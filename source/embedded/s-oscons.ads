--
--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

package System.OS_Constants is

   pragma Pure;

   configMAX_PRIORITIES : constant := 25;
   configTICK_RATE_HZ   : constant := 100;

   --  Byte sizes and alignments for the tested ESP32-S3 / ESP-IDF 6.1
   --  configuration with Newlib. Keep the C assertions in ada-freertos.c
   --  in sync.
   portMUX_TYPE_Size           : constant := 8;
   portMUX_TYPE_Alignment      : constant := 4;
   StaticTask_t_Size           : constant := 348;
   StaticTask_t_Alignment      : constant := 4;
   StaticSemaphore_t_Size      : constant := 84;
   StaticSemaphore_t_Alignment : constant := 4;

   ATCB_Slot : constant := 1;
   --  Slot 0 is reserved by ESP-IDF for pthread TLS.

end System.OS_Constants;
