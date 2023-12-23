require "kubernetes"

module Kubernetes
  struct PersistentVolumeClaim
    include Serializable

    field access_modes : Array(String)?
    field resources : Resources
    field storage_class_name : String

    struct Resources
      include Serializable

      field requests : Requests

      struct Requests
        include Serializable

        field storage : String
      end
    end
  end

  define_resource "persistentvolumeclaims",
    group: "",
    type: Resource(PersistentVolumeClaim),
    prefix: "api",
    kind: "PersistentVolumeClaim"
end
