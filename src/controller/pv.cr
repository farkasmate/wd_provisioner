require "kubernetes"

require "../kubernetes/ext"

module WdProvisioner
  class Controller
    def create_pv(name : String, pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)) : Kubernetes::Resource(Kubernetes::PersistentVolume)?
      if pv = get_pv(name: name)
        @log.info { "PersistentVolume #{name} already exists" }

        validate_pv(pv, pvc)

        return pv
      end

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
          persistentVolumeReclaimPolicy: @storage_class.reclaim_policy,
        },
      )

      if pv.is_a? Kubernetes::Status
        @log.error { "PersistentVolume #{name} could not be created: #{pv.inspect}" }

        return nil
      end

      @log.info { "PersistentVolume #{name} created" }

      pv
    end

    def get_pv(name : String) : Kubernetes::Resource(Kubernetes::PersistentVolume)?
      pv = @k8s.persistentvolume(name: name)

      return pv if pv.is_a? Kubernetes::Resource(Kubernetes::PersistentVolume)

      return nil
    end

    def delete_pv(name : String)
      unless get_pv(name: name)
        @log.info { "PersistentVolume #{name} already deleted" }

        return
      end

      @k8s.delete_persistentvolume(name: name)

      @log.info { "PersistentVolume #{name} deleted" }
    end

    private def validate_pv(pv : Kubernetes::Resource(Kubernetes::PersistentVolume), pvc : Kubernetes::Resource(Kubernetes::PersistentVolumeClaim))
      if (provisioner = pv.metadata.annotations["pv.kubernetes.io/provisioned-by"]?) != @storage_class.provisioner
        @log.warn { "PersistentVolume #{pv.metadata.name} was provisioned by '#{provisioner}'" }
      end

      if pv.spec.storage_class_name != @storage_class_name
        @log.warn { "PersistentVolume #{pv.metadata.name} has '#{pv.spec.storage_class_name}' StorageClass" }
      end

      if claim_ref = pv.spec.claim_ref
        if claim_ref.name != pvc.metadata.name || claim_ref.namespace != pvc.metadata.namespace
          @log.warn { "PersistentVolume #{pv.metadata.name} claimed by PersistentVolumeClaim #{claim_ref.namespace}/#{claim_ref.name}" }
        end
      end

      if pv.spec.capacity.storage != pvc.spec.resources.requests.storage
        @log.warn { "PersistentVolume #{pv.metadata.name} actual size #{pv.spec.capacity.storage} differs from spec size #{pvc.spec.resources.requests.storage}" }
      end

      if pv.spec.access_modes != pvc.spec.access_modes
        @log.warn { "PersistentVolume #{pv.metadata.name} actual accessModes #{pv.spec.access_modes} differ from spec accessModes #{pvc.spec.access_modes}" }
      end

      unless iscsi = pv.spec.iscsi
        @log.warn { "PersistentVolume #{pv.metadata.name} has no iSCSI configuration" }

        return
      end

      if iscsi.target_portal != @storage_class.parameters.host
        @log.warn { "PersistentVolume #{pv.metadata.name} has #{iscsi.target_portal} targetPortal" }
      end

      if iscsi.iqn != "iqn.2013-03.com.wdc:mycloudex2ultra:#{pv.metadata.name}"
        @log.warn { "PersistentVolume #{pv.metadata.name} has unmatching iqn #{iscsi.iqn}" }
      end

      if iscsi.secret_ref.name != pv.metadata.name
        @log.warn { "PersistentVolume #{pv.metadata.name} has unmatching secret name #{iscsi.secret_ref.name}" }
      end
    end
  end
end
