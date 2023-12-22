require "kubernetes"
require "spec"

module Kubernetes
  struct Namespace
    include Serializable
  end

  define_resource "namespaces",
    group: "",
    type: Resource(Namespace),
    prefix: "api",
    kind: "Namespace",
    cluster_wide: true
end
