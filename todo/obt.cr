require "event_handler"
require "log"
require "uuid"

require "./resource"
require "./device"

module IoTivity

  # Mix-in to create an IoTivity onboarding tool (OBT).
  module OnboardingTool
    include EventHandler

    # =======================================================================================
    # Constants
    # =======================================================================================

    Log = ::Log.for("IoTivity::OnboardingTool")

    # =======================================================================================
    # Events
    # =======================================================================================

    event DeviceDiscovery, di : UUID, eps : OC::Endpoint*

    # =======================================================================================
    # Methods
    # =======================================================================================

    # Triggers an invocation of `oc_obt_discover_owned_devices` and
    # emits `Discovery` events for each found device.
    def discover_owned
      OC.obt_discover_owned_devices \
        ->(uuid, eps, user_data){
          obt = Box({{@type}}).unbox(user_data)
          obt.emit DeviceDiscovery, UUID.new(uuid.value.id), eps
        },
        Box.box(self.as({{@type}}))
    end

    # ---------------------------------------------------------------------------------------

    # Triggers an invocation of `oc_obt_discover_unowned_devices` and
    # emits `Discovery` events for each found device.
    def discover_unowned
      OC.obt_discover_unowned_devices \
        ->(uuid, eps, data){
          obt = Box({{@type}}).unbox(user_data)
          obt.emit DeviceDiscovery, UUID.new(uuid.value.id), eps
        },
        Box.box(self.as({{@type}}))
    end

    # ---------------------------------------------------------------------------------------

    def onboard(device)
      Log.context.clear
      Log.context.set uuid: device.uuid.to_s, method: "Just Works"

      uuid = OC::UUID.new id: device.uuid.bytes
      Log.info { "Sending onboarding request" }
      sent = OC.obt_perform_just_works_otm pointerof(uuid),
               ->(u : OC::UUID*, status : Int32, d : Void*){
                 dev = Box(IoTivity::Device).unbox d
                 Log.context.clear
                 Log.context.set uuid: dev.uuid.to_s, method: "Just Works"
                 if status >= 0
                   Log.info { "Onboarding successful" }
                 else
                   Log.warn { "Error performing ownership transfer on device" }
                 end
               }, Box.box device
      if sent >= 0
        Log.info { "Successfully sent onboarding request" }
      else
        Log.warn { "Failed to send onboarding request" }
      end
    end

    # ---------------------------------------------------------------------------------------

    def provision(device)
      Log.context.clear
      Log.context.set my_uuid: myself.uuid.to_s, device_uuid: device.uuid.to_s

      my_uuid  = OC::UUID.new id: myself.uuid.bytes
      dev_uuid = OC::UUID.new id: device.uuid.bytes

      Log.info { "Provision ACL2" }

      ace = Pointer(OC::SecACE).null
      ace = OC.obt_new_ace_for_subject pointerof(my_uuid)

      res = OC.obt_ace_new_resource ace

      if res.null?
        Log.error { "ERROR: Could not allocate new resource for ACE" }
        OC.obt_free_ace ace
        return
      end

      OC.obt_ace_resource_set_href res, "/oic/sec/pstat"

      # ######################################################

      res2 = OC.obt_ace_new_resource ace

      if res2.null?
        Log.error { "ERROR: Could not allocate new resource for ACE" }
        OC.obt_free_ace ace
        return
      end

      OC.obt_ace_resource_set_href res2, "/led"
      OC.obt_ace_add_permission ace,
        OC::ACEPermissions.flags(Retrieve, Update)

      sent = OC.obt_provision_ace \
              pointerof(dev_uuid), ace,
              ->(uuid, status, data) {
                dev = Box(IoTivity::Device).unbox data
                Log.context.clear
                Log.context.set uuid: dev.uuid.to_s

                if status >= 0
                  Log.info { "Provisioning successful" }
                else
                  Log.warn { "Error provisioning ACE for device" }
                end
              }, Box.box myself
      if sent >= 0
        Log.info { "Successfully issued request to provision ACE" }
      else
        Log.warn { "ERROR issuing request to provision ACE" }
      end
    end

  end # module OnboardingTool
end # module IoTivity
