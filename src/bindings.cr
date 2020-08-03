require "./helper"

# =============================================================================
# C bindings for OCF/IoTivity
# =============================================================================

@[Link(ldflags: "-DOC_CLIENT -DOC_SERVER -DNO_MAIN -DOC_PKI -DOC_SECURITY -DOC_DYNAMIC_ALLOCATION \
                 -I/home/pi/iot-lite/iotivity-lite -I/home/pi/iot-lite/iotivity-lite/include \
                 -I/home/pi/iot-lite/iotivity-lite/port/linux -liotivity-lite-client-server /tmp/helper.c")]
lib OC

  # =======================================================================================
  # Aliases
  # =======================================================================================

  alias AddDeviceCallback = Void* -> Void
  alias Array = Mmem # oc_helpers.h
  alias ByteStringArray = Mmem # oc_helpers.h
  alias ClockTime = UInt64
  alias DiscoveryAllHandler = LibC::Char*, LibC::Char*, StringArray, LibC::Int, Endpoint*, ResourceProperties, LibC::Int, Void* -> DiscoveryFlags
  alias DiscoveryHandler = LibC::Char*, LibC::Char*, StringArray, LibC::Int, Endpoint*, ResourceProperties, Void* -> DiscoveryFlags
  alias FactoryPresetsCallback = LibC::SizeT, Void* -> Void
  alias GetPropertiesCb = Resource*, IoTivity::Interface*, Void* -> Void # oc_ri.h
  alias InitPlatformCallback = Void* -> Void
  alias Handle = Mmem # oc_helpers.h

  alias ObtACLCb = SecACL*, Void* -> Void
  alias ObtDeviceStatusCb = UUID*, LibC::Int, Void* -> Void
  alias ObtDiscoveryCb = UUID*, Endpoint*, Void* -> Void
  alias ObtStatusCb = LibC::Int, Void* -> Void

  alias ResponseHandler = ClientResponse* -> Void
  alias RequestCallback = Request*, IoTivity::Interface, Void* -> Void
  alias SetPropertiesCb = Resource*, Rep*, Void* -> LibC::Int # oc_ri.h
  alias String = Mmem # oc_helpers.h
  alias StringArray = Mmem # oc_helpers.h

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

  # enum CborError
  #   CborNoError = 0
  #
  #   # errors in all modes
  #   CborUnknownError
  #   CborErrorUnknownLength         # request for length in array, map, or string with indeterminate length
  #   CborErrorAdvancePastEOF
  #   CborErrorIO
  #
  #   # parser errors streaming errors
  #   CborErrorGarbageAtEnd = 256
  #   CborErrorUnexpectedEOF
  #   CborErrorUnexpectedBreak
  #   CborErrorUnknownType           # can only happen in major type 7
  #   CborErrorIllegalType           # type not allowed here
  #   CborErrorIllegalNumber
  #   CborErrorIllegalSimpleType     # types of value less than 32 encoded in two bytes
  #
  #   # parser errors in strict mode parsing only
  #   CborErrorUnknownSimpleType = 512
  #   CborErrorUnknownTag
  #   CborErrorInappropriateTagForType
  #   CborErrorDuplicateObjectKeys
  #   CborErrorInvalidUtf8TextString
  #   CborErrorExcludedType
  #   CborErrorExcludedValue
  #   CborErrorImproperValue
  #   CborErrorOverlongEncoding
  #   CborErrorMapKeyNotString
  #   CborErrorMapNotSorted
  #   CborErrorMapKeysNotUnique
  #
  #   # encoder errors
  #   CborErrorTooManyItems = 768
  #   CborErrorTooFewItems
  #
  #   # internal implementation errors
  #   CborErrorDataTooLarge = 1024
  #   CborErrorNestingTooDeep
  #   CborErrorUnsupportedType
  #
  #   # errors in converting to JSON
  #   CborErrorJsonObjectKeyIsAggregate = 1280
  #   CborErrorJsonObjectKeyNotString
  #   CborErrorJsonNotImplemented
  #
  #   CborErrorOutOfMemory = (int) (~0U / 2 + 1)
  #   CborErrorInternalError = (int) (~0U / 2)    # INT_MAX on two's complement machines
  # end

  # =======================================================================================
  # Types: Structs, unions, enums
  # =======================================================================================

  # [ A ] ---------------------------------------------------------------------------------

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

  struct ACERes
    next : ACERes*
    href : String
    interfaces : InterfaceMask
    types : StringArray
    wildcard : ACEWildcard
  end

  union ACESubject
    uuid : UUID
    role : ACESubjectRole
    conn : ACEConnectionType
  end

  struct ACESubjectRole
    role : String
    authority : String
  end

  enum ACESubjectType
    UUID = 0
    Role
    Conn
  end

  enum ACEWildcard
    None = 0
    All = 0x111
    AllSecured = 0x01
    AllPublic = 0x10
  end

  # [ B ] ---------------------------------------------------------------------------------
  # [ C ] ---------------------------------------------------------------------------------

  struct CborEncoder
    data : CborEncoderDataUnion
    end_of_data : UInt8* # this member is named "end" in C struct
    remaining : LibC::SizeT
    flags : LibC::Int
  end

  union CborEncoderDataUnion
    ptr : UInt8*
    bytes_needed : LibC::SizeT
  end

  struct ClientResponse
    payload : Rep*
    endpoint : Endpoint*
    client_cb : Void*
    user_data : Void*
    code : Status
    observe_option : LibC::Int
  end

  # [ D ] ---------------------------------------------------------------------------------
  union DevAddr
    ipv6 : IPv6Addr
    ipv4 : IPv4Addr
    bt : LEAddr
  end

  # [ E ] ---------------------------------------------------------------------------------

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

  enum Enum
    Aborted = 1
    Active
    Airdry
    ArmedAway
    ArmedInstant
    ArmedMaximum
    ArmedNightstay
    ArmedStay
    Aroma
    Ai
    Auto
    Boiling
    Brewing
    Cancelled
    Circulating
    Cleaning
    Clothes
    Completed
    Cool
    Delicate
    Disabled
    Down
    Dual
    Dry
    Enabled
    Extended
    Fan
    Fast
    FilterMaterial
    Focused
    Grinding
    Heating
    Heavy
    Idle
    Ink
    InkBlack
    InkCyan
    InkMagenta
    InkTricolour
    InkYellow
    KeepWarm
    Normal
    NotSupported
    Pause
    Pending
    PendingHeld
    PermaPress
    Prewash
    Processing
    Pure
    Quick
    Quiet
    Rinse
    Sectored
    Silent
    Sleep
    Smart
    Spot
    Steam
    Stopped
    Spin
    Testing
    Toner
    TonerBlack
    TonerCyan
    TonerMagenta
    TonerYellow
    Warm
    Wash
    Wet
    Wind
    WrinklePrevent
    ZigZag
  end

  # [ F ] ---------------------------------------------------------------------------------

  struct FactoryPresets
    cb : FactoryPresetsCallback
    data : Void*
  end

  # [ G ] ---------------------------------------------------------------------------------
  # [ H ] ---------------------------------------------------------------------------------

  struct Handler
    init : -> LibC::Int
    signal_event_loop : -> Void
    register_resources : -> Void
    requests_entry : -> Void
  end

  # [ I ] ---------------------------------------------------------------------------------

  struct IPv4Addr
    port : UInt16
    address : UInt8[4]
  end

  struct IPv6Addr
    port : UInt16
    address : UInt8[16]
    scope : UInt8
  end

  # [ J ] ---------------------------------------------------------------------------------
  # [ K ] ---------------------------------------------------------------------------------
  # [ L ] ---------------------------------------------------------------------------------

  struct LEAddr
    type : UInt8
    address : UInt8[6]
  end

  # [ M ] ---------------------------------------------------------------------------------

  enum Method
    GET = 1; POST; PUT; DELETE
  end

  struct Mmem # util/oc_mmem.h
    next : Mmem*
    size : LibC::SizeT
    ptr : Void*
  end

  # [ N ] ---------------------------------------------------------------------------------
  # [ O ] ---------------------------------------------------------------------------------
  # [ P ] ---------------------------------------------------------------------------------

  enum PosDescription
    Unknown = 1
    Top
    Bottom
    Left
    Right
    Centre
    TopLeft
    BottomLeft
    CentreLeft
    CentreRight
    BottomRight
    TopRight
    TopCentre
    BottomCentre
  end

  union PropertiesCbUnion
    set_props : SetPropertiesCb
    get_props : GetPropertiesCb
  end

  struct PropertiesCb
    cb : PropertiesCbUnion
    user_data : Void*
  end

  # [ Q ] ---------------------------------------------------------------------------------
  # [ R ] ---------------------------------------------------------------------------------

  struct RequestHandler
    cb : RequestCallback
    user_data : Void*
  end

  struct Resource
    next : Resource*
    device : LibC::SizeT
    name : String
    uri : String
    types : StringArray
    interfaces : Int32
    default_interface : Int32
    properties : Int32
    get_handler : RequestHandler
    put_handler : RequestHandler
    post_handler : RequestHandler
    delete_handler : RequestHandler
    get_properties : PropertiesCb
    set_properties : PropertiesCb
    tag_pos_rel : LibC::Double[3]
    tag_pos_desc : PosDescription
    tag_func_desc : Enum
    num_observers : UInt8
  #ifdef OC_COLLECTIONS
    num_links : UInt8
  #endif /* OC_COLLECTIONS */
    observe_period_seconds : UInt16
  end

  struct Rep
    type : RepValueType
    next : Rep*
    name : String
    value : RepValue
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

  struct Request
    origin : Endpoint*
    resource : Resource*
    query : LibC::Char*
    query_len : LibC::SizeT
    request_payload : Rep*
    response : Response*
  end

  struct Response
    separate_response : SeparateResponse*
    response_buffer : ResponseBuffer*
  end

  struct ResponseBuffer
    buffer : UInt8*
    buffer_size : UInt16
    response_length : UInt16
    code : LibC::Int
  end

  # [ S ] ---------------------------------------------------------------------------------

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

  struct SecACL
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(subject) macro defined in oc_list.h
    subject_list : Void*
    name : Void** # = oc_list_t
    rowneruuid : UUID
  end

  struct SecCreds
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(creds) macro defined in oc_list.h
    creds_list : Void*
    name : Void** # = oc_list_t
    rowneruuid : UUID
  end

  struct SeparateResponse
    # The following 2 lines are the translation of
    # the OC_LIST_STRUCT(requests) macro defined in oc_list.h
    requests_list : Void*
    name : Void** # = oc_list_t
    active : LibC::Int
  #ifdef OC_DYNAMIC_ALLOCATION
    buffer : UInt8*
  #else  /* OC_DYNAMIC_ALLOCATION */
    # uint8_t buffer[OC_MAX_APP_DATA_SIZE];
  #endif /* !OC_DYNAMIC_ALLOCATION */
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

  # [ T ] ---------------------------------------------------------------------------------
  # [ U ] ---------------------------------------------------------------------------------

  struct UUID
    id : UInt8[16]
  end

  # struct CoapTransaction
  #   next : CoapTransaction*
  #   mid : UInt16
  #   retrans_timer : ETimer
  #   retrans_counter : UInt8
  #   message : Message*
  # end

  # =======================================================================================
  # Function bindings
  # =======================================================================================

  fun add_device = oc_add_device(uri : LibC::Char*,	rt : LibC::Char*, name : LibC::Char*, spec_version : LibC::Char*, data_model_version : LibC::Char*, add_device_cb : AddDeviceCallback, data : Void*) : LibC::Int
  fun add_resource = oc_add_resource(resource : Resource*) : LibC::Int
  fun core_get_device_id = oc_core_get_device_id(device : LibC::SizeT) : UUID*
  fun do_get = oc_do_get(uri : LibC::Char*, endpoint : Endpoint*, query : LibC::Char*, handler : ResponseHandler, qos : QoS, user_data : Void*) : LibC::Int
  fun do_ip_discovery = oc_do_ip_discovery(rt : LibC::Char*, handler : DiscoveryHandler, user_data : Void* ) : LibC::Int
  fun do_ip_discovery_all = oc_do_ip_discovery_all(handler : DiscoveryAllHandler, user_data : Void* ) : LibC::Int
  fun do_post = oc_do_post() : LibC::Int
  fun endpoint_list_copy = oc_endpoint_list_copy(dst : Endpoint**, src : Endpoint*) : Void
  fun	endpoint_to_string = oc_endpoint_to_string(endpoint : Endpoint*, endpoint_str : String*) : LibC::Int
  fun free_server_endpoints = oc_free_server_endpoints(endpoint : Endpoint*) : Void
  fun init_platform = oc_init_platform(mfg_name : LibC::Char*, init_platform_cb : InitPlatformCallback, data : Void*) : LibC::Int
  fun init_post = oc_init_post(uri : LibC::Char*, endpoint : Endpoint*, query : LibC::Char*, handler : ResponseHandler, qos : QoS, user_data : Void*) : LibC::Int

  fun jni_begin_root_object() : CborEncoder*
  fun jni_rep_end_root_object() : Void
  fun jni_rep_set_boolean(object : CborEncoder*, key : LibC::Char*, value : LibC::Int) : Void
  fun jni_rep_set_long(object : CborEncoder*, key : LibC::Char*, value : Int64) : Void
  fun jni_rep_set_double(object : CborEncoder*, key : LibC::Char*, value : LibC::Double) : Void
  fun jni_rep_set_text_string(object : CborEncoder*, key : LibC::Char*, value : LibC::Char*) : Void
  fun jni_rep_set_array(object : CborEncoder*, key : LibC::Char*) : CborEncoder*
  fun jni_rep_close_array(parent : CborEncoder*, arrayObject : CborEncoder*) : Void
  fun jni_rep_open_object(object : CborEncoder*, key : LibC::Char*) : CborEncoder*
  fun jni_rep_close_object(parent : CborEncoder*, object : CborEncoder*) : Void

  fun main_init = oc_main_init(handler : Handler*) : LibC::Int
  fun main_shutdown = oc_main_shutdown() : Void
  fun main_poll = oc_main_poll() : ClockTime
  fun new_resource = oc_new_resource(name : LibC::Char*, uri : LibC::Char*, num_resource_types : UInt8, device : LibC::SizeT) : Resource*

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

  fun parse_rep = oc_parse_rep(in_payload : LibC::Char*, payload_size : LibC::Int, out_rep : Rep**) : LibC::Int
  fun rep_to_json = oc_rep_to_json(rep : Rep*, buf : LibC::Char*, buf_size : LibC::SizeT, pretty_print : LibC::Int) : LibC::SizeT
  fun resource_bind_resource_interface = oc_resource_bind_resource_interface(resource : Resource*, iface_mask : IoTivity::Interface) : Void
  fun resource_bind_resource_type = oc_resource_bind_resource_type(resource : Resource*, type : LibC::Char*) : Void
  fun resource_set_default_interface = oc_resource_set_default_interface(resource : Resource*, iface_mask : IoTivity::Interface) : Void
  fun resource_set_discoverable = oc_resource_set_discoverable(resource : Resource*, state : LibC::Int) : Void
  fun resource_set_periodic_observable = oc_resource_set_periodic_observable(resource : Resource*, state : LibC::Int) : Void
  fun resource_set_request_handler = oc_resource_set_request_handler(resource : Resource*, method : Method, callback : RequestCallback, user_data : Void*) : Void
  fun set_factory_presets_cb = oc_set_factory_presets_cb(cb : FactoryPresetsCallback, data : Void*) : Void
  fun set_con_res_announced = oc_set_con_res_announced(announce	: LibC::Int) : Void
  fun storage_config = oc_storage_config(store : LibC::Char*) : LibC::Int

  # fun coap_set_payload(packet : Void*, payload : Void*, length : LibC::SizeT) : LibC::Int
  # fun coap_send_transaction(t : CoapTransaction*) : Void

end
