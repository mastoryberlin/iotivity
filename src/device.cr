require "uuid"
require "log"

require "./bindings"

module IoTivity

  # The interfaces exposed by some particular resource.
  @[Flags]
  enum Interface
    Baseline = 1 << 1
    LL = 1 << 2
    B = 1 << 3
    R = 1 << 4
    RW = 1 << 5
    A = 1 << 6
    S = 1 << 7
    Create = 1 << 8
  end

  # ---------------------------------------------------------------------------------------

  # An IoTivity resource.
  record Resource,
    interfaces = Interface::Baseline

  # ---------------------------------------------------------------------------------------

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

    def onboard(client : Client)
      Log.context.set uuid: @uuid.urn, method: "JustWorks"

      uuid = OC::UUID.new id: @uuid.bytes
      Log.info { "Sending onboarding request" }
      sent = OC.obt_perform_just_works_otm pointerof(uuid),
               ->(u : OC::UUID*, status : Int32, d : Void*){
                 dev = Box(self).unbox d
                 Log.context.set uuid: dev.uuid.urn, method: "JustWorks"
                 if status >= 0
                   Log.info { "Onboarding successful" }
                 else
                   Log.warn { "Error performing ownership transfer on device" }
                 end
               }, Box.box self
      if sent >= 0
        Log.info { "Sent onboarding request" }
      else
        Log.warn { "Failed to send onboarding request" }
      end
    end

    # ---------------------------------------------------------------------------------------

    def reset
      Log.context.set uuid: @uuid.urn
      uuid = OC::UUID.new id: @uuid.bytes
      sent = OC.obt_device_hard_reset pointerof(uuid),
                ->(u : OC::UUID*, status : Int32, d : Void*){
                  dev = Box(self).unbox d
                  Log.context.set uuid: dev.uuid.urn
                  if status >= 0
                    Log.info { "Hard reset successful" }
                  else
                    Log.warn { "Error performing hard reset" }
                  end
                 }, Box.box self
      if sent >= 0
        Log.info { "Sent hard reset request" }
      else
        Log.warn { "Failed to send hard reset request" }
      end
    end

  end # class Device

end # module IoTivity
