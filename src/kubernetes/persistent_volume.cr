require "kubernetes"

module Kubernetes
  struct PersistentVolume
    include Serializable

    field storage_class_name : String?
    field claim_ref : ClaimRef?
    field capacity : PersistentVolumeClaim::Resources::Requests
    field access_modes : Array(String)
    field iscsi : Iscsi?
    field persistent_volume_reclaim_policy : String = "Delete"

    struct ClaimRef
      include Serializable

      field api_version : String = "v1"
      field kind : String = "PersistentVolumeClaim"
      field name : String
      field namespace : String = "default"
    end

    struct Iscsi
      include Serializable

      field target_portal : String
      field iqn : String
      field lun : Int32 = 0
      field fs_type : String = "ext4"
      field chap_auth_session : Bool = true
      field secret_ref : SecretRef

      struct SecretRef
        include Serializable

        field name : String
      end
    end
  end

  define_resource "persistentvolumes",
    group: "",
    type: Resource(PersistentVolume),
    prefix: "api",
    kind: "PersistentVolume",
    cluster_wide: true
end
