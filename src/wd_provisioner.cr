require "./controller"

module WdProvisioner
  VERSION = "0.1.0"

  controller = Controller.new
  controller.process_pvcs
end
