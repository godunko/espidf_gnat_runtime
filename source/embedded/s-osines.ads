--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

--  Interface for ESP-IDF

package System.OS_Interface.ESPIDF with Preelaborate is

   type esp_err_t is new int;

   ESP_OK : constant esp_err_t := 0;

   type intr_handle_data_t is limited private;

   type intr_handle_t is access all intr_handle_data_t
     with Convention => C, Storage_Size => 0;

   type intr_handler_t is access procedure (Arg : System.Address)
   with Convention => C;

   ESP_INTR_FLAG_LEVEL1 : constant int := 2#0000_0010#;
   ESP_INTR_FLAG_LEVEL2 : constant int := 2#0000_0100#;
   ESP_INTR_FLAG_LEVEL3 : constant int := 2#0000_1000#;
   ESP_INTR_FLAG_LEVEL4 : constant int := 2#0001_0000#;
   ESP_INTR_FLAG_LEVEL5 : constant int := 2#0010_0000#;
   ESP_INTR_FLAG_LEVEL6 : constant int := 2#0100_0000#;
   ESP_INTR_FLAG_NMI    : constant int := 2#1000_0000#;

   function esp_intr_alloc
     (Source  : int;
      Flags   : int;
      Handler : intr_handler_t;
      Arg     : System.Address;
      Handle  : out intr_handle_t) return esp_err_t
   with Import, Convention => C, External_Name => "esp_intr_alloc";

   function To_Flags (Priority : Interrupt_Priority) return int;
   --  Convert an interrupt priority into the corresponding ESP-IDF flag value

   function Clock_Usec return int64_t
   with Import, Convention => C, External_Name => "__gnat_calendar_clock_usec";

private

   type intr_handle_data_t is null record with Convention => C;

end System.OS_Interface.ESPIDF;