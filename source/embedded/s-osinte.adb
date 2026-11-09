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
      Size : size_t; Prio, CPU : int)
      return TaskHandle_t
     with Import, Convention => C, External_Name => "__gnat_embedded_create";
   procedure C_Set_Priority (Prio : int)
     with Import, Convention => C,
          External_Name => "__gnat_embedded_set_priority";
   function C_ISR return int
     with Import, Convention => C, External_Name => "xPortInIsrContext";
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
      Priority : Integer;
      Base_CPU : Multiprocessors.CPU_Range) return TaskHandle_t is
     (C_Create (Code, Arg, Stack, Task_Buffer, size_t (Stack_Size),
                int (Priority), int (Base_CPU)));
   procedure Set_Priority (Priority : Integer) is
   begin
      C_Set_Priority (int (Priority));
   end Set_Priority;
   function Is_Task_Context return Boolean is (C_ISR = 0);
end System.OS_Interface;
