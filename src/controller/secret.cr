require "base64"

module WdProvisioner
  class Controller
    def create_secret(name : String, namespace = "default") : String?
      if secret = get_secret(name: name, namespace: namespace)
        @log.info { "Secret #{namespace}/#{name} already exists" }

        auth_name = Base64.decode_string(secret.data.node_session_auth_username)
        @log.warn { "Secret #{name} has unmatching auth name #{auth_name}" } unless auth_name == name

        return Base64.decode_string(secret.data.node_session_auth_password)
      end

      # NOTE: CHAP password must be between 12 to 16 characters
      password = generate_password(16)

      secret = @k8s.apply_secret(
        metadata: {
          name:      name,
          namespace: namespace,
        },
        data: {
          "node.session.auth.password": Base64.encode(password),
          "node.session.auth.username": Base64.encode(name),
        },
        type: "kubernetes.io/iscsi-chap",
      )

      if secret.is_a? Kubernetes::Status
        @log.error { "Secret #{namespace}/#{name} could not be created: #{secret.inspect}" }

        return nil
      end

      @log.info { "Secret #{namespace}/#{name} created" }

      password
    end

    def get_secret(name : String, namespace = "default") : Kubernetes::Secret?
      secret = @k8s.secret(name: name, namespace: namespace)

      return secret if secret.is_a? Kubernetes::Secret

      return nil
    end

    def delete_secret(name : String, namespace = "default")
      unless secret = get_secret(name: name, namespace: namespace)
        @log.info { "Secret #{namespace}/#{name} already deleted" }

        return
      end

      @k8s.delete_secret(name: name, namespace: namespace)

      @log.info { "Secret #{namespace}/#{name} deleted" }
    end

    private def generate_password(size : Int32) : String
      chars = [*("a".."z"), *("A".."Z"), *("0".."9")]

      String.build(size) do |io|
        size.times do
          io << chars.sample(Random::Secure)
        end
      end
    end
  end
end
