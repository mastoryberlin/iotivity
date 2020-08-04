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
  struct Resource

    # =======================================================================================
    # Properties
    # =======================================================================================

    # The URI used to locate this resource.
    getter uri : String

    # ---------------------------------------------------------------------------------------

    # A list of all resource types of this resource.
    getter types : Array(String)

    # ---------------------------------------------------------------------------------------

    # The interfaces supported by this resource
    getter interfaces : Interface

    # ---------------------------------------------------------------------------------------

    getter default_interface : Interface

    # ---------------------------------------------------------------------------------------

    getter properties : ResourceProperties

    # ---------------------------------------------------------------------------------------

    forward_missing_to @properties

    # =======================================================================================
    # Constructor
    # =======================================================================================

    def initialize(@uri, @types,
                   interfaces : Interface | Array(String),
                   default_interface : Interface | String = "",
                   @properties = ResourceProperties::Discoverable)

      if interfaces.is_a? Interface
        @interfaces = interfaces
      else # Array(String)
        @interfaces = Interface::None
        interfaces.each do |i|
          case i.lchop("oic.if.")
          when "baseline" then @interfaces |= Interface::Baseline
          when "ll"       then @interfaces |= Interface::LL
          when "b"        then @interfaces |= Interface::B
          when "r"        then @interfaces |= Interface::R
          when "rw"       then @interfaces |= Interface::RW
          when "a"        then @interfaces |= Interface::A
          when "s"        then @interfaces |= Interface::S
          when "create"   then @interfaces |= Interface::Create
          end
        end
      end

      if default_interface.is_a? Interface
        @default_interface = default_interface
      else # String
        if default_interface.empty?
          if interfaces.is_a?(Array) && !interfaces.empty?
            default_interface = interfaces.first
          end
        end

        @default_interface = \
          case default_interface.lchop("oic.if.")
          when "baseline" then Interface::Baseline
          when "ll"       then Interface::LL
          when "b"        then Interface::B
          when "r"        then Interface::R
          when "rw"       then Interface::RW
          when "a"        then Interface::A
          when "s"        then Interface::S
          when "create"   then Interface::Create
          else                 Interface::None
          end
      end

    end

  end

end
