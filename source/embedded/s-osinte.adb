--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

with System.OS_Interface.ESPIDF;

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

   type Handler_Entry is record
      Handler : Interrupt_Handler;
      --  The protected subprogram

      Handle  : System.OS_Interface.ESPIDF.intr_handle_t;
      --  ESP-IDF handle for the interrupt
   end record with Suppress_Initialization;

   type Handles_Table is array (Interrupt_ID) of Handler_Entry
   with Suppress_Initialization;
   --  Type used to represent the ESP-IDF handles used for interrupt management

   Interrupt_Handlers_Table : Handles_Table := (others => (null, null));
   --  Table containing handles attached to the different external interrupts

   procedure Dispatch_Interrupt (Arg : Address) with Convention => C;
   --  Dispatch an interrupt to the appropriate handler.

   --------------------
   -- Attach_Handler --
   --------------------

   procedure Attach_Handler
     (Handler : not null Interrupt_Handler;
      Id      : Interrupt_ID;
      Prio    : Interrupt_Priority)
   is
      use type System.OS_Interface.ESPIDF.esp_err_t;
      use type System.OS_Interface.ESPIDF.intr_handle_t;

      Result : System.OS_Interface.ESPIDF.esp_err_t;

   begin
      --  Check that we are attaching to a real interrupt

      pragma Assert (Id /= No_Interrupt);

      --  Check that no previous interrupt handler has been registered

      if Interrupt_Handlers_Table (Id).Handle /= null then
         raise Program_Error;
      end if;

      --  Copy the user's handler to the appropriate place within the table,
      --  and allocate the interrupt with the ESP-IDF.

      Interrupt_Handlers_Table (Id).Handler := Handler;
      Result :=
        System.OS_Interface.ESPIDF.esp_intr_alloc
          (Interfaces.C.int (Id),
           System.OS_Interface.ESPIDF.To_Flags (Prio),
           Dispatch_Interrupt'Access,
           Storage_Elements.To_Address (Storage_Elements.Integer_Address (Id)),
           Interrupt_Handlers_Table (Id).Handle);

      if Result /= System.OS_Interface.ESPIDF.ESP_OK then
         Interrupt_Handlers_Table (Id) := (null, null);

         raise Program_Error with "ESP-IDF interrupt allocation failed";
      end if;
   end Attach_Handler;

   ------------------------
   -- Dispatch_Interrupt --
   ------------------------

   procedure Dispatch_Interrupt (Arg : Address) is
      Id : constant Interrupt_ID :=
        Interrupt_ID (Storage_Elements.To_Integer (Arg));

   begin
      Interrupt_Handlers_Table (Id).Handler.all (Id);
   end Dispatch_Interrupt;

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
