require "kubernetes"
require "spec"

def test_client : Kubernetes::Client
  config = File.open("kubeconfig.yaml") { |f| Kubernetes::Config.from_yaml f }
  kind = config.clusters.find! { |cluster| cluster.name == "kind-wd-provisioner" }.cluster
  cert = File.tempfile(prefix: "kubernetes", suffix: ".crt") do |tempfile|
    Base64.decode(kind.certificate_authority_data, tempfile)
  end
  at_exit { cert.delete }

  Kubernetes::Client.new(
    server: kind.server,
    token: "abcdef.0123456789abcdef",
    certificate_file: cert.path,
  )
end
