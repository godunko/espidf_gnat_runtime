--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Ada.Real_Time;

package body System.Relative_Delays is
   procedure Delay_For (D : Duration) is
      use Ada.Real_Time;
      Span : Time_Span := Time_Span_Zero;
   begin
      if D > 0.0 then
         Span := To_Time_Span (D);
         if To_Duration (Span) < D then
            Span := Span + Time_Span_Unit;
         end if;
      end if;
      delay until Clock + Span;
   end Delay_For;
end System.Relative_Delays;
