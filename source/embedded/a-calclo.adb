--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Interfaces;

separate (Ada.Calendar)
function Clock return Time is
   use type Interfaces.Integer_64;
   function Clock_Usec return Interfaces.Integer_64
     with Import, Convention => C,
          External_Name => "__gnat_calendar_clock_usec";
   US : constant Interfaces.Integer_64 := Clock_Usec;
begin
   --  Split before fixed-point conversion to preserve the Duration range.
   return Radix_Time + Duration (US / 1_000_000)
     + Duration (US rem 1_000_000) / 1_000_000;
end Clock;
