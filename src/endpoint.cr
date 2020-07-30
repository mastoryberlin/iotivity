require "socket"
require "uuid"

require "./bindings"

module IoTivity

  # A wrapper for IoTivity's `oc_endpoint_t` (except the pointer to the
  # `next` endpoint for lists - you should iterate a `ListOfEndpoints`
  # instead of directly using the C linked list).
  record Endpoint,
    device : LibC::SizeT,
    flags : OC::TransportFlags,
    di : UUID,
    addr : Socket::IPAddress,
    # addr_local : DevAddr,
    interface_index : LibC::Int,
    priority : UInt8,
    version : OC::Version

  # ---------------------------------------------------------------------------------------

  # A wrapper for IoTivity's `oc_endpoint_t*` lists returned by
  # discovery functions and needed to send GET/POST/DELETE requests.
  # Currently, this is implemented as an opaque data structure;
  # thus it is not meant to be investigated for the actual IP addresses.
  # Its main use is to provide a more convenient way to persistently store
  # endpoint information by wrapping calls to `oc_endpoint_list_copy`.
  struct ListOfEndpoints
    include Iterable(Endpoint)

    # =======================================================================================
    # Properties
    # =======================================================================================

    getter eps : OC::Endpoint* = Pointer(OC::Endpoint).null

    # =======================================================================================
    # Constructors
    # =======================================================================================

    def initialize(eps : OC::Endpoint*)
      OC.endpoint_list_copy pointerof(@eps), eps
    end

    # ---------------------------------------------------------------------------------------

    def initialize(other : ListOfEndpoints)
      OC.endpoint_list_copy pointerof(@eps), other.eps
    end

    # =======================================================================================
    # Required methods
    # =======================================================================================

    def each : Iterator(Endpoint)
      EndpointIterator.new(@eps)
    end

  end # struct ListOfEndpoints

  # ---------------------------------------------------------------------------------------

  private struct EndpointIterator
    include Iterator(Endpoint)

    def initialize(@ptr : OC::Endpoint*)
    end

    def next
      if @ptr
        e = @ptr.value
        OC.endpoint_to_string @ptr, out mmem
        addr = String.new(Helper.mmem_to_cstring mmem)
        @ptr = e.next
        # oc = case e.flags
        #      when .ipv4? then e.addr.ipv4
        #      else             e.addr.ipv6
        #      end
        # addr = oc.is_a?(OC::IPv4Addr) ? String.new(oc.address) : String.new(oc.address)
        # port = oc.port
        Endpoint.new \
          device: e.device,
          flags: e.flags,
          di: UUID.new(e.di.id),
          addr: Socket::IPAddress.parse(addr),
          interface_index: e.interface_index,
          priority: e.priority,
          version: e.version
      else
        stop
      end
    end
  end

end # module IoTivity
