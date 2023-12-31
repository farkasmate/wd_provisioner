require "log"
require "ssh"

class WdSSH < SSH
  def initialize(*, @host : String, @user : String, @port = 22, @private_key : String)
    Log.setup_from_env
    @log = Log.for("wd-provisioner.ssh")

    super(@host, @user, @port)
  end

  def self.open(*, host : String, user : String, port = 22, private_key : String)
    ssh = self.new(host: host, user: user, port: port, private_key: private_key)
    begin
      yield ssh
    ensure
      ssh.close
    end
  end

  private def authenticate : Nil
    loop do
      auth = LibSSH.ssh_userauth_publickey_auto(@session, @user, nil)

      break if auth.success?

      if auth.again?
        wait_socket
        next
      end

      raise Error.new("auth failed")
    end
  end

  private def connect : Nil
    configure
    super
  end

  private def configure
    verbosity = case @log.level
                when .trace?
                  5
                when .debug?
                  1
                else
                  0
                end
    LibSSH.ssh_options_set(@session, LibSSH::Options::LOG_VERBOSITY, pointerof(verbosity))

    LibSSH.ssh_options_set(@session, LibSSH::Options::IDENTITY, @private_key)
  end

  def iscsictl!(params : String) : Tuple(String, Bool)
    output, exit_status = exec! "iscsictl #{params}"
    errors = output.lines.reject(/^option /)

    {errors.join("\n"), errors.empty?}
  end
end
