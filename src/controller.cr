require "kubernetes"

require "./persistentvolume"
require "./persistentvolumeclaim"

module WdProvisioner
  class Controller
    def initialize(@k8s : Kubernetes::Client = Kubernetes::Client.new)
      Log.setup_from_env
      @log = Log.for("wd-provisioner.controller")
    end

    def process_pvcs
      @k8s.watch_persistentvolumeclaims(namespace: nil) do |watch|
        pvc = watch.object
        pv_name = "wd-iscsi-#{pvc.metadata.name}"

        case watch
        when .added?
          create_pv(pvc)
        when .deleted?
          @log.info { "PersistentVolume #{pv_name} deleted" }

          @k8s.delete_persistentvolume(name: pv_name)
        else
          @log.debug { "PersistentVolume #{pvc.metadata.namespace}/#{pvc.metadata.name} #{watch.type} event ignored" }

          next
        end
      end
    end

    def create_pv(pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Kubernetes::Resource(Kubernetes::PersistentVolume) | Nil
      pv_name = "wd-iscsi-#{pvc.metadata.name}" # FIXME

      pv = @k8s.apply_persistentvolume(
        metadata: {
          name:        pv_name,
          annotations: {
            "pv.kubernetes.io/provisioned-by": "farkasmate.github.io/wd-provisioner",
          },
        },
        spec: {
          storageClassName: "wd-iscsi",
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
  end
end
