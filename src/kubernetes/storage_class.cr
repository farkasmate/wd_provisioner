require "kubernetes"

module Kubernetes
  struct StorageClass
    include Serializable

    field metadata : Metadata
    field provisioner : String
    field reclaim_policy : String
    field parameters : Parameters

    struct Parameters
      include Serializable

      field host : String
      field port : String = "22"
      field user : String
      field size_limit : String = "100Gi"
    end
  end

  define_resource "storageclasses",
    singular_name: "storageclass",
    group: "storage.k8s.io",
    type: StorageClass,
    prefix: "apis",
    kind: "StorageClass",
    cluster_wide: true
end
