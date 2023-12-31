require "kubernetes"

require "../kubernetes/ext"

module WdProvisioner
  class Controller
    def create_pv(name : String, pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Kubernetes::Resource(Kubernetes::PersistentVolume)?
      pv = @k8s.apply_persistentvolume(
        metadata: {
          name:        name,
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
            targetPortal:    @storage_class.parameters.host,
            iqn:             "iqn.2013-03.com.wdc:mycloudex2ultra:#{name}",
            lun:             0,
            fsType:          "ext4",
            chapAuthSession: true,
            secretRef:       {
              name: name,
            },
          },
        },
      )

      if pv.is_a? Kubernetes::Status
        @log.error { "PersistentVolume #{name} could not be created: #{pv.inspect}" }

        return nil
      end

      @log.info { "PersistentVolume #{name} created" }

      pv
    end

    def delete_pv(name : String)
      @k8s.delete_persistentvolume(name: name)

      @log.info { "PersistentVolume #{name} deleted" }
    end
  end
end
