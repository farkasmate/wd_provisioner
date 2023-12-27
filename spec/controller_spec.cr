require "./spec_helper"

require "../src/controller"

module WdProvisioner
  describe Controller do
    it "creates PV for PVC" do
      k8s = test_client

      pvc = k8s.apply_persistentvolumeclaim(
        metadata: {
          name:      "test",
          namespace: "test",
        },
        spec: {
          accessModes: ["ReadOnlyMany"],
          volumeMode:  "Filesystem",
          resources:   {
            requests: {
              storage: "10Gi",
            },
          },
          storageClassName: "wd-iscsi",
        },
      )

      case pvc
      in Kubernetes::Status
        pvc.should be_a(Kubernetes::Resource(Kubernetes::PersistentVolumeClaim))
      in Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)
        controller = Controller.new(client: k8s)
        pv_for_pvc = controller.create_pv(pvc)

        case pv_for_pvc
        in Nil
          pv_for_pvc.should_not be_nil
        in Kubernetes::Resource(Kubernetes::PersistentVolume)
          pv = k8s.persistentvolume(name: pv_for_pvc.metadata.name)
          pv.should be_a(Kubernetes::Resource(Kubernetes::PersistentVolume))

          k8s.delete_persistentvolumeclaim(namespace: pvc.metadata.namespace, name: pvc.metadata.name)
          if pv
            k8s.delete_persistentvolume(name: pv.metadata.name)
            k8s.delete_secret(name: pv.metadata.name)
          end
        end
      end
    end

    it "ignores other storage classes" do
      k8s = test_client

      pvc = k8s.apply_persistentvolumeclaim(
        metadata: {
          name:      "standard",
          namespace: "test",
        },
        spec: {
          accessModes: ["ReadOnlyMany"],
          volumeMode:  "Filesystem",
          resources:   {
            requests: {
              storage: "10Gi",
            },
          },
          storageClassName: "standard",
        },
      )

      case pvc
      in Kubernetes::Status
        pvc.should be_a(Kubernetes::Resource(Kubernetes::PersistentVolumeClaim))
      in Kubernetes::Resource(Kubernetes::PersistentVolumeClaim)
        controller = Controller.new(client: k8s)
        controller.matching_storage_class?(pvc).should be_false
      end
    end
  end
end
