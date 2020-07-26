#include "oc_api.h"
#include <stddef.h>

/* ========================================================================= */
/* Global variables used for Crystal integration                             */
/* ========================================================================= */

void* pDevice;
oc_discovery_handler_t     on_discovery;
oc_discovery_all_handler_t on_discovery_all;

/* ========================================================================= */
/* Functions used for Crystal integration                                    */
/* ========================================================================= */

void issue_requests(void) {
  oc_do_ip_discovery_all( on_discovery_all, pDevice );
}

/* ------------------------------------------------------------------------- */

const char* mmem_to_cstring(oc_string_t string) {
  return oc_string(string);
}
