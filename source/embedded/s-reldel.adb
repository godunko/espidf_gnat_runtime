--
--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

with Ada.Real_Time;
with Ada.Unchecked_Conversion;
with Interfaces;
with System.OS_Interface;

package body System.Relative_Delays is

   use type Interfaces.Integer_64;

   function To_Duration_Units is new
     Ada.Unchecked_Conversion (Duration, Interfaces.Integer_64);
   --  Same signed integer representation used by Ada.Real_Time conversions.

   function To_Time_Span is new
     Ada.Unchecked_Conversion
       (System.OS_Interface.Time_Span,
        Ada.Real_Time.Time_Span);
   --  Ada.Real_Time.Time_Span is derived from OS_Interface.Time_Span.

   Units_Per_Tick : constant :=
     Interfaces.Integer_64 (Ada.Real_Time.Time_Unit / Duration'Small);

   pragma
     Compile_Time_Error
       (Duration'Size /= Interfaces.Integer_64'Size
        or else Units_Per_Tick < 1
        or else Duration'Small * Units_Per_Tick /= Ada.Real_Time.Time_Unit,
        "unsupported Duration/time unit representation");

   ---------------
   -- Delay_For --
   ---------------

   procedure Delay_For (D : Duration) is
      use type Ada.Real_Time.Time_Span;

      Span : Ada.Real_Time.Time_Span := Ada.Real_Time.Time_Span_Zero;

   begin
      if D > 0.0 then
         --  Round positive Duration units upward to clock units. Subtract
         --  before dividing to avoid overflow even for Duration'Last.

         Span :=
           To_Time_Span ((To_Duration_Units (D) - 1) / Units_Per_Tick + 1);
      end if;

      delay until Ada.Real_Time.Clock + Span;
   end Delay_For;

end System.Relative_Delays;
