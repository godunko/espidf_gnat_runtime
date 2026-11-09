--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Interfaces;
with Interfaces.C;
with System.Multiprocessors;
with System.OS_Constants;
with System.Storage_Elements;

package System.OS_Interface is

   pragma Preelaborate;

   subtype uint32_t is Interfaces.Unsigned_32;

   type BaseType_t is new Interfaces.C.int;
   pdFALSE : constant BaseType_t := 0;
   pdTRUE  : constant BaseType_t := 1;

   type TickType_t is new uint32_t;
   portMAX_DELAY : constant TickType_t := TickType_t'Last;

   type StaticTask_t is private;
   type TaskHandle_t is new System.Address;
   Null_TaskHandle_t : constant TaskHandle_t := TaskHandle_t (Null_Address);
   type StaticSemaphore_t is private;
   type SemaphoreHandle_t is new System.Address;

   subtype Thread_Id is TaskHandle_t;
   --  Compatibility name used by the upstream task-primitives specification.

   Null_Thread_Id : constant Thread_Id := TaskHandle_t (Null_Address);

   subtype Time is Interfaces.Unsigned_64;
   subtype Time_Span is Interfaces.Integer_64;
   Ticks_Per_Second : constant := 1_000_000;
   function Clock return Time;
   procedure Delay_Until (T : Time);
   procedure Initialize;
   function Thread_Self return TaskHandle_t;
   function Thread_Create
     (Code, Arg, Stack, Task_Buffer : Address;
      Stack_Size                    : Storage_Elements.Storage_Offset;
      Priority                      : Integer;
      Base_CPU                      : Multiprocessors.CPU_Range)
      return TaskHandle_t;
   procedure Set_Priority (Priority : Integer);
   function Is_Task_Context return Boolean;

   function xSemaphoreCreateBinaryStatic
     (pxSemaphoreBuffer : access StaticSemaphore_t) return SemaphoreHandle_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreCreateBinaryStatic";

   function xSemaphoreGive (xSemaphore : SemaphoreHandle_t) return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_xSemaphoreGive";

   function xSemaphoreTake
     (xSemaphore : SemaphoreHandle_t; xTicksToWait : TickType_t)
      return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_xSemaphoreTake";

   function xTaskGetCurrentTaskHandle return TaskHandle_t
   with Import, Convention => C, External_Name => "xTaskGetCurrentTaskHandle";

private

   type StaticTask_t is
     new System.Storage_Elements.Storage_Array
          (1 .. System.OS_Constants.StaticTask_t_Size)
   with Alignment => System.OS_Constants.StaticTask_t_Alignment;

   pragma Compile_Time_Error
     (StaticTask_t'Size /=
        System.OS_Constants.StaticTask_t_Size * System.Storage_Unit,
      "StaticTask_t storage size mismatch");

   type StaticSemaphore_t is
     new System.Storage_Elements.Storage_Array
          (1 .. System.OS_Constants.StaticSemaphore_t_Size)
   with Alignment => System.OS_Constants.StaticSemaphore_t_Alignment;

   pragma Compile_Time_Error
     (StaticSemaphore_t'Size /=
        System.OS_Constants.StaticSemaphore_t_Size * System.Storage_Unit,
      "StaticSemaphore_t storage size mismatch");

end System.OS_Interface;
