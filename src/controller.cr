require "kubernetes"

require "./kubernetes/ext"

module WdProvisioner
  class Controller
    @storage_class : Kubernetes::StorageClass
    @is_default_class : Bool

    def initialize(*, client @k8s : Kubernetes::Client = Kubernetes::Client.new, @storage_class_name = "wd-iscsi")
      Log.setup_from_env
      @log = Log.for("wd-provisioner.controller")

      sc = @k8s.storageclass(name: @storage_class_name)

      raise "StorageClass #{@storage_class_name} not found" unless sc

      @storage_class = sc
      @is_default_class = @storage_class.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true"
    end

    def process_pvcs
      @log.info { "Processing PersistentVolumeClaims targeting #{@storage_class_name} StorageClass" }

      @k8s.watch_persistentvolumeclaims(namespace: nil) do |watch|
        pvc = watch.object

        next unless matching_storage_class? pvc

        case watch
        when .added?
          create_pv(pvc)
        when .deleted?
          pv_name = "#{@storage_class_name}-#{pvc.metadata.name}"
          @log.info { "PersistentVolume #{pv_name} deleted" }

          @k8s.delete_persistentvolume(name: pv_name)
        else
          @log.debug { "PersistentVolume #{pvc.metadata.namespace}/#{pvc.metadata.name} #{watch.type} event ignored" }

          next
        end
      end
    end

    def create_pv(pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Kubernetes::Resource(Kubernetes::PersistentVolume)?
      pv_name = "#{@storage_class_name}-#{pvc.metadata.name}"

      pv = @k8s.apply_persistentvolume(
        metadata: {
          name:        pv_name,
          annotations: {
            "pv.kubernetes.io/provisioned-by": @storage_class.provisioner,
          },
        },
        spec: {
          storageClassName: @storage_class_name,
          claimRef:         {
            apiVersion: "v1",
            kind:       "PersistentVolumeClaim",
            name:       pvc.metadata.name,
            namespace:  pvc.metadata.namespace,
          },
          capacity: {
            storage: pvc.spec.resources.requests.storage,
          },
          accessModes: pvc.spec.access_modes,
          iscsi:       {
            targetPortal:    "10.100.0.101",
            iqn:             "iqn.2013-03.com.wdc:mycloudex2ultra:#{pv_name}",
            lun:             0,
            fsType:          "ext4",
            chapAuthSession: true,
            secretRef:       {
              name: pv_name,
            },
          },
        },
      )

      case pv
      in Kubernetes::Resource(Kubernetes::PersistentVolume)
        @log.info { "PersistentVolume #{pv_name} created" }

        pv
      in Kubernetes::Status
        @log.error { "PersistentVolume #{pv_name} could not be created: #{pv.inspect}" }

        nil
      end
    end

    def matching_storage_class?(pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Bool
      (@is_default_class && pvc.spec.storage_class_name.nil?) || (@storage_class_name == pvc.spec.storage_class_name)
    end
  end
end
