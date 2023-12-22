require "./spec_helper"

require "../src/controller"

module WdProvisioner
  describe Controller do
    it "creates PV for PVC" do
      config = File.open("config.yaml") { |f| Kubernetes::Config.from_yaml f }
      kind = config.clusters.find! { |cluster| cluster.name == "kind-wd-provisioner" }.cluster
      cert = File.tempfile(prefix: "kubernetes", suffix: ".crt") do |tempfile|
        Base64.decode(kind.certificate_authority_data, tempfile)
      end
      at_exit { cert.delete }

      k8s = Kubernetes::Client.new(
        server: kind.server,
        token: "abcdef.0123456789abcdef",
        certificate_file: cert.path,
      )

      ns = k8s.apply_namespace(
        metadata: {
          name: "test",
        }
      )
      ns.should be_a(Kubernetes::Resource(Kubernetes::Namespace))

      pvc = k8s.apply_persistentvolumeclaim(
        metadata: {
          name:      "test",
          namespace: ns.metadata.name,
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
        controller = Controller.new(k8s)
        pv_for_pvc = controller.create_pv(pvc)

        case pv_for_pvc
        in Nil
          pv_for_pvc.should_not be(nil)
        in Kubernetes::Resource(Kubernetes::PersistentVolume)
          pv = k8s.persistentvolumes(namespace: nil).items.find { |pv| pv.metadata.name == pv_for_pvc.metadata.name }
          pv.should be_a(Kubernetes::Resource(Kubernetes::PersistentVolume))

          k8s.delete_persistentvolumeclaim(namespace: pvc.metadata.namespace, name: pvc.metadata.name)
          k8s.delete_persistentvolume(name: pv.metadata.name) if pv
        end
      end
    end
  end
end
