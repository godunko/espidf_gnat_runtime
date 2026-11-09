--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

package body System.OS_Interface is
   use Interfaces.C;
   function C_Clock return Time
     with Import, Convention => C, External_Name => "esp_timer_get_time";
   procedure C_Init
     with Import, Convention => C, External_Name => "__gnat_embedded_init";
   function C_Create
     (Code, Arg, Stack, Task_Buffer : Address;
      Size : size_t; Prio : UBaseType_t; CPU : int)
      return TaskHandle_t
     with Import, Convention => C, External_Name => "__gnat_embedded_create";
   function Clock return Time is (C_Clock);
   procedure Delay_Until (T : Time) is
      pragma Unreferenced (T);
   begin
      raise Program_Error with "delays are not implemented in stage 1";
   end Delay_Until;
   procedure Initialize is
   begin
      C_Init;
   end Initialize;
   function Thread_Self return TaskHandle_t is
     (xTaskGetCurrentTaskHandle);
   function Thread_Create
     (Code, Arg, Stack, Task_Buffer : Address;
      Stack_Size : Storage_Elements.Storage_Offset;
      Priority : System.Any_Priority;
      Base_CPU : Multiprocessors.CPU_Range) return TaskHandle_t is
     (C_Create (Code, Arg, Stack, Task_Buffer, size_t (Stack_Size),
                To_Priority (Priority), int (Base_CPU)));
   procedure Set_Priority (Priority : System.Any_Priority) is
   begin
      pragma Assert (Is_Task_Context);
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
      --  Reserve priority zero for idle tasks. Higher Ada ceilings map to
      --  the highest kernel priority; ISR masking is a later stage.

      return
        (if Priority < System.OS_Constants.configMAX_PRIORITIES - 1
         then UBaseType_t (Priority + 1)
         else UBaseType_t (System.OS_Constants.configMAX_PRIORITIES - 1));
   end To_Priority;

end System.OS_Interface;
