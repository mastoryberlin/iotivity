require "event_handler"
require "log"
require "uuid"

require "./resource"
require "./device"

module IoTivity

  # Mix-in to create an IoTivity client.
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
    event Response, from : OC::Endpoint*, code : OC::Status, payload : OC::Rep*

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

    # =======================================================================================
    # Class variables
    # =======================================================================================

    @@boxed_self : Void* = Pointer(Void).null

    # ---------------------------------------------------------------------------------------

    # "Class-global" helper variable to facilitate device discovery.
    @@ddev : Device? = nil

    # =========================================================================
    # Methods
    # =========================================================================

    macro included

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
            client = Box({{@type}}).unbox(user_data)
            client.emit Discovery, uuid, res, endpoints
            return OC::DiscoveryFlags::ContinueDiscovery #TODO
          },
          Box.box(self.as({{@type}}))
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
            client = Box({{@type}}).unbox(user_data)
            client.emit Discovery, uuid, res, endpoints
            return OC::DiscoveryFlags::ContinueDiscovery #TODO
         },
         Box.box(self.as({{@type}}))
      end

      # ---------------------------------------------------------------------------------------

      # Sends a GET request via an invocation of `oc_do_get` and returns
      # the response.
      def get(uri, from endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
        sent = OC.do_get uri, endpoints.eps, query,
          ->(response : OC::ClientResponse*){
            r = response.value
            client = Box({{@type}}).unbox r.user_data
            client.emit Response, r.endpoint, r.code, r.payload
          },
          qos, Box.box(self)

        if sent >= 0
          Log.info { "Sent GET request" }
        else
          Log.warn { "Failed to send GET request" }
        end

        once Response do |e|
          puts "Response arrived - code #{e.code}"
          if e.code.ok?
            puts "Received payload:"
            rep = e.payload
            puts "Determining JSON bufsize..."
            size = OC.rep_to_json rep, nil, 0, 1
            puts "Need #{size + 1} bytes"
            buf = Pointer(UInt8).malloc(size + 1)
            OC.rep_to_json rep, buf, size + 1, 1
            puts String.new(buf)
          end
        end
      end

      # ---------------------------------------------------------------------------------------

      # Sends a POST request and returns the response.
      def post(payload, to uri, at endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
        iter = endpoints.each
        iter.each do |ep|
          puts "One EP has flags: #{ep.flags}, addr: #{ep.addr.address}, port: #{ep.addr.port}"
          client = UDPSocket.new ep.flags.ipv6? ? Socket::Family::INET6
                                                : Socket::Family::INET
          # client.connect ep.addr
          client.send payload, to: ep.addr
          client.close
          break
        end
        # init = OC.init_post uri, endpoints.eps, query,
        #   ->(response : OC::ClientResponse*){
        #     r = response.value
        #     client = Box({{@type}}).unbox r.user_data
        #     client.emit Response, r.endpoint, r.code, r.payload
        #   },
        #   qos, Box.box(self)
        #
        # if init >= 0
        #   Log.info { "Initiated POST" }
        #
        #   rep = Pointer(OC::Rep).null
        #   parsed = OC.parse_rep payload, payload.size, pointerof(rep)
        #   if parsed >= 0
        #     Log.info { "Successfully parsed JSON into representation" }
        #     puts "Double checking: result of oc_rep_to_json is"
        #     size = OC.rep_to_json rep, nil, 0, 1
        #     puts "Need #{size + 1} bytes"
        #     buf = Pointer(UInt8).malloc(size + 1)
        #     OC.rep_to_json rep, buf, size + 1, 1
        #     puts String.new(buf)
        #     if OC.do_post >= 0
        #       Log.info { "Sent POST request" }
        #     else
        #       Log.warn { "Could not send POST" }
        #     end
        #
        #   else
        #     Log.warn { "Error parsing payload JSON" }
        #   end
        #
        # else
        #   Log.warn { "Failed to initiate POST request" }
        # end

        once Response do |e|
          puts "Response arrived - code #{e.code}"
          if e.code.ok?
            puts "Received payload:"
            rep = e.payload
            puts "Determining JSON bufsize..."
            size = OC.rep_to_json rep, nil, 0, 1
            puts "Need #{size + 1} bytes"
            buf = Pointer(UInt8).malloc(size + 1)
            OC.rep_to_json rep, buf, size + 1, 1
            puts String.new(buf)
          end
        end
      end

    end # macro included

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

      @@boxed_self = Box.box self

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
                              @@boxed_self
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

    # =======================================================================================
    # Helper functions
    # =======================================================================================

  end # module Client

end # module Mastory::IoT