require "kubernetes"

module Kubernetes
  struct Secret
    include Serializable

    field metadata : Metadata
    field data : Data

    struct Data
      include Serializable

      field node_session_auth_password : String, key: "node.session.auth.password"
      field node_session_auth_username : String, key: "node.session.auth.username"
    end
  end

  define_resource "secrets",
    group: "",
    type: Secret,
    prefix: "api",
    kind: "Secret"
end
