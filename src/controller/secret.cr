require "base64"

module WdProvisioner
  class Controller
    def create_secret(name : String, namespace = "default") : String?
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
        @log.error { "Secret #{name} could not be created: #{secret.inspect}" }

        return nil
      end

      @log.info { "Secret #{name} created" }

      password
    end

    def delete_secret(name : String, namespace = "default")
      @k8s.delete_secret(name: name, namespace: namespace)

      @log.info { "Secret #{name} deleted" }
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
