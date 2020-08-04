require "event_handler"
require "log"
require "uuid"
require "json"

require "./resource"
require "./device"

module IoTivity

  # An IoTivity client.
  class Client
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

    # Sends a GET request via an invocation of `oc_do_get` and returns
    # the response.
    def get(uri, from endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
      sent = OC.do_get uri, endpoints.eps, query,
        ->(response : OC::ClientResponse*){
          r = response.value
          client = Box(self).unbox r.user_data
          client.emit Response, r.endpoint, r.code, r.payload
        },
        qos, Helper.pClient

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
          size = OC.rep_to_json rep, nil, 0, 1
          buf = Pointer(UInt8).malloc(size + 1)
          OC.rep_to_json rep, buf, size + 1, 1
          puts String.new(buf)
        end
      end
    end

    # ---------------------------------------------------------------------------------------

    # Sends a POST request and returns the response.
    def post(payload, to uri, at endpoints : IoTivity::ListOfEndpoints, query = nil, qos = OC::QoS::Low)
      # This is the 5-step way the C example client does it:
      # 1) oc_init_post(uri, endpoint, NULL, cb, LOW_QOS, NULL);
      # 2) oc_rep_start_root_object();
      # 3) oc_rep_set_...
      # ...
      # 4) oc_rep_end_root_object();
      # 5) oc_do_post();

      return if payload.empty?

      # oc_init_post(uri, endpoint, NULL, cb, LOW_QOS, NULL);
      init = OC.init_post uri, endpoints.eps, query,
        ->(response : OC::ClientResponse*){
          r = response.value
          client = Box(self).unbox r.user_data
          client.emit Response, r.endpoint, r.code, r.payload
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

    # =======================================================================================
    # Helper functions
    # =======================================================================================

    private def prepare_cbor(from json)
      parser = JSON::PullParser.new json
      nesting = 0
      is_key = false
      key_name = ""
      rel = [] of OC::CborEncoder*
      log = Log.for("Parsing JSON -> CBOR")

      loop do
        log.context.set is_key: is_key,
                        key_name: key_name,
                        nesting: nesting,
                        rel_no: rel.size

        case parser.kind
        when .null?
          log.info { "Next entry is a null value" }
          null = parser.read_null
          if is_key
            raise "CBOR Format Error: Key string expected but got Null"
          else
            raise "CBOR Format Error: Null values are not supported"
          end

        when .bool?
          log.info { "Next entry is a boolean" }
          bool = parser.read_bool
          log.info { "Read #{bool}" }

          if is_key
            raise "CBOR Format Error: Key string expected but got Bool"
          else
            log.info &.emit "Calling OC.jni_rep_set_boolean rel.last", key_name: key_name, value: bool
            OC.jni_rep_set_boolean rel.last, key_name, bool
            is_key = true
          end

        when .int?
          log.info { "Next entry is an integer" }
          int = parser.read_int
          log.info { "Read #{int}" }

          if is_key
            raise "CBOR Format Error: Key string expected but got Int #{int}"
          else
            log.info &.emit "Calling OC.jni_rep_set_long rel.last", key_name: key_name, value: int
            OC.jni_rep_set_long rel.last, key_name, int
            is_key = true
          end

        when .float?
          log.info { "Next entry is a floating-point value" }
          float = parser.read_float
          log.info { "Read #{float}" }

          if is_key
            raise "CBOR Format Error: Key string expected but got Float"
          else
            log.info &.emit "Calling OC.jni_rep_set_double rel.last", key_name: key_name, value: float
            OC.jni_rep_set_double rel.last, key_name, float
            is_key = true
          end

        when .string?
          log.info { "Next entry is a string" }
          string = parser.read_string
          log.info { "Read #{string}" }

          if is_key
            log.info { "Setting key_name->\"#{string}\", is_key->false" }
            key_name = string
            is_key = false
          else
            log.info &.emit "Calling OC.jni_rep_set_text_string rel.last", key_name: key_name, value: string
            OC.jni_rep_set_text_string rel.last, key_name, string
            is_key = true
          end

        when .begin_array?
          log.info { "Next entry is a [ opening bracket" }
          parser.read_begin_array
          log.info { "Read beginning of array" }

          log.info &.emit "Calling OC.jni_rep_set_array rel.last", key_name: key_name
          sub = OC.jni_rep_set_array rel.last, key_name
          rel.push sub
          nesting += 1
          is_key = false

        when .end_array?
          log.info { "Next entry is a ] closing bracket" }
          parser.read_end_array
          log.info { "Read end of array" }

          sub = rel.pop
          log.info &.emit "Calling OC.jni_rep_close_array rel.last, sub"
          OC.jni_rep_close_array rel.last, sub
          nesting -= 1
          is_key = true

        when .begin_object?
          log.info { "Next entry is a { opening brace" }
          parser.read_begin_object
          log.info { "Read beginning of object" }

          if nesting.zero?
            log.info &.emit "Calling OC.jni_begin_root_object"
            root = OC.jni_begin_root_object
            rel.push root
          else
            log.info &.emit "Calling OC.jni_rep_open_object rel.last", key_name: key_name
            sub = OC.jni_rep_open_object rel.last, key_name
            rel.push sub
          end
          is_key = true
          nesting += 1

        when .end_object?
          log.info { "Next entry is a } closing brace" }
          parser.read_end_object
          log.info { "Read end of object" }

          nesting -= 1
          if nesting.zero?
            log.info &.emit "Calling OC.jni_rep_end_root_object"
            OC.jni_rep_end_root_object
          else
            sub = rel.pop
            log.info &.emit "Calling OC.jni_rep_close_object rel.last, sub"
            OC.jni_rep_close_object rel.last, sub
            is_key = true
          end

        when .eof?
          log.info { "Reached EOF of JSON - stop parsing" }
          break
        end
      end
    end

  end # module Client

end # module Mastory::IoT
