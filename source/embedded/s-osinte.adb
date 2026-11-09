--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

package body System.OS_Interface is
   use type Multiprocessors.CPU_Range;
   use type Storage_Elements.Storage_Offset;
   function C_Clock return Time
     with Import, Convention => C, External_Name => "esp_timer_get_time";
   procedure C_Init
     with Import, Convention => C, External_Name => "__gnat_embedded_init";
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
   procedure Set_Priority (Priority : System.Any_Priority) is
   begin
      pragma Assert (Is_Task_Context);
      vTaskPrioritySet (Null_TaskHandle_t, To_Priority (Priority));
   end Set_Priority;

   ---------------------
   -- Is_Task_Context --
   ---------------------

   function Is_Task_Context return Boolean is (xPortInIsrContext = pdFALSE);

   -------------------
   -- Thread_Create --
   -------------------

   function Thread_Create
     (Code         : not null TaskFunction_t;
      Arg          : System.Address;
      Task_Storage : out StaticTask_t;
      Stack        : System.Address;
      Stack_Size   : System.Storage_Elements.Storage_Offset;
      Priority     : System.Any_Priority;
      Base_CPU     : System.Multiprocessors.CPU_Range) return TaskHandle_t
   is
      C_Name : aliased constant Interfaces.C.char_array :=
        Interfaces.C.To_C ("Ada task");

   begin
      pragma Assert (Is_Task_Context);
      pragma Assert (Arg /= Null_Address);
      pragma Assert (Stack /= Null_Address);
      pragma Assert (Stack_Size > 0);

      return
        xTaskCreateStaticPinnedToCore
          (pxTaskCode     => Code,
           pcName         => C_Name (C_Name'First)'Access,
           ulStackDepth   => uint32_t (Stack_Size),
           pvParameters   => Arg,
           uxPriority     => To_Priority (Priority),
           puxStackBuffer => Stack,
           pxTaskBuffer   => Task_Storage,
           xCoreID        =>
             (if Base_CPU = 0
              then tskNO_AFFINITY
              else BaseType_t (Base_CPU - 1)));
   end Thread_Create;

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
