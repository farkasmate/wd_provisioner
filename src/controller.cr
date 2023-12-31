require "kubernetes"

require "./controller/*"
require "./kubernetes/ext"
require "./quantity"
require "./ssh"

module WdProvisioner
  class Controller
    include Quantity

    @storage_class : Kubernetes::StorageClass
    @is_default_class : Bool
    @size_limit : Int32

    def initialize(*, client @k8s : Kubernetes::Client = Kubernetes::Client.new, @storage_class_name = "wd-iscsi", @private_key = "/config/ssh.key")
      Log.setup_from_env
      @log = Log.for("wd-provisioner.controller")

      sc = @k8s.storageclass(name: @storage_class_name)

      raise "StorageClass #{@storage_class_name} not found" unless sc

      @storage_class = sc
      @is_default_class = @storage_class.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true"

      @size_limit = estimate_gb(@storage_class.parameters.size_limit)

      raise "SSH private key #{private_key} not found" unless File.exists? private_key

      params = @storage_class.parameters
      @ssh = WdSSH.new(host: params.host, port: params.port.to_i, user: params.user, private_key: private_key)
      at_exit { @ssh.close }

      @log.debug { "StorageClass: #{@storage_class_name}#{@is_default_class ? " (DEFAULT)" : ""}" }
      @log.debug { "PersistentVolume size limit: #{@size_limit}GB" }
      @log.debug { "SSH private key path: #{@private_key}" }
    end

    def process_pvcs
      @log.info { "Processing PersistentVolumeClaims targeting #{@storage_class_name} StorageClass" }

      @k8s.watch_persistentvolumeclaims(namespace: nil) do |watch|
        pvc = watch.object

        next unless matching_storage_class? pvc

        name = "#{@storage_class_name}-#{pvc.metadata.name}"
        namespace = pvc.metadata.namespace

        case watch
        when .added?
          begin
            size = estimate_gb(pvc.spec.resources.requests.storage)
          rescue ex
            @log.error { "PersistentVolumeClaim #{pvc.metadata.name}'s storage request can't be parsed: #{ex.message}" }

            next
          end

          if size > @size_limit
            @log.error { "PersistentVolumeClaim #{pvc.metadata.name}'s storage request exceeds StorageClass limit: #{@size_limit}GB" }

            next
          end

          next unless password = create_secret(name, namespace)

          next unless create_iscsi(name, password, size)

          next unless create_pv(name, pvc)
        when .deleted?
          delete_pv(name)
          delete_iscsi(name)
          delete_secret(name, namespace)
        else
          @log.debug { "PersistentVolume #{pvc.metadata.namespace}/#{pvc.metadata.name} #{watch.type} event ignored" }

          next
        end
      end
    end

    def matching_storage_class?(pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Bool
      (@is_default_class && pvc.spec.storage_class_name.nil?) || (@storage_class_name == pvc.spec.storage_class_name)
    end
  end
end
