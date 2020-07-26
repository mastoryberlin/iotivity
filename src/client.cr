require "event_handler"
require "iotivity"
require "log"
require "uuid"

require "./helper"

module IoTivity

  # An IoTivity client.
  class Client
    include EventHandler

    # =======================================================================================
    # Constants
    # =======================================================================================

    Log = ::Log.for(self)

    # =======================================================================================
    # Events
    # =======================================================================================

    event Discovery, device : Device
    event Response, from : OC::Endpoint*, code : OC::Status, payload : OC::Rep*

    # =======================================================================================
    # Properties
    # =======================================================================================

    # A list of all devices discovered.
    property discovered = [] of Device

    # ---------------------------------------------------------------------------------------

    # Indicates the client is about to quit.
    getter? closing = false

    # =======================================================================================
    # Class variables
    # =======================================================================================

    # "Class-global" helper variable to facilitate device discovery.
    @@ddev : Device? = nil

    # =========================================================================
    # Methods
    # =========================================================================

    # Triggers an invocation of `oc_do_ip_discovery` if *resource_type* is
    # set to a String, or `oc_do_ip_discovery_all` otherwise.
    def discover(resource_type : String? = nil)
      if resource_type
        OC.do_ip_discovery resource_type, ->Client.discovery_cb, Box.box(self.as(Client))
      else
        OC.do_ip_discovery_all ->Client.discovery_all_cb, Box.box(self.as(Client))
      end
    end

    # ---------------------------------------------------------------------------------------

    # Triggers an invocation of `oc_obt_discover_owned_devices` and
    # emits `Discovery` events for each found device.
    def discover_owned
      OC.obt_discover_owned_devices ->(uuid : OC::UUID*, eps : OC::Endpoint*, data : Void*){
        dev = Device.new( UUID.new(uuid.value.id), eps )
        client = Box(Client).unbox(data)
        client.discovered << dev
        client.emit Discovery, dev
      }, Box.box(self.as(Client))
    end

    # ---------------------------------------------------------------------------------------

    # Triggers an invocation of `oc_obt_discover_unowned_devices` and
    # emits `Discovery` events for each found device.
    def discover_unowned
      OC.obt_discover_unowned_devices ->(uuid : OC::UUID*, eps : OC::Endpoint*, data : Void*){
        dev = Device.new( UUID.new(uuid.value.id), eps )
        client = Box(Client).unbox(data)
        client.discovered << dev
        client.emit Discovery, dev
      }, Box.box(self.as(Client))
    end

    # ---------------------------------------------------------------------------------------

    # Sends a GET request via an invocation of `oc_do_get` and returns
    # the response.
    def get(uri, from device, query = nil, qos = OC::QoS::Low)
      OC.do_get uri, device.endpoints, query, ->(response : OC::ClientResponse*){
                  r = response.value
                  client = Box(Client).unbox r.user_data
                  client.emit Response, r.endpoint, r.code, r.payload
                },
                qos, Box.box(self)
      once Response do |e|
        puts "Response arrived - code #{e.code}"
        if e.code.ok?
          puts "Received payload:"
          rep = e.payload
          puts "Determining JSON bufsize..."
          size = OC.rep_to_json rep, nil, 0, true
          puts "Need #{size + 1} bytes"
          buf = Pointer(UInt8).malloc(size + 1)
          OC.rep_to_json rep, buf, size + 1, true
          puts String.new(buf)
        end
      end
    end

    # ---------------------------------------------------------------------------------------

    # Sets up and runs the IoTivity client.
    def run
      # This is basically the Crystal translation of the C main() function
      # of IoTivity's example "apps/client_linux.c"

      # Register signal handler for Ctrl+C abortion with proper cleanup
      Signal::INT.trap do
        @closing = true
      end

      puts "Set up an OCF Client..."

      LibIoTivity.on_discovery     = ->Client.discovery_cb
      LibIoTivity.on_discovery_all = ->Client.discovery_all_cb

      # initialize the handlers structure
      handler = OC::Handler.new \
        init: ->{
          ret = OC.init_platform("Mastory GmbH", nil, nil) \
              | OC.add_device("/oic/d", "oic.wk.d", "Generic Client", "ocf.1.0.0",
                               "ocf.res.1.3.0", nil, nil)
          ret
        },
        signal_event_loop:  ->{},
        requests_entry: ->{
          OC.obt_init
        }

      # #ifdef OC_SECURITY
      puts "Initialize Secure Resources\n"
      OC.storage_config "./client_creds"
      # #endif /* OC_SECURITY */

      # #ifdef OC_SECURITY
      # /* please comment out if the server:
      #   - have no display capabilities to display the PIN value
      #   - server does not require to implement RANDOM PIN (oic.sec.doxm.rdp) onboarding mechanism
      # */
      # oc_set_random_pin_callback(random_pin_cb, NULL);
      # #endif /* OC_SECURITY */

      OC.set_con_res_announced(false)

      # start the stack
      init = OC.main_init(pointerof(handler))

      if init < 0
        puts "oc_main_init failed #{init}, exiting.\n"
        exit init
      end

      puts "OCF client running\n"

      # main loop
      until @closing
        OC.main_poll
        sleep 100.milliseconds
      end

      puts "Shutting down IoTivity..."
      OC.obt_shutdown
      OC.main_shutdown
    end

    # -------------------------------------------------------------------------

    # Stops the IoTivity client.
    def stop
      @closing = true
    end

    # =======================================================================================
    # Callbacks
    # =======================================================================================

    # Module-level class method used as a callback for IoTivity's
    # `oc_do_ip_discovery` function. When called upon a discovery,
    # this method emits a `Discovery` event containing all information
    # relevant for the discovered device.
    def self.discovery_cb(di, uri,
                          types : OC::StringArray,
                          iface_mask : OC::InterfaceMask,
                          endpoints : OC::Endpoint*,
                          bm : OC::ResourceProperties,
                          user_data)
      return OC::DiscoveryFlags::ContinueDiscovery
    end

    # ---------------------------------------------------------------------------------------

    # Module-level class method used as a callback for IoTivity's
    # `oc_do_ip_discovery_all` function. When called upon a discovery,
    # this method emits a `Discovery` event containing all information
    # relevant for the discovered device.
    def self.discovery_all_cb(device_id, uri,
                              types : OC::StringArray,
                              ifs,
                              endpoints : OC::Endpoint*,
                              bm : OC::ResourceProperties,
                              more_for_this_device, user_data)
      uuid, uri = String.new(device_id), String.new(uri)

      @@ddev ||= Device.new uuid, endpoints
      dev = @@ddev.not_nil!
      dev.res[uri] = Resource.new interfaces: Interface.new(ifs)

      if more_for_this_device.zero?
        client = Box(Client).unbox(user_data)
        client.discovered << dev
        client.emit Discovery, dev
        @@ddev = nil
      end

      return OC::DiscoveryFlags::ContinueDiscovery
    end

    # ---------------------------------------------------------------------------------------

    # Module-level class method used as a callback for IoTivity's
    # `oc_obt_perform_just_works_otm` function. It retrieves information
    # about the success or failure of an onboarding request and updates the
    # client's `#onboard?` property accordingly.
    def self.onboarding_cb(uuid : OC::UUID*, status : LibC::Int, user_data : Void*)
      if status >= 0
        puts "Successfully performed OTM on device with UUID"
      else
        puts "ERROR performing ownership transfer on device"
      end
    end

    # =======================================================================================
    # Helper functions
    # =======================================================================================

  end # module Client

end # module Mastory::IoT
