module WdProvisioner
  class Controller
    def create_iscsi(name : String, password : String, size : Int32) : Bool
      # iscsictl --add_target_lun -n TARGET_NAME -V Volume(Volume_1) -s SIZE(GB) -c CHAP(0/1) [-U usename -P pwd] -p PREALLOC(0/1)
      params = "--add_target_lun -n '#{name}' -V Volume_1 -s '#{size}' -c 1 -U '#{name}' -P '#{password}' -p 1"
      output, success = @ssh.iscsictl! params

      unless success
        @log.error { "iSCSI target #{name} could not be created: #{output}" }

        return false
      end

      @log.info { "iSCSI target #{name} created" }

      true
    end

    def delete_iscsi(name : String) : Bool
      # iscsictl --del_target_lun -n TARGET_NAME
      params = "--del_target_lun -n '#{name}'"
      output, success = @ssh.iscsictl! params

      unless success
        @log.error { "iSCSI target #{name} could not be deleted: #{output}" }

        return false
      end

      @log.info { "iSCSI target #{name} deleted" }

      true
    end
  end
end
