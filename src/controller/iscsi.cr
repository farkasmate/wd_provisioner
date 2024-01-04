module WdProvisioner
  class Controller
    def create_iscsi(name : String, password : String, size : Int32) : Bool
      if current_size = get_iscsi_size(name: name)
        @log.info { "iSCSI target #{name} already exists" }

        @log.warn { "iSCSI target #{name} actual size #{current_size} GB differs from spec size #{size} GB" } unless current_size == size

        return true
      end

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

    def get_iscsi_size(name : String) : Int32?
      command = "stat -c '%s' /shares/Volume_1/.systemfile/iscsi_images/#{name}.img"
      output, exit_status = @ssh.exec! command

      return nil unless exit_status == 0

      # NOTE: WD LUN size approximation
      (output.lines.first.to_i64 / 1_000_000_000).round_away.to_i
    end

    def delete_iscsi(name : String) : Bool
      unless get_iscsi_size(name: name)
        @log.info { "iSCSI target #{name} already deleted" }

        return true
      end

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
