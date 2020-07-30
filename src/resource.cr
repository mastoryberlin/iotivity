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
  record Resource,
    uri : String,
    types : Array(String),
    interfaces : Interface,
    properties : ResourceProperties

end
