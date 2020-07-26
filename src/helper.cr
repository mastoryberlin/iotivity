require "./bindings"

# =============================================================================
# Helper C bindings for OCF/IoTivity
# =============================================================================

@[Link(ldflags: "-DOC_CLIENT -DOC_SECURITY -I/home/pi/iot-lite/iotivity-lite -I/home/pi/iot-lite/iotivity-lite/include -I/home/pi/iot-lite/iotivity-lite/port/linux /home/pi/iot-dashboard/src/helper.c /home/pi/iot-lite/iotivity-lite/port/linux/libiotivity-lite-client.a")]
lib LibIoTivity
  $pDevice : Void*
  $on_discovery     : OC::DiscoveryHandler
  $on_discovery_all : OC::DiscoveryAllHandler
  fun issue_requests() : Void
  fun mmem_to_cstring(string : OC::String) : LibC::Char*
end
