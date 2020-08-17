require "event_handler"
require "log"
require "uuid"
require "json"

require "./resource"
require "./device"

module IoTivity

  # An IoTivity client.
  module Client
    include EventHandler

    # =======================================================================================
    # Constants
    # =======================================================================================

    Log = ::Log.for("IoTivity::Client")

    # =======================================================================================
    # Events
    # =======================================================================================

    event Discovery, di : UUID, resource : Resource, endpoints : ListOfEndpoints
    event Response, sender : OC::Endpoint*, status : OC::Status, payload : String
    event Notification, sender : OC::Endpoint*, uri : String, payload : String

    # =======================================================================================
    # Properties
    # =======================================================================================

    # The device associated with the client itself. Needed for onboarding.
    property myself do
      oc_uuid = OC.core_get_device_id(0).value.id
      uuid = UUID.new oc_uuid
      Device.new uuid, Pointer(OC::Endpoint).null
    end

    # ---------------------------------------------------------------------------------------

    # A list of all devices discovered.
    property discovered = [] of Device

    # ---------------------------------------------------------------------------------------

    # Indicates the client is about to quit.
    getter? closing = false

    # =========================================================================
    # Methods
    # =========================================================================

    # Searches the network for a *resource_type* by invoking
    # `oc_do_ip_discovery`.
    # When a resource is found that has the *resource_type* listed in its
    # `rt` array, a `Discovery` event is triggered.
    def discover(resource_type : String)
      OC.do_ip_discovery resource_type,
        ->(di, uri, rts, ifs, eps, bm, user_data) {
          str = String.new di
          uuid = UUID.new str.lchop("ocf://")
          res = IoTivity::Resource.new \
            uri: String.new(uri),
            types: [] of String, #TODO
            interfaces: IoTivity::Interface.new(ifs),
            properties: IoTivity::ResourceProperties::Discoverable #TODO
          endpoints = IoTivity::ListOfEndpoints.new eps
          client = Box(self).unbox(user_data)
          client.emit Discovery, uuid, res, endpoints
          return OC::DiscoveryFlags::ContinueDiscovery #TODO
        }, Helper.pClient
    end

    # ---------------------------------------------------------------------------------------

    # Searches the network for all available resouces by invoking
    # `oc_do_ip_discovery_all`.
    # When a resource is found, a `Discovery` event is triggered.
    def discover_all
      OC.do_ip_discovery_all \
        ->(di, uri, rts, ifs, eps, bm, more_cbs, user_data) {
          str = String.new di
          uuid = UUID.new str.lchop("ocf://")
          res = IoTivity::Resource.new \
            uri: String.new(uri),
            types: [] of String, #TODO
            interfaces: IoTivity::Interface.new(ifs),
            properties: IoTivity::ResourceProperties::Discoverable #TODO
          endpoints = IoTivity::ListOfEndpoints.new eps
          client = Box(self).unbox(user_data)
          client.emit Discovery, uuid, res, endpoints
          return OC::DiscoveryFlags::ContinueDiscovery #TODO
       }, Helper.pClient
    end

    # ---------------------------------------------------------------------------------------

    # Sends a GET request via an invocation of `oc_do_get`.
    # When a response from the server arrives, a `Response` event is emitted.
    def send_GET(to uri, at endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
      sent = OC.do_get uri, endpoints.eps, query,
        ->(response : OC::ClientResponse*) {
          r = response.value
          rep = r.payload
          size = OC.rep_to_json rep, nil, 0, 1
          json = Pointer(UInt8).malloc(size + 1)
          OC.rep_to_json rep, json, size + 1, 1
          client = Box(self).unbox r.user_data
          client.emit Response, r.endpoint, r.code, String.new(json)
        },
        qos, Helper.pClient

      if sent >= 0
        Log.info { "Sent GET request" }
      else
        Log.warn { "Failed to send GET request" }
      end
    end

    # ---------------------------------------------------------------------------------------

    # Sends a POST request via an invocation of `oc_init_post`/`oc_do_post`.
    # When a response from the server arrives, a `Response` event is emitted.
    def send_POST(payload, to uri, at endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
      # This is the 5-step way the C example client does it:
      # 1) oc_init_post(uri, endpoint, NULL, cb, LOW_QOS, NULL);
      # 2) oc_rep_start_root_object();
      # 3) oc_rep_set_...
      # ...
      # 4) oc_rep_end_root_object();
      # 5) oc_do_post();

      # oc_init_post(uri, endpoint, NULL, cb, LOW_QOS, NULL);
      init = OC.init_post uri, endpoints.eps, query,
        ->(response : OC::ClientResponse*) {
          r = response.value
          rep = r.payload
          size = OC.rep_to_json rep, nil, 0, 1
          json = Pointer(UInt8).malloc(size + 1)
          OC.rep_to_json rep, json, size + 1, 1
          client = Box(self).unbox r.user_data
          client.emit Response, r.endpoint, r.code, String.new(json)
        },
        qos, Helper.pClient

      # oc_rep_start_root_object();
      # oc_rep_set_...
      # oc_rep_end_root_object();
      # -> These are C macros that we replace by their
      #    dynamic JNI counterparts:
      prepare_cbor from: payload

      # oc_do_post();
      OC.do_post
    end

    # ---------------------------------------------------------------------------------------

    def observe(uri, at endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
      sent = OC.do_observe uri, endpoints.eps, query,
        ->(response : OC::ClientResponse*) {
          r = response.value
          rep = r.payload
          size = OC.rep_to_json rep, nil, 0, 1
          json = Pointer(UInt8).malloc(size + 1)
          OC.rep_to_json rep, json, size + 1, 1
          client, loc = Box({self, String}).unbox r.user_data
          client.emit Notification, r.endpoint, loc, String.new(json)
        },
        qos, Box.box( {self, uri} )

      if sent >= 0
        Log.info { "Sent observe request" }
      else
        Log.warn { "Failed to send observe request" }
      end
    end

    # ---------------------------------------------------------------------------------------

    def stop_observing(uri, at endpoints : IoTivity::ListOfEndpoints)
      sent = OC.stop_observe uri, endpoints.eps
      if sent >= 0
        Log.info { "Sent stop observe request" }
      else
        Log.warn { "Failed to send stop observe request" }
      end
    end

    # ---------------------------------------------------------------------------------------

    def discover_myself
      puts "Retrieving my own credentials..."
      ptr = OC.obt_retrieve_own_creds
      creds = ptr.value
      oc_uuid = creds.rowneruuid.id
      @myself = IoTivity::Device.new \
        uuid: UUID.new(oc_uuid),
        endpoints: Pointer(OC::Endpoint).null
      puts "UUID of myself is #{myself.uuid.colorize.bold.yellow}"
      ptr = OC.core_get_device_id(0)
      u = ptr.value
      uu = UUID.new u.id
      puts "For comparison: OC.core_get_device_id returns #{uu.colorize.bold.yellow}"
    end

    # ---------------------------------------------------------------------------------------

    # Sets up and runs the IoTivity client.
    # *storage_dir* should name a path - either absolute or relative to the
    # current working directory - in which IoTivity will load/store credentials,
    # certificates and authentication info.
    def run_client(storage_dir)
      if storage_dir.is_a? Path
        storage_dir = storage_dir.to_s
      end

      Helper.pClient = Box.box self

      # What follows is basically the Crystal translation of the C main()
      # function of IoTivity's example "apps/client_linux.c"

      # Register signal handler for Ctrl+C abortion with proper cleanup
      Signal::INT.trap do
        @closing = true
      end

      puts "Set up an OCF Client..."

      # LibIoTivity.on_discovery     = ->Client.discovery_cb
      # LibIoTivity.on_discovery_all = ->Client.discovery_all_cb

      # initialize the handlers structure
      handler = OC::Handler.new \
        init: ->{
          puts "Init callback"
          ip = OC.init_platform("ocf", nil, nil)
          ret = OC.add_device("/oic/d",
                              "oic.d.dashboard",
                              "Dashboard",
                              "ocf.2.0.5",
                              "ocf.res.1.3.0, ocf.sh.1.3.0",
                              ->(data : Void*) {
                                puts "Device added successfully (this is the callback)"
                                # puts "Retrieving my own credentials..."
                              #   ptr = OC.obt_retrieve_own_creds
                              #   creds = ptr.value
                              #   oc_uuid = creds.rowneruuid.id
                              #   client = Box(IoTivity::Client).unbox data
                              #   client.myself = IoTivity::Device.new \
                              #     uuid: UUID.new(oc_uuid),
                              #     endpoints: Pointer(OC::Endpoint).null
                              },
                              Helper.pClient
                             )
          puts "Called init_platform (ret: #{ip}) and add_device (ret: #{ret})"
          ret
        },
        signal_event_loop: ->{},
        requests_entry:    ->{}

      # #ifdef OC_SECURITY
      puts "Initialize Secure Resources"
      OC.storage_config storage_dir
      # #endif /* OC_SECURITY */

      # #ifdef OC_SECURITY
      # /* please comment out if the server:
      #   - have no display capabilities to display the PIN value
      #   - server does not require to implement RANDOM PIN (oic.sec.doxm.rdp) onboarding mechanism
      # */
      # oc_set_random_pin_callback(random_pin_cb, NULL);
      # #endif /* OC_SECURITY */

      OC.set_con_res_announced(0)

      # start the stack
      puts "Calling oc_main_init"
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
      # OC.obt_shutdown
      OC.main_shutdown
    end

    # -------------------------------------------------------------------------

    # Stops the IoTivity client.
    def quit_client
      @closing = true
    end

  end # module Client

end # module Mastory::IoT
