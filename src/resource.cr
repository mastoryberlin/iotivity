module IoTivity

  # The interfaces exposed by some particular resource.
  @[Flags]
  enum Interface
    Baseline = 1 << 1
    LL       = 1 << 2
    B        = 1 << 3
    R        = 1 << 4
    RW       = 1 << 5
    A        = 1 << 6
    S        = 1 << 7
    Create   = 1 << 8
  end

  # ---------------------------------------------------------------------------------------

  # Properties a particular resource may or may not have.
  @[Flags]
  enum ResourceProperties
    Discoverable = 1 << 0
    Observable   = 1 << 1
    Secure       = 1 << 4
    Periodic     = 1 << 6
  end

  # ---------------------------------------------------------------------------------------

  # An IoTivity resource.
  class Resource

    # =======================================================================================
    # Properties
    # =======================================================================================

    def default_interface=(i : Interface)
      OC.resource_set_default_interface @ptr, i
    end

    # ---------------------------------------------------------------------------------------

    getter on_get : Proc(OC::Request*, Interface, Void)? = nil
    def on_get=(get_handler : OC::Request*, Interface -> Void)
      @on_get = get_handler
      OC.resource_set_request_handler @ptr, OC::Method::GET,
        ->(request, interface, data){
          myself = Box(self).unbox data
          myself.on_get.not_nil!.call request, interface
        }, Box.box self
    end

    # ---------------------------------------------------------------------------------------

    getter on_post : Proc(OC::Request*, Interface, Void)? = nil
    def on_post=(post_handler : OC::Request*, Interface -> Void)
      @on_post = post_handler
      OC.resource_set_request_handler @ptr, OC::Method::POST,
        ->(request, interface, data){
          myself = Box(self).unbox data
          myself.on_post.not_nil!.call request, interface
        }, Box.box self
    end

    # ---------------------------------------------------------------------------------------

    getter on_put : Proc(OC::Request*, Interface, Void)? = nil
    def on_put=(put_handler : OC::Request*, Interface -> Void)
      @on_put = put_handler
      OC.resource_set_request_handler @ptr, OC::Method::PUT,
        ->(request, interface, data){
          myself = Box(self).unbox data
          myself.on_put.not_nil!.call request, interface
        }, Box.box self
    end

    # ---------------------------------------------------------------------------------------

    getter on_delete : Proc(OC::Request*, Interface, Void)? = nil
    def on_delete=(delete_handler : OC::Request*, Interface -> Void)
      @on_delete = delete_handler
      OC.resource_set_request_handler @ptr, OC::Method::DELETE,
        ->(request, interface, data){
          myself = Box(self).unbox data
          myself.on_delete.not_nil!.call request, interface
        }, Box.box self
    end

    # =======================================================================================
    # Instance variables
    # =======================================================================================

    @ptr : OC::Resource* = Pointer(OC::Resource).null

    # =======================================================================================
    # Constructor
    # =======================================================================================

    def initialize(@name : String, @uri : String, @types : Array(String),
                   @interfaces : Interface, @properties : ResourceProperties,
                   *, device = 0)
      res = OC.new_resource name, uri, types.size, device
      @types.each { |t| OC.resource_bind_resource_type res, t }
      @interfaces.each { |i| OC.resource_bind_resource_interface res, i }
      # OC.resource_set_default_interface res, OC_IF_RW
      OC.resource_set_discoverable res, @properties.discoverable?
      OC.resource_set_periodic_observable res, @properties.periodic? && @properties.observable?
      @ptr = res
    end

    # =======================================================================================
    # Methods
    # =======================================================================================

    def add
      ret = OC.add_resource(@ptr)
      if ret.zero?
        raise "ERROR: Could not add resource #{@name} to IoTivity stack (code #{ret})"
      end
    end

  end

end
