require "log"

require "./bindings"
require "./device"
require "./client"
require "./server"

# Base namespace containing all IoTivity-related classes.
module IoTivity
  extend self

  # =======================================================================================
  # Constants
  # =======================================================================================

  Log = ::Log.for(self)

  # =======================================================================================
  # Class methods
  # =======================================================================================

  def oc_string(mmem : OC::Mmem)
    content = oc_mmem_ptr mmem
    if content
      String.new content.as(LibC::Char*)
    else
      "NOTHING"
    end
  end

  # ---------------------------------------------------------------------------------------

  def oc_mmem_ptr(mmem : OC::Mmem) : OC::Mmem*
    mmem.ptr.as(OC::Mmem*)
  end

end
