#pragma once

#ifndef CFG_TUSB_MCU
#define CFG_TUSB_MCU OPT_MCU_RP2040
#endif

// for malloc
#include <stdlib.h>

#include "pico/stdlib.h"

// For HID
#include "bsp/board.h"
#include "usb_descriptors.h"

// board_millis
#include "pico/time.h"
static inline uint32_t get_board_millis(void)
{
  return to_ms_since_boot(get_absolute_time());
}
