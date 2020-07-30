#include "oc_api.h"
#include <stddef.h>

/* ========================================================================= */
/* Global variables used for Crystal integration                             */
/* ========================================================================= */

/* ========================================================================= */
/* Functions used for Crystal integration                                    */
/* ========================================================================= */

const char* mmem_to_cstring(oc_string_t string) {
  return oc_string(string);
}
