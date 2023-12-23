require "kubernetes"

module Kubernetes
  define_resource "secrets",
    group: "",
    type: JSON::Any,
    prefix: "api",
    kind: "Secret"
end
