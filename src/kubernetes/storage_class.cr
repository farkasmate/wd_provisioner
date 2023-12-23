require "kubernetes"

module Kubernetes
  struct StorageClass
    include Serializable

    field metadata : Metadata
    field provisioner : String
    field reclaim_policy : String
  end

  define_resource "storageclasses",
    singular_name: "storageclass",
    group: "storage.k8s.io",
    type: StorageClass,
    prefix: "apis",
    kind: "StorageClass",
    cluster_wide: true
end
