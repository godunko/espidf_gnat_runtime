--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Ada.Exceptions;
with Ada.Unchecked_Conversion;
with Interfaces.C;
with System.OS_Constants;
with System.Secondary_Stack;
with System.Tasking.Debug;

package body System.Task_Primitives.Operations is
   use type OSI.TaskHandle_t;
   use type OSI.SemaphoreHandle_t;
   use type OSI.BaseType_t;
   use type ST.Task_Id;
   use type Multiprocessors.CPU_Range;
   use type System.Parameters.Size_Type;

   function To_Address is new Ada.Unchecked_Conversion (ST.Task_Id, Address);
   function To_Task_Id is new Ada.Unchecked_Conversion (Address, ST.Task_Id);

   function Get_Current_Task return ST.Task_Id
     with Pre => System.OS_Interface.Is_Task_Context;

   procedure Set_Current_Task (T : ST.Task_Id)
     with Pre => System.OS_Interface.Is_Task_Context;

   subtype ESPIDF_Interrupt_Nesting_Level is Positive range
     1 .. System.Interrupt_Priority'Last - System.Interrupt_Priority'First + 1;
   --  Maximum nesting depth of ISRs in ESP-IDF. By convention, higher
   --  priorities, which can't use FreeRTOS API, and doesn't mapped to Ada.

   ISR_Pseudo_Tasks :
     array (System.Multiprocessors.CPU, ESPIDF_Interrupt_Nesting_Level)
     of aliased ST.Ada_Task_Control_Block (0);

   ISR_Secondary_Stacks :
     array (System.Multiprocessors.CPU) of System.Secondary_Stack.SS_Stack_Ptr
   with Suppress_Initialization;
   --  Allocated from the binder pool during initialization, one per CPU.
   --  All nested handlers on that CPU share this stack in LIFO order.

   RTS_Mutex_Storage : aliased OSI.StaticSemaphore_t;
   RTS_Mutex         : OSI.SemaphoreHandle_t :=
     OSI.SemaphoreHandle_t (Null_Address);

   --  Keep the soft-links entry points while owning the lock in Ada.
   procedure RTS_Lock
     with Export, Convention => C, External_Name => "__gnat_embedded_rts_lock";
   procedure RTS_Unlock
     with Export, Convention => C,
          External_Name => "__gnat_embedded_rts_unlock";

   procedure RTS_Lock is
      Result : OSI.BaseType_t;
   begin
      pragma Assert (OSI.Is_Task_Context);
      Result := OSI.xSemaphoreTakeRecursive (RTS_Mutex, OSI.portMAX_DELAY);
      pragma Assert (Result = OSI.pdTRUE);
   end RTS_Lock;

   procedure RTS_Unlock is
      Result : OSI.BaseType_t;
   begin
      pragma Assert (OSI.Is_Task_Context);
      Result := OSI.xSemaphoreGiveRecursive (RTS_Mutex);
      pragma Assert (Result = OSI.pdTRUE);
   end RTS_Unlock;

   procedure Set_Priority (T : ST.Task_Id; Prio : ST.Extended_Priority) is
   begin
      pragma Assert (T = Self);
      T.Common.LL.Current_Priority := Prio;
      OSI.Set_Priority (Prio);
   end Set_Priority;
   function Get_Priority (T : ST.Task_Id) return ST.Extended_Priority is
   begin
      if not OSI.Is_Task_Context
        and then T = Self
        and then T.Common.Protected_Action_Nesting = 1
      then
         --  Outside an Ada protected action, include masking done by SDK C
         --  code. Inside one, retain the exact software ceiling priority.
         return System.Interrupt_Priority'First
           + Integer (OSI.Interrupt_Level) - 1;
      end if;
      return T.Common.LL.Current_Priority;
   end Get_Priority;
   function Get_Affinity (T : ST.Task_Id) return Multiprocessors.CPU_Range is
     (T.Common.Base_CPU);
   function Get_CPU (T : ST.Task_Id) return Multiprocessors.CPU is
     (if Get_Affinity (T) = 0 then Multiprocessors.CPU'First
      else Multiprocessors.CPU (Get_Affinity (T)));
   function Get_Thread_Id (T : ST.Task_Id) return OSI.Thread_Id is
     (T.Common.LL.Thread);
   function Monotonic_Clock return Time is (Time (OSI.Clock));
   procedure Delay_Until (Abs_Time : Time) is
   begin
      Self.Common.State := ST.Delay_Sleep;
      OSI.Delay_Until (OSI.Time (Abs_Time));
      Self.Common.State := ST.Runnable;
   end Delay_Until;
   procedure Sleep (Self_ID : ST.Task_Id; Reason : ST.Task_States) is
      pragma Unreferenced (Reason);
      Result : OSI.BaseType_t;
   begin
      pragma Assert (Self_ID = Self and then OSI.Is_Task_Context);
      Result := OSI.xSemaphoreTake
        (Self_ID.Common.LL.CV, OSI.portMAX_DELAY);
      pragma Assert (Result = OSI.pdTRUE);
   end Sleep;
   procedure Wakeup (T : ST.Task_Id; Reason : ST.Task_States) is
      Result : OSI.BaseType_t;
      Higher_Priority_Task_Woken : OSI.BaseType_t := OSI.pdFALSE;
      pragma Unreferenced (Reason, Result);
   begin
      if not OSI.Is_Task_Context then
         Result := OSI.xSemaphoreGiveFromISR
           (T.Common.LL.CV, Higher_Priority_Task_Woken);
         OSI.portYIELD_FROM_ISR (Higher_Priority_Task_Woken);
         return;
      end if;
      --  Repeated wakeups coalesce when the binary event is already signaled.
      Result := OSI.xSemaphoreGive (T.Common.LL.CV);
   end Wakeup;

   -----------------
   -- Create_Task --
   -----------------

   procedure Create_Task
     (T          : ST.Task_Id;
      Wrapper    : System.Address;
      Stack_Size : System.Parameters.Size_Type;
      Priority   : ST.Extended_Priority;
      Base_CPU   : System.Multiprocessors.CPU_Range;
      Succeeded  : out Boolean)
   is
      function To_Task_Function is new
        Ada.Unchecked_Conversion (Address, OSI.TaskFunction_t);

      C_Name : aliased constant Interfaces.C.char_array :=
        Interfaces.C.To_C ("Ada task");
      Stack : constant Address :=
        T.Common.Compiler_Data.Pri_Stack_Info.Start_Address;

   begin
      pragma Assert (OSI.Is_Task_Context);
      pragma Assert (T /= ST.Null_Task);
      pragma Assert (Stack /= Null_Address);
      pragma Assert (Stack_Size > 0);

      T.Common.LL.Current_Priority := Priority;
      T.Common.LL.Thread :=
        OSI.xTaskCreateStaticPinnedToCore
          (pxTaskCode     => To_Task_Function (Wrapper),
           pcName         => C_Name (C_Name'First)'Access,
           ulStackDepth   => OSI.uint32_t (Stack_Size),
           pvParameters   => To_Address (T),
           uxPriority     => OSI.To_Priority (Priority),
           puxStackBuffer => Stack,
           pxTaskBuffer   => T.Common.LL.TCB,
           xCoreID        =>
             (if Base_CPU = 0
              then OSI.tskNO_AFFINITY
              else OSI.BaseType_t (Base_CPU - 1)));
      Succeeded := T.Common.LL.Thread /= OSI.Null_TaskHandle_t;
   end Create_Task;

   ----------------
   -- Enter_Task --
   ----------------

   procedure Enter_Task (Self_ID : ST.Task_Id) is
   begin
      Set_Current_Task (Self_ID);

      Sleep (Self_ID, ST.Activator_Sleep);
      --  Wait for creator publication, or consume the environment's token.
      --  An early signal is retained by the per-task wake event.

      Self_ID.Common.LL.Lwp := Address (Self_ID.Common.LL.Thread);
      RTS_Lock;
      System.Tasking.Debug.Add_Task_Id (Self_ID);
      RTS_Unlock;
      System.OS_Interface.Set_Priority (Self_ID.Common.Base_Priority);
   end Enter_Task;

   ----------------------
   -- Get_Current_Task --
   ----------------------

   function Get_Current_Task return ST.Task_Id
   is (To_Task_Id
         (System.OS_Interface.pvTaskGetThreadLocalStoragePointer
            (System.OS_Interface.Null_TaskHandle_t,
             System.OS_Constants.ATCB_Slot)));

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Environment_Task : ST.Task_Id) is
   begin
      pragma Assert (Get_Current_Task = ST.Null_Task);
      pragma
        Assert
          (OSI.Is_Task_Context
           and then RTS_Mutex = OSI.SemaphoreHandle_t (Null_Address));

      --  For each CPU, initialize the secondary stack and ATCS for
      --  pseudo-tasks per each interrupt priority.

      for CPU in System.Multiprocessors.CPU loop
         ISR_Secondary_Stacks (CPU) := null;
         System.Secondary_Stack.SS_Init (ISR_Secondary_Stacks (CPU));

         for P in ESPIDF_Interrupt_Nesting_Level loop
            ISR_Pseudo_Tasks (CPU, P).Common.State := ST.Runnable;
            ISR_Pseudo_Tasks (CPU, P).Common.Base_CPU := CPU;
            ISR_Pseudo_Tasks (CPU, P).Common.Base_Priority :=
              System.Interrupt_Priority'First;
            ISR_Pseudo_Tasks (CPU, P).Common.LL.Current_Priority :=
              System.Interrupt_Priority'First;
            ISR_Pseudo_Tasks (CPU, P).Common.Protected_Action_Nesting := 1;
            ISR_Pseudo_Tasks (CPU, P).Common.Compiler_Data.Sec_Stack_Ptr :=
              ISR_Secondary_Stacks (CPU);

            Ada.Exceptions.Save_Occurrence
              (ISR_Pseudo_Tasks (CPU, P).Common.Compiler_Data.Current_Excep,
               Ada.Exceptions.Null_Occurrence);
         end loop;
      end loop;

      --  Create the recursive mutex for task activate/sleep/wakeup operations.
      --  The environment has no activator; provide its startup token here.

      RTS_Mutex :=
        OSI.xSemaphoreCreateRecursiveMutexStatic (RTS_Mutex_Storage'Access);
      pragma Assert (RTS_Mutex /= OSI.SemaphoreHandle_t (Null_Address));
      Wakeup (Environment_Task, ST.Activator_Sleep);

      --  Set the thread

      Environment_Task.Common.LL.Thread := OSI.xTaskGetCurrentTaskHandle;

      --  Clear Activation_Link, as required by Add_Task_Id

      Environment_Task.Common.Activation_Link := null;

      --  Set the current priority to the base priority of the environment
      --  task.

      Environment_Task.Common.LL.Current_Priority :=
        Environment_Task.Common.Base_Priority;

      Enter_Task (Environment_Task);

      --  Store the identifier for the environment task

      Operations.Environment_Task := Environment_Task;
   end Initialize;

   --------------------
   -- Initialize_TCB --
   --------------------

   procedure Initialize_TCB (Self_ID : ST.Task_Id; Succeeded : out Boolean) is
   begin
      Self_ID.Common.LL.CV :=
        OSI.xSemaphoreCreateBinaryStatic (Self_ID.Common.LL.CV_Storage'Access);

      Succeeded :=
        Self_ID.Common.LL.CV /= OSI.SemaphoreHandle_t (Null_Address);
   end Initialize_TCB;

   ---------------------
   -- Is_Task_Context --
   ---------------------

   function Is_Task_Context return Boolean renames OSI.Is_Task_Context;

   ----------
   -- Self --
   ----------

   function Self return ST.Task_Id is
   begin
      if OSI.Is_Task_Context then
         return Get_Current_Task;

      else
         declare
            CPU : constant System.Multiprocessors.CPU :=
              System.Multiprocessors.CPU (OSI.Core_ID + 1);

         begin
            --  Select the ISR pseudo-task for this CPU and nesting depth.
            --  All ISR pseudo-tasks on this CPU share one secondary stack.

            return
              ISR_Pseudo_Tasks
                (CPU,
                 ESPIDF_Interrupt_Nesting_Level
                   (OSI.Interrupt_Nesting))'Access;
         end;
      end if;
   end Self;

   ----------------------
   -- Set_Current_Task --
   ----------------------

   procedure Set_Current_Task (T : ST.Task_Id) is
   begin
      System.OS_Interface.vTaskSetThreadLocalStoragePointer
        (System.OS_Interface.Null_TaskHandle_t,
         System.OS_Constants.ATCB_Slot,
         To_Address (T));
   end Set_Current_Task;

end System.Task_Primitives.Operations;
