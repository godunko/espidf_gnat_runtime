--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Ada.Unchecked_Conversion;
with System.Tasking.Debug;
with System.Storage_Elements;

package body System.Task_Primitives.Operations is
   use type OSI.TaskHandle_t;
   use type OSI.SemaphoreHandle_t;
   use type OSI.BaseType_t;
   use type ST.Task_Id;
   use type Multiprocessors.CPU_Range;

   Current_Task : aliased ST.Task_Id := null;
   pragma Thread_Local_Storage (Current_Task);

   RTS_Mutex_Storage : aliased OSI.StaticSemaphore_t;
   RTS_Mutex         : OSI.SemaphoreHandle_t :=
     OSI.SemaphoreHandle_t (Null_Address);

   function To_Address is new Ada.Unchecked_Conversion (ST.Task_Id, Address);
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
     (T.Common.LL.Current_Priority);
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
      OSI.Delay_Until (OSI.Time (Abs_Time));
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
      pragma Unreferenced (Reason, Result);
   begin
      pragma Assert (OSI.Is_Task_Context);
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

   begin
      T.Common.LL.Current_Priority := Priority;
      T.Common.LL.Thread :=
        OSI.Thread_Create
          (Code         => To_Task_Function (Wrapper),
           Arg          => To_Address (T),
           Task_Storage => T.Common.LL.TCB,
           Stack        => T.Common.Compiler_Data.Pri_Stack_Info.Start_Address,
           Stack_Size   => System.Storage_Elements.Storage_Offset (Stack_Size),
           Priority     => Priority,
           Base_CPU     => Base_CPU);
      Succeeded := T.Common.LL.Thread /= OSI.Null_TaskHandle_t;
   end Create_Task;

   ----------------
   -- Enter_Task --
   ----------------

   procedure Enter_Task (Self_ID : ST.Task_Id) is
   begin
      Current_Task := Self_ID;

      Sleep (Self_ID, ST.Activator_Sleep);
      --  Wait for creator publication, or consume the environment's token.
      --  An early signal is retained by the per-task wake event.

      Self_ID.Common.LL.Lwp := Address (Self_ID.Common.LL.Thread);
      RTS_Lock;
      System.Tasking.Debug.Add_Task_Id (Self_ID);
      RTS_Unlock;
      System.OS_Interface.Set_Priority (Self_ID.Common.Base_Priority);
   end Enter_Task;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Environment_Task : ST.Task_Id) is
   begin
      pragma Assert (Current_Task = ST.Null_Task);
      pragma
        Assert
          (OSI.Is_Task_Context
           and then RTS_Mutex = OSI.SemaphoreHandle_t (Null_Address));

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

   function Self return ST.Task_Id is (Current_Task);

end System.Task_Primitives.Operations;
