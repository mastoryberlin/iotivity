require "uuid"
require "log"

require "./resource"
require "./endpoint"

module IoTivity

  # An IoTivity device.
  class Device

    # =======================================================================================
    # Constants
    # =======================================================================================

    Log = ::Log.for(self)

    # =======================================================================================
    # Properties
    # =======================================================================================

    # The unique device id ("di") of this device within the network.
    getter uuid : UUID

    # ---------------------------------------------------------------------------------------

    # The endpoints (IP addresses) at which this device can be found.
    getter endpoints : OC::Endpoint*

    # ---------------------------------------------------------------------------------------

    # The resources available at this device, stored as a map connecting
    # a URI to the respective resource information. You can also use the
    # index operators `#[]` and `#[]?` as shortcut to access a certain resource.
    property res = {} of String => Resource

    # ---------------------------------------------------------------------------------------

    def [](uri); @res[uri]; end
    def []?(uri); @res[uri]?; end

    # =======================================================================================
    # Instance variables
    # =======================================================================================

    @onboard_candidate : Void* = Pointer(Void).null

    # =======================================================================================
    # Constructors
    # =======================================================================================

    def initialize(@uuid : UUID, @endpoints : OC::Endpoint*)
    end

    # ---------------------------------------------------------------------------------------

    def initialize(device_id : String, @endpoints : OC::Endpoint*)
      @uuid = UUID.new device_id.lchop("ocf://")
    end

    # =======================================================================================
    # Methods
    # =======================================================================================

    def reset
      Log.context.clear
      Log.context.set uuid: @uuid.to_s
      uuid = OC::UUID.new id: @uuid.bytes
      sent = OC.obt_device_hard_reset pointerof(uuid),
                ->(u : OC::UUID*, status : Int32, d : Void*){
                  dev = Box(self).unbox d
                  Log.context.clear
                  Log.context.set uuid: dev.uuid.to_s
                  if status >= 0
                    Log.info { "Hard reset successful" }
                  else
                    Log.warn { "Error performing hard reset" }
                  end
                 }, Box.box self
      if sent >= 0
        Log.info { "Successfully sent hard reset request" }
      else
        Log.warn { "Failed to send hard reset request" }
      end
    end

  end # class Device

end # module IoTivity
