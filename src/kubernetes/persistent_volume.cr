require "kubernetes"

module Kubernetes
  struct PersistentVolume
    include Serializable
  end

  define_resource "persistentvolumes",
    group: "",
    type: Resource(PersistentVolume),
    prefix: "api",
    kind: "PersistentVolume",
    cluster_wide: true
end
