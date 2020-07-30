require "./helper"

# =============================================================================
# C bindings for OCF/IoTivity
# =============================================================================

@[Link(ldflags: "-DOC_CLIENT -DOC_SERVER -DNO_MAIN -DOC_PKI -DOC_SECURITY -DOC_DYNAMIC_ALLOCATION \
                 -liotivity-lite-client-server")]
lib OC

  # =======================================================================================
  # Aliases
  # =======================================================================================

  alias AddDeviceCallback = Void* -> Void
  alias ClockTime = UInt64
  alias FactoryPresetsCallback = LibC::SizeT, Void* -> Void
  alias InitPlatformCallback = Void* -> Void
  alias ResponseHandler = ClientResponse* -> Void
  alias DiscoveryHandler = LibC::Char*, LibC::Char*, StringArray, LibC::Int, Endpoint*, ResourceProperties, Void* -> DiscoveryFlags
  alias DiscoveryAllHandler = LibC::Char*, LibC::Char*, StringArray, LibC::Int, Endpoint*, ResourceProperties, LibC::Int, Void* -> DiscoveryFlags

  alias ObtStatusCb = LibC::Int, Void* -> Void
  alias ObtDeviceStatusCb = UUID*, LibC::Int, Void* -> Void
  alias ObtDiscoveryCb = UUID*, Endpoint*, Void* -> Void
  alias ObtACLCb = SecACL*, Void* -> Void

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
    Ipv4 = 1 << 2
    Ipv6 = 1 << 3
    Tcp = 1 << 4
    Gatt = 1 << 5
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
    Nil = 0
    Int = 0x01
    Double = 0x02
    Bool = 0x03
    ByteString = 0x04
    String = 0x05
    Object = 0x06
    Array = 0x08
    IntArray = 0x09
    DoubleArray = 0x0A
    BoolArray = 0x0B
    ByteStringArray = 0x0C
    StringArray = 0x0D
    ObjectArray = 0x0E
  end

  enum QoS
    High = 0
    Low
  end

  enum Status
    OK = 0
    Created
    Changed
    Deleted
    NotModified
    BadRequest
    Unauthorized
    BadOption
    Forbidden
    NotFound
    MethodNotAllowed
    NotAcceptable
    RequestEntityTooLarge
    UnsupportedMediaType
    InternalServerError
    NotImplemented
    BadGateway
    ServiceUnavailable
    GatewayTimeout
    ProxyingNotSupported
    NumberOfStatusCodes
    Ignore
    PingTimeout
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
    register_resources : -> Void
    requests_entry : -> Void
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

  struct SecACL
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(subject) macro defined in oc_list.h
    subject_list : Void*
    name : Void** # = oc_list_t
    rowneruuid : UUID
  end

  struct ACESubjectRole
    role : String
    authority : String
  end

  union ACESubject
    uuid : UUID
    role : ACESubjectRole
    conn : ACEConnectionType
  end

  enum ACESubjectType
    UUID = 0
    Role
    Conn
  end

  enum ACEConnectionType
    AuthCrypt = 0
    AnonClear
  end

  @[Flags]
  enum ACEPermissions
    None      = 0
    Create    = (1 << 0)
    Retrieve  = (1 << 1)
    Update    = (1 << 2)
    Delete    = (1 << 3)
    Notify    = (1 << 4)
  end

  struct SecACE
    next : SecACE*
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(resources) macro defined in oc_list.h
    resources_list : Void*
    name : Void** # = oc_list_t
    subject_type : ACESubjectType
    subject : ACESubject
    aceid : LibC::Int
    permission : ACEPermissions
  end

  struct SecCreds
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(creds) macro defined in oc_list.h
    creds_list : Void*
    name : Void** # = oc_list_t
    rowneruuid : UUID
  end

  struct ACERes
    next : ACERes*
    href : String
    interfaces : InterfaceMask
    types : StringArray
    wildcard : ACEWildcard
  end

  enum ACEWildcard
    None = 0
    All = 0x111
    AllSecured = 0x01
    AllPublic = 0x10
  end

  # =======================================================================================
  # Function bindings
  # =======================================================================================

  fun core_get_device_id = oc_core_get_device_id(device : LibC::SizeT) : UUID*
  fun add_device = oc_add_device(uri : LibC::Char*,	rt : LibC::Char*, name : LibC::Char*, spec_version : LibC::Char*, data_model_version : LibC::Char*, add_device_cb : AddDeviceCallback, data : Void*) : LibC::Int
  fun init_platform = oc_init_platform(mfg_name : LibC::Char*, init_platform_cb : InitPlatformCallback, data : Void*) : LibC::Int
  fun init_post = oc_init_post(uri : LibC::Char*, endpoint : Endpoint*, query : LibC::Char*, handler : ResponseHandler, qos : QoS, user_data : Void*) : LibC::Int
  fun main_init = oc_main_init(handler : Handler*) : LibC::Int
  fun main_shutdown = oc_main_shutdown() : Void
  fun main_poll = oc_main_poll() : ClockTime
  fun storage_config = oc_storage_config(store : LibC::Char*) : LibC::Int
  fun set_factory_presets_cb = oc_set_factory_presets_cb(cb : FactoryPresetsCallback, data : Void*) : Void
  fun set_con_res_announced = oc_set_con_res_announced(announce	: LibC::Int) : Void
  fun do_ip_discovery = oc_do_ip_discovery(rt : LibC::Char*, handler : DiscoveryHandler, user_data : Void* ) : LibC::Int
  fun do_ip_discovery_all = oc_do_ip_discovery_all(handler : DiscoveryAllHandler, user_data : Void* ) : LibC::Int
  fun do_get = oc_do_get(uri : LibC::Char*, endpoint : Endpoint*, query : LibC::Char*, handler : ResponseHandler, qos : QoS, user_data : Void*) : LibC::Int
  fun do_post = oc_do_post() : LibC::Int
  fun free_server_endpoints = oc_free_server_endpoints(endpoint : Endpoint*) : Void
  fun endpoint_list_copy = oc_endpoint_list_copy(dst : Endpoint**, src : Endpoint*) : Void
  fun	endpoint_to_string = oc_endpoint_to_string(endpoint : Endpoint*, endpoint_str : String*) : LibC::Int
  fun rep_to_json = oc_rep_to_json(rep : Rep*, buf : LibC::Char*, buf_size : LibC::SizeT, pretty_print : LibC::Int) : LibC::SizeT
  fun parse_rep = oc_parse_rep(in_payload : LibC::Char*, payload_size : LibC::Int, out_rep : Rep**) : LibC::Int

  fun obt_init = oc_obt_init() : LibC::Int
  fun obt_discover_owned_devices = oc_obt_discover_owned_devices(cb : ObtDiscoveryCb, data : Void*) : LibC::Int
  fun obt_discover_unowned_devices = oc_obt_discover_unowned_devices(cb : ObtDiscoveryCb, data : Void*) : LibC::Int
  fun obt_perform_just_works_otm = oc_obt_perform_just_works_otm(uuid : UUID*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_perform_cert_otm = oc_obt_perform_cert_otm(uuid : UUID*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_retrieve_acl = oc_obt_retrieve_acl(uuid : UUID*, cb : ObtACLCb, data : Void*) : LibC::Int
  fun obt_retrieve_own_creds = oc_obt_retrieve_own_creds() : SecCreds*
  fun obt_provision_ace = oc_obt_provision_ace(subject : UUID*, ace : SecACE*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_provision_identity_certificate = oc_obt_provision_identity_certificate(uuid : UUID*, cb : ObtStatusCb, data : Void*) : LibC::Int
  fun obt_device_hard_reset = oc_obt_device_hard_reset(uuid : UUID*, cb : ObtDeviceStatusCb, data : Void*) : LibC::Int
  fun obt_shutdown = oc_obt_shutdown() : Void
  fun obt_new_ace_for_connection = oc_obt_new_ace_for_connection(conn	: ACEConnectionType) : SecACE*
  fun obt_new_ace_for_subject = oc_obt_new_ace_for_subject(uuid	: UUID*) : SecACE*
  fun obt_ace_new_resource = oc_obt_ace_new_resource(ace : SecACE*) : ACERes*
  fun obt_ace_resource_set_href = oc_obt_ace_resource_set_href(resource : ACERes*, href : LibC::Char*) : Void
  fun obt_ace_resource_set_wc = oc_obt_ace_resource_set_wc(resource : ACERes*, wc : ACEWildcard) : Void
  fun obt_ace_add_permission = oc_obt_ace_add_permission(ace : SecACE*, permission : ACEPermissions) : Void
  fun obt_free_ace = oc_obt_free_ace(ace : SecACE*) : Void

end