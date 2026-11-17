--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

--  Interface for FreeRTOS

package System.OS_Interface.FreeRTOS
  with Preelaborate
is

   procedure vTaskDelay (xTicksToDelay : TickType_t)
   with Import, Convention => C, External_Name => "vTaskDelay";

end System.OS_Interface.FreeRTOS;