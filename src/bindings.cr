require "./helper"

# =============================================================================
# C bindings for OCF/IoTivity
# =============================================================================

@[Link(ldflags: "-DOC_CLIENT -DOC_SERVER -DOC_SECURITY -DOC_PKI -DNO_MAIN \
                 -liotivity-lite-client -liotivity-lite-server")]
lib OC

  # =======================================================================================
  # Aliases
  # =======================================================================================

  alias AddDeviceCallback = Void* -> Void
  alias ClockTime = UInt64
  alias FactoryPresetsCallback = LibC::SizeT, Void* -> Void
  alias InitPlatformCallback = Void* -> Void
  alias ResponseHandler = ClientResponse* -> Void
  alias DiscoveryHandler = LibC::Char*, LibC::Char*, StringArray, InterfaceMask, Endpoint*, ResourceProperties, Void* -> DiscoveryFlags
  alias DiscoveryAllHandler = LibC::Char*, LibC::Char*, StringArray, LibC::Int, Endpoint*, ResourceProperties, LibC::Int, Void* -> DiscoveryFlags
  alias ObtDeviceStatusCb = UUID*, LibC::Int, Void* -> Void
  alias ObtDiscoveryCb = UUID*, Endpoint*, Void* -> Void

  # oc_helpers.h
  alias Handle = Mmem
  alias String = Mmem
  alias Array = Mmem
  alias StringArray = Mmem
  alias ByteStringArray = Mmem

  # =======================================================================================
  # Enums
  # =======================================================================================

  enum DiscoveryFlags
    StopDiscovery
    ContinueDiscovery
  end

  @[Flags]
  enum InterfaceMask
    Baseline = 1 << 1
    LL = 1 << 2
    B = 1 << 3
    R = 1 << 4
    RW = 1 << 5
    A = 1 << 6
    S = 1 << 7
    Create = 1 << 8
  end

  @[Flags]
  enum TransportFlags
    Discovery = 1 << 0
    Secured = 1 << 1
    IPv4 = 1 << 2
    IPv6 = 1 << 3
    TCP = 1 << 4
    GATT = 1 << 5
    Multicast = 1 << 6
  end

  enum Version
    OCFv1_0_0 = 2048
    OICv1_1_0 = 2112
  end

  @[Flags]
  enum ResourceProperties
    Discoverable = (1 << 0)
    Observable = (1 << 1)
    Secure = (1 << 4)
    Periodic = (1 << 6)
  end

  enum RepValueType
    NIL = 0
    INT = 0x01
    DOUBLE = 0x02
    BOOL = 0x03
    BYTE_STRING = 0x04
    STRING = 0x05
    OBJECT = 0x06
    ARRAY = 0x08
    INT_ARRAY = 0x09
    DOUBLE_ARRAY = 0x0A
    BOOL_ARRAY = 0x0B
    BYTE_STRING_ARRAY = 0x0C
    STRING_ARRAY = 0x0D
    OBJECT_ARRAY = 0x0E
  end

  enum QoS
    High = 0
    Low
  end

  enum Status
    OK = 0
    CREATED
    CHANGED
    DELETED
    NOT_MODIFIED
    BAD_REQUEST
    UNAUTHORIZED
    BAD_OPTION
    FORBIDDEN
    NOT_FOUND
    METHOD_NOT_ALLOWED
    NOT_ACCEPTABLE
    REQUEST_ENTITY_TOO_LARGE
    UNSUPPORTED_MEDIA_TYPE
    INTERNAL_SERVER_ERROR
    NOT_IMPLEMENTED
    BAD_GATEWAY
    SERVICE_UNAVAILABLE
    GATEWAY_TIMEOUT
    PROXYING_NOT_SUPPORTED
    NUMBER_OF_STATUS_CODES
    IGNORE
    PING_TIMEOUT
  end

  # =======================================================================================
  # Structs
  # =======================================================================================

  # util/oc_mmem.h
  struct Mmem
    next : Mmem*
    size : LibC::SizeT
    ptr : Void*
  end

  struct UUID
    id : UInt8[16]
  end

  struct IPv6Addr
    port : UInt16
    address : UInt8[16]
    scope : UInt8
  end

  struct IPv4Addr
    port : UInt16
    address : UInt8[4]
  end

  struct LEAddr
    type : UInt8
    address : UInt8[6]
  end

  union DevAddr
    ipv6 : IPv6Addr
    ipv4 : IPv4Addr
    bt : LEAddr
  end

  struct Endpoint
    next : Endpoint*
    device : LibC::SizeT
    flags : TransportFlags
    di : UUID
    addr : DevAddr
    # addr_local : DevAddr
    interface_index : LibC::Int
    priority : UInt8
    version : Version
  end

  struct FactoryPresets
    cb : FactoryPresetsCallback
    data : Void*
  end

  struct Handler
    init : -> LibC::Int
    signal_event_loop : -> Void
    requests_entry : -> Void
    register_resources : -> Void
  end

  union RepValue
    integer : Int64
    boolean : LibC::Int
    double_p : LibC::Double
    string : String
    array : Array
    object : Rep*
    object_array : Rep*
  end

  struct Rep
    type : RepValueType
    next : Rep*
    name : String
    value : RepValue
  end

  struct ClientResponse
    payload : Rep*
    endpoint : Endpoint*
    client_cb : Void*
    user_data : Void*
    code : Status
    observe_option : LibC::Int
  end

  # =======================================================================================
  # Function bindings
  # =======================================================================================

  fun add_device = oc_add_device(uri : LibC::Char*,	rt : LibC::Char*, name : LibC::Char*, spec_version : LibC::Char*, data_model_version : LibC::Char*, add_device_cb : AddDeviceCallback, data : Void*) : LibC::Int
  fun init_platform = oc_init_platform(mfg_name : LibC::Char*, init_platform_cb : InitPlatformCallback, data : Void*) : LibC::Int
  fun main_init = oc_main_init(handler : Handler*) : LibC::Int
  fun main_shutdown = oc_main_shutdown() : Void
  fun main_poll = oc_main_poll() : ClockTime
  fun storage_config = oc_storage_config(store : LibC::Char*) : LibC::Int
  fun set_factory_presets_cb = oc_set_factory_presets_cb(cb : FactoryPresetsCallback, data : Void*) : Void
  fun set_con_res_announced = oc_set_con_res_announced(announce	: LibC::Int) : Void
  fun do_ip_discovery = oc_do_ip_discovery(rt : LibC::Char*, handler : DiscoveryHandler, user_data : Void* ) : LibC::Int
  fun do_ip_discovery_all = oc_do_ip_discovery_all(handler : DiscoveryAllHandler, user_data : Void* ) : LibC::Int
  fun do_get = oc_do_get(uri : LibC::Char*, endpoint : Endpoint*, query : LibC::Char*, handler : ResponseHandler, qos : QoS, user_data : Void*) : LibC::Int
  fun rep_to_json = oc_rep_to_json(rep : Rep*, buf : LibC::Char*, buf_size : LibC::SizeT, pretty_print : LibC::Int) : LibC::SizeT
  fun free_server_endpoints = oc_free_server_endpoints(endpoint : Endpoint*) : Void

  fun obt_init = oc_obt_init() : LibC::Int
  fun obt_discover_owned_devices = oc_obt_discover_owned_devices(cb : ObtDiscoveryCb, data : Void*) : LibC::Int
  fun obt_discover_unowned_devices = oc_obt_discover_unowned_devices(cb : ObtDiscoveryCb, data : Void*) : LibC::Int
  fun obt_perform_just_works_otm = oc_obt_perform_just_works_otm(uuid : UUID*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_device_hard_reset = oc_obt_device_hard_reset(uuid : UUID*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_shutdown = oc_obt_shutdown() : Void

end
