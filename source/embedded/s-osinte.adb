--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

package body System.OS_Interface is
   use type Time;
   function C_Clock return Time
     with Import, Convention => C, External_Name => "esp_timer_get_time";
   function Clock return Time is (C_Clock);
   procedure Delay_Until (T : Time) is
      Now       : Time := Clock;
      Remaining : Time;
      Ticks     : Time;
      Max_Ticks : constant Time := Time (TickType_t'Last / 2);
      Rate      : constant Time := System.OS_Constants.configTICK_RATE_HZ;
   begin
      pragma Assert (Is_Task_Context);
      if Now >= T then
         --  A nonblocking delay is still a task dispatching point.
         vTaskDelay (0);
         return;
      end if;

      loop
         Remaining := T - Now;
         --  Split before multiplication to handle the full unsigned Time
         --  range without overflow. Round the interval up to kernel ticks.
         Ticks := (Remaining / Ticks_Per_Second) * Rate
           + ((Remaining rem Ticks_Per_Second) * Rate
              + Ticks_Per_Second - 1) / Ticks_Per_Second;
         vTaskDelay (TickType_t (Time'Min (Ticks, Max_Ticks)));
         --  N tick boundaries can be less than N complete tick intervals.
         --  Recheck the high-resolution clock before completing the delay.
         Now := Clock;
         exit when Now >= T;
      end loop;
   end Delay_Until;
   procedure Set_Priority (Priority : System.Any_Priority) is
   begin
      if not Is_Task_Context then
         return;
      end if;
      vTaskPrioritySet (Null_TaskHandle_t, To_Priority (Priority));
   end Set_Priority;

   ---------------------
   -- Is_Task_Context --
   ---------------------

   function Is_Task_Context return Boolean is (xPortInIsrContext = pdFALSE);

   -----------------
   -- To_Priority --
   -----------------

   function To_Priority (Priority : System.Any_Priority) return UBaseType_t is
   begin
      --  Ada task priorities map directly to kernel priorities, including
      --  zero. Higher Ada ceilings map to the highest kernel priority;
      --  protected interrupt ceilings mask IRQs.

      return
        UBaseType_t'Min
          (UBaseType_t (Priority),
           System.OS_Constants.configMAX_PRIORITIES - 1);
   end To_Priority;

end System.OS_Interface;
