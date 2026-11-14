--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Interfaces;
with Interfaces.C;
with System.OS_Constants;
with System.Storage_Elements;

package System.OS_Interface is

   pragma Preelaborate;

   subtype uint32_t is Interfaces.Unsigned_32;

   type BaseType_t is new Interfaces.C.int;
   pdFALSE : constant BaseType_t := 0;
   pdTRUE  : constant BaseType_t := 1;

   tskNO_AFFINITY : constant BaseType_t := 16#7FFF_FFFF#;

   type UBaseType_t is new Interfaces.C.unsigned;

   type TickType_t is new uint32_t;
   portMAX_DELAY : constant TickType_t := TickType_t'Last;

   type portMUX_TYPE is private;

   type StaticTask_t is private;
   type TaskHandle_t is new System.Address;
   Null_TaskHandle_t : constant TaskHandle_t := TaskHandle_t (Null_Address);

   type StaticSemaphore_t is private;
   type SemaphoreHandle_t is new System.Address;
   Null_SemaphoreHandle_t : constant SemaphoreHandle_t :=
     SemaphoreHandle_t (Null_Address);

   type TaskFunction_t is access procedure (Arg : System.Address)
   with Convention => C;

   subtype Thread_Id is TaskHandle_t;
   --  Compatibility name used by the upstream task-primitives specification.

   Null_Thread_Id : constant Thread_Id := TaskHandle_t (Null_Address);

   subtype Interrupt_Range is Integer range 0 .. 98;
   function Try_Critical (Mux : in out portMUX_TYPE) return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_mux_try";
   function Core_ID return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_core_id";
   function Interrupt_Nesting return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_interrupt_nesting";
   function Interrupt_Level return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_interrupt_level";

   subtype Time is Interfaces.Unsigned_64;
   subtype Time_Span is Interfaces.Integer_64;
   Ticks_Per_Second : constant := 1_000_000;
   function Clock return Time;
   procedure Delay_Until (T : Time);
   procedure Set_Priority (Priority : System.Any_Priority);
   function Is_Task_Context return Boolean;

   function To_Priority (Priority : System.Any_Priority) return UBaseType_t;
   --  Convert an Ada priority to the corresponding FreeRTOS priority. Value
   --  is saturated to the valid FreeRTOS priority range.

   procedure portENTER_CRITICAL_SAFE (Mux : in out portMUX_TYPE)
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_portENTER_CRITICAL_SAFE";

   procedure portEXIT_CRITICAL_SAFE (Mux : in out portMUX_TYPE)
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_portEXIT_CRITICAL_SAFE";

   procedure portMUX_INITIALIZE (Mux : out portMUX_TYPE)
   with Import, Convention => C, External_Name => "__gnat_portMUX_INITIALIZE";

   procedure portYIELD_FROM_ISR (xHigherPriorityTaskWoken : BaseType_t)
   with Import, Convention => C,
        External_Name => "__gnat_portYIELD_FROM_ISR";

   function xPortInIsrContext return BaseType_t
   with Import, Convention => C, External_Name => "xPortInIsrContext";

   function xSemaphoreCreateBinaryStatic
     (pxSemaphoreBuffer : access StaticSemaphore_t) return SemaphoreHandle_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreCreateBinaryStatic";

   function xSemaphoreCreateMutexStatic
     (pxMutexBuffer : access StaticSemaphore_t) return SemaphoreHandle_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreCreateMutexStatic";

   function xSemaphoreCreateRecursiveMutexStatic
     (pxMutexBuffer : access StaticSemaphore_t) return SemaphoreHandle_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreCreateRecursiveMutexStatic";

   function uxSemaphoreGetCount
     (xSemaphore : SemaphoreHandle_t) return UBaseType_t
   with Import, Convention => C, External_Name => "__gnat_uxSemaphoreGetCount";

   function xSemaphoreGive (xSemaphore : SemaphoreHandle_t) return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_xSemaphoreGive";

   function xSemaphoreGiveFromISR
     (xSemaphore                : SemaphoreHandle_t;
      pxHigherPriorityTaskWoken : out BaseType_t) return BaseType_t
   with Import, Convention => C,
        External_Name => "__gnat_xSemaphoreGiveFromISR";

   function xSemaphoreGiveRecursive
     (xMutex : SemaphoreHandle_t) return BaseType_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreGiveRecursive";

   function xSemaphoreTake
     (xSemaphore : SemaphoreHandle_t; xTicksToWait : TickType_t)
      return BaseType_t
   with Import, Convention => C, External_Name => "__gnat_xSemaphoreTake";

   function xSemaphoreTakeRecursive
     (xMutex : SemaphoreHandle_t; xTicksToWait : TickType_t) return BaseType_t
   with
     Import,
     Convention    => C,
     External_Name => "__gnat_xSemaphoreTakeRecursive";

   function xTaskCreateStaticPinnedToCore
     (pxTaskCode     : not null TaskFunction_t;
      pcName         : access constant Interfaces.C.char;
      ulStackDepth   : uint32_t;
      pvParameters   : System.Address;
      uxPriority     : UBaseType_t;
      puxStackBuffer : System.Address;
      pxTaskBuffer   : out StaticTask_t;
      xCoreID        : BaseType_t) return TaskHandle_t
   with
     Import,
     Convention    => C,
     External_Name => "xTaskCreateStaticPinnedToCore";

   function xTaskGetCurrentTaskHandle return TaskHandle_t
   with Import, Convention => C, External_Name => "xTaskGetCurrentTaskHandle";

   procedure vTaskDelay (xTicksToDelay : TickType_t)
   with Import, Convention => C, External_Name => "vTaskDelay";

   procedure vTaskPrioritySet
     (xTask : TaskHandle_t; uxNewPriority : UBaseType_t)
   with Import, Convention => C, External_Name => "vTaskPrioritySet";

private

   type portMUX_TYPE is array
     (1 .. System.OS_Constants.portMUX_TYPE_Size) of Interfaces.Unsigned_8
     with Convention => C,
          Alignment => System.OS_Constants.portMUX_TYPE_Alignment;

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
