require "./spec_helper"

require "../src/controller"

module WdProvisioner
  @@k8s : Kubernetes::Client = test_client

  describe Controller do
    it "creates PV for PVC" do
      pvc = @@k8s.apply_persistentvolumeclaim(
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
        controller = Controller.new(client: @@k8s, private_key: "spec/kustomize/id_rsa")
        pv_for_pvc = controller.create_pv("test-pv", pvc)

        case pv_for_pvc
        in Nil
          pv_for_pvc.should_not be_nil
        in Kubernetes::Resource(Kubernetes::PersistentVolume)
          pv = @@k8s.persistentvolume(name: pv_for_pvc.metadata.name)
          pv.should be_a(Kubernetes::Resource(Kubernetes::PersistentVolume))

          @@k8s.delete_persistentvolumeclaim(namespace: pvc.metadata.namespace, name: pvc.metadata.name)
          controller.delete_pv(name: pv.metadata.name) if pv
        end
      end
    end

    it "ignores other storage classes" do
      pvc = @@k8s.apply_persistentvolumeclaim(
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
        controller = Controller.new(client: @@k8s, private_key: "spec/kustomize/id_rsa")
        controller.matching_storage_class?(pvc).should be_false
      end
    end

    it "creates compatible secret" do
      controller = Controller.new(client: @@k8s, private_key: "spec/kustomize/id_rsa")
      password = controller.create_secret("test-secret", namespace: "test")
      controller.delete_secret("test-secret", namespace: "test")

      password.should_not be_nil

      next unless password

      password.size.should be >= 12
      password.size.should be <= 16
    end
  end
end
