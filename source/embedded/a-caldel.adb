--  GNAT runtime for ESP-IDF. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with System.Relative_Delays;
with System.Task_Primitives.Operations;

package body Ada.Calendar.Delays is
   procedure Delay_For (D : Duration) is
   begin
      System.Relative_Delays.Delay_For (D);
   end Delay_For;

   procedure Delay_Until (T : Time) is
      Now : Time;
   begin
      if System.Task_Primitives.Operations.Self.Common.Protected_Action_Nesting
        > 0
      then
         raise Program_Error;
      end if;
      Now := Clock;
      if T <= Now then
         Delay_For (0.0);
      else
         loop
            --  Use 100 ms monotonic chunks to resample the adjustable clock.
            --  Tick rounding and scheduling can extend each chunk.
            Delay_For (Duration'Min (T - Now, 0.1));
            Now := Clock;
            exit when T <= Now;
         end loop;
      end if;
   end Delay_Until;

   function To_Duration (T : Time) return Duration is
   begin
      return T - Radix_Time;
   end To_Duration;
end Ada.Calendar.Delays;
