--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

--  This is an ESP-IDF/FreeRTOS implementation of this function.

with System.OS_Interface.ESPIDF;

separate (Ada.Calendar)
function Clock return Time is

   use type System.OS_Interface.int64_t;

   US : constant System.OS_Interface.int64_t :=
     System.OS_Interface.ESPIDF.Clock_Usec;

begin
   return
     Radix_Time + Duration (US / 1_000_000)
     + Duration (US rem 1_000_000) / 1_000_000;
   --  Split before fixed-point conversion to preserve the Duration range.
end Clock;
