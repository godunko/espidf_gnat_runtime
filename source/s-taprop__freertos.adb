
--  This is the FreeRTOS version of this package

--  This package contains all the GNULL primitives that interface directly with
--  the underlying OS.

with Ada.Unchecked_Conversion;
with Interfaces.C;

with System.FreeRTOS;
with System.OS_Interface;
with System.OS_Primitives;
with System.Soft_Links;

package body System.Task_Primitives.Operations is

   package SSL renames System.Soft_Links;

   use System.FreeRTOS;
   use System.OS_Interface;
   use System.OS_Locks;
   use System.OS_Primitives;
   use System.Parameters;
   use System.Tasking;

   use type Interfaces.C.int;

   subtype int is Interfaces.C.int;

   ----------------
   -- Local Data --
   ----------------

   --  The followings are logically constants, but need to be initialized at
   --  run time.

   Environment_Task_Id : Task_Id;
   --  A variable to hold Task_Id for the environment task

   Foreign_Task_Elaborated : aliased Boolean := True;
   --  Used to identified fake tasks (i.e., non-Ada Threads)

   Locking_Policy : constant Character;
   pragma Import (C, Locking_Policy, "__gl_locking_policy");

   Mutex_Protocol : Priority_Type;

   Single_RTS_Lock : aliased RTS_Lock;
   --  This is a lock to allow only one thread of control in the RTS at a
   --  time; it is used to execute in mutual exclusion from all other tasks.
   --  Used to protect All_Tasks_List

   --------------------
   -- Local Packages --
   --------------------

   package Specific is

      procedure Initialize (Environment_Task : Task_Id);
      pragma Inline (Initialize);
      --  Initialize task specific data

      function Is_Valid_Task return Boolean;
      pragma Inline (Is_Valid_Task);
      --  Does executing thread have a TCB?

      procedure Set (Self_Id : Task_Id);
      pragma Inline (Set);
      --  Set the self id for the current task, unless Self_Id is null, in
      --  which case the task specific data is deleted.

      function Self return Task_Id;
      pragma Inline (Self);
      --  Return a pointer to the Ada Task Control Block of the calling task

   end Specific;

   package body Specific is separate;
   --  The body of this package is target specific

   ----------------------------------
   -- ATCB allocation/deallocation --
   ----------------------------------

   package body ATCB_Allocation is separate;
   --  The body of this package is shared across several targets

   ---------------------------------
   -- Support for foreign threads --
   ---------------------------------

   function Register_Foreign_Thread
     (Thread         : Thread_Id;
      Sec_Stack_Size : Size_Type := Unspecified_Size) return Task_Id;
   --  Allocate and initialize a new ATCB for the current Thread. The size of
   --  the secondary stack can be optionally specified.

   function Register_Foreign_Thread
     (Thread         : Thread_Id;
      Sec_Stack_Size : Size_Type := Unspecified_Size)
     return Task_Id is separate;

   -----------------------
   -- Local Subprograms --
   -----------------------

   function Is_Task_Context return Boolean;
   --  This function returns True if the current execution is in the context of
   --  a task, and False if it is an interrupt context.

   procedure Semaphore_Take
     (xSemaphore      : SemaphoreHandle_t;
      In_Task_Context : Boolean);
   --  Calls `xSemaphoreTake` or `xSemaphoreTakeFromISR` depending on the
   --  context.

   procedure Semaphore_Give
     (xSemaphore      : SemaphoreHandle_t;
      In_Task_Context : Boolean);
   --  Calls `xSemaphoreGive` or `xSemaphoreGiveFromISR` depending on the
   --  context.

   function To_Address is
     new Ada.Unchecked_Conversion (Task_Id, System.Address);

   function To_TaskFunction_t is
     new Ada.Unchecked_Conversion (System.Address, TaskFunction_t);

   ----------
   -- Self --
   ----------

   function Self return Task_Id renames Specific.Self;

   -----------
   -- Sleep --
   -----------

   procedure Sleep (Self_ID : Task_Id; Reason : System.Tasking.Task_States) is
      pragma Unreferenced (Reason);

      Result : BaseType_t;

   begin
      pragma Assert (Self_ID = Self);

      --  Release the mutex before sleeping

      Result := xSemaphoreGive (Self_ID.Common.LL.L.Mutex);
      pragma Assert (Result = pdTRUE);

      --  Perform a blocking operation to take the CV semaphore.

      Result := xSemaphoreTake (Self_ID.Common.LL.CV, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);

      --  Take the mutex back

      Result := xSemaphoreTake (Self_ID.Common.LL.L.Mutex, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);
   end Sleep;

   -----------------
   -- Timed_Delay --
   -----------------

   --  This is for use in implementing delay statements, so we assume the
   --  caller is holding no locks.

   procedure Timed_Delay
     (Self_ID : Task_Id;
      Time    : Duration;
      Mode    : ST.Delay_Modes)
   is
      Orig     : constant Duration := Monotonic_Clock;
      Absolute : Duration;
      Ticks    : TickType_t;
      Timedout : Boolean;
      Aborted  : Boolean := False;

      Result   : BaseType_t;

   begin
      if Mode = Relative then
         Absolute := Orig + Time;
         Ticks    := To_Ticks (Time);

         if Ticks > 0 and then Ticks < portMAX_DELAY then

            --  First tick will delay anytime between 0 and tick period,
            --  so we need to add one to be on the safe side.

            Ticks := Ticks + 1;
         end if;

      else
         Absolute := Time;
         Ticks    := To_Ticks (Time - Orig);
      end if;

      if Ticks = System.FreeRTOS.portMAX_DELAY then
         --  portMAX_DELAY is used to indicate infinite delay, avoid its use.

         Ticks := @ - 1;
      end if;

      if Ticks > 0 then

         --  Modifying State, locking the TCB

         Result := xSemaphoreTake (Self_ID.Common.LL.L.Mutex, portMAX_DELAY);
         pragma Assert (Result = pdTRUE);

         Self_ID.Common.State := Delay_Sleep;
         Timedout := False;

         loop
            Aborted := Self_ID.Pending_ATC_Level < Self_ID.ATC_Nesting_Level;

            --  Release the TCB before sleeping

            Result := xSemaphoreGive (Self_ID.Common.LL.L.Mutex);
            pragma Assert (Result = pdTRUE);

            exit when Aborted;

            Result := xSemaphoreTake (Self_ID.Common.LL.CV, Ticks);

            if Result /= pdTRUE then

               --  If Ticks = portMAX_DELAY - 1, it was most probably
               --  truncated, so make another round after recomputing
               --  Ticks from absolute time.

               if Ticks /= System.FreeRTOS.portMAX_DELAY - 1 then
                  Timedout := True;

               else
                  declare
                     D : constant Duration := Absolute - Monotonic_Clock;

                  begin
                     if D < 0.0 and then To_Ticks (abs D) > 0 then
                        Timedout := True;

                     else
                        Ticks := To_Ticks (Absolute - Monotonic_Clock);

                        if Ticks < portMAX_DELAY - 1 then

                           --  First tick will delay anytime between 0 and
                           --  tick period, so we need to add one to be on the
                           --  safe side.

                           Ticks := @ + 1;

                        elsif Ticks = System.FreeRTOS.portMAX_DELAY then
                           --  portMAX_DELAY is used to indicate infinite
                           --  delay, avoid its use.

                           Ticks := @ - 1;
                        end if;
                     end if;
                  end;
               end if;
            end if;

            --  Take back the lock after having slept, to protect further
            --  access to Self_ID.

            Result :=
              xSemaphoreTake (Self_ID.Common.LL.L.Mutex, portMAX_DELAY);
            pragma Assert (Result = pdTRUE);

            exit when Timedout;
         end loop;

         Self_ID.Common.State := Runnable;

         Result := xSemaphoreGive (Self_ID.Common.LL.L.Mutex);
         pragma Assert (Result = pdTRUE);

      else
         vTaskDelay (0);
      end if;
   end Timed_Delay;

   ---------------------
   -- Monotonic_Clock --
   ---------------------

   function Monotonic_Clock return Duration is
   begin
      return To_Duration (xTaskGetTickCount);
   end Monotonic_Clock;

   --------------------
   -- Initialize_TCB --
   --------------------

   procedure Initialize_TCB (Self_ID : Task_Id; Succeeded : out Boolean) is
   begin
      Self_ID.Common.LL.Thread := Null_Thread_Id;
      Self_ID.Common.LL.CV := xSemaphoreCreateBinary;

      if Self_ID.Common.LL.CV = Null_SemaphoreHandle_t then
         Succeeded := False;

      else
         Succeeded := True;
         Initialize_Lock (Self_ID.Common.LL.L'Access, ATCB_Level);
      end if;
   end Initialize_TCB;

   -----------------
   -- Create_Task --
   -----------------

   procedure Create_Task
     (T          : Task_Id;
      Wrapper    : System.Address;
      Stack_Size : System.Parameters.Size_Type;
      Priority   : System.Any_Priority;
      Succeeded  : out Boolean)
   is
--      use type System.Multiprocessors.CPU_Range;

      Result : BaseType_t;

   begin
--      --  Check whether both Dispatching_Domain and CPU are specified for
--      --  the task, and the CPU value is not contained within the range of
--      --  processors for the domain.
--
--      if T.Common.Domain /= null
--        and then T.Common.Base_CPU /= System.Multiprocessors
--  .Not_A_Specific_CPU
--        and then
--          (T.Common.Base_CPU not in T.Common.Domain'Range
--            or else not T.Common.Domain (T.Common.Base_CPU))
--      then
--         Succeeded := False;
--         return;
--      end if;

      --  Since the initial signal mask of a thread is inherited from the
      --  creator, and the Environment task has all its signals masked, we do
      --  not need to manipulate caller's signal mask at this point. All tasks
      --  in RTS will have All_Tasks_Mask initially.

      --  We now compute the FreeRTOS task name, then spawn ...

      declare
         Name : aliased Interfaces.C.char_array
           (1 .. size_t (T.Common.Task_Image_Len + 1));
         --  Task name we are going to hand down to FreeRTOS

      begin
         for J in Name'Range loop
            Name (J) := char (T.Common.Task_Image (Integer (J)));
         end loop;

         Name (Name'Last) := Interfaces.C.nul;

         --  Now create the FreeRTOS task

         Result :=
           xTaskCreate
             (pvTaskCode    => To_TaskFunction_t (Wrapper),
              pcName        => Name (1)'Access,
              uxStackDepth  => configSTACK_DEPTH_TYPE (Stack_Size),
              pvParameters  => To_Address (T),
              uxPriority    => To_FreeRTOS_Priority (Priority),
              pxCreatedTask => T.Common.LL.Thread);
         --  Note, ESP-IDF's `xTaskCreate` expects stack size in bytes, not
         --  words as vanilla FreeRTOS.

         if Result = pdTRUE then
            Succeeded := True;
--            Task_Creation_Hook (T.Common.LL.Thread);

         else
            Succeeded := False;
         end if;
      end;

--      --  Set processor affinity
--
--      Set_Task_Affinity (T);
--
      --  Only case of failure is if taskSpawn returned 0 (aka Null_Thread_Id)
--
--      if T.Common.LL.Thread = Null_Thread_Id then
--         Succeeded := False;
--      else
--         Succeeded := True;
--         Task_Creation_Hook (T.Common.LL.Thread);
--      end if;
   end Create_Task;

   ----------------
   -- Abort_Task --
   ----------------

   procedure Abort_Task (T : Task_Id) is
   begin
      vTaskDelete (T.Common.LL.Thread);
   end Abort_Task;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (S : in out Suspension_Object) is
      Success : BaseType_t;

   begin
      --  Initialize internal state (always to False (RM D.10(6)))

      S.State := False;
      S.Waiting := False;

      --  Initialize internal mutex

      S.L := xSemaphoreCreateBinary;
      pragma Assert (S.L /= Null_SemaphoreHandle_t);

      Success := xSemaphoreGive (S.L);
      pragma Assert (Success = pdTRUE);
      --  Binary semaphore (opposite to mutex) is in "unavailable" state after
      --  creation and must be "given" first.

      --  Initialize internal condition variable

      S.CV := xSemaphoreCreateBinary;
      pragma Assert (S.CV /= Null_SemaphoreHandle_t);
   end Initialize;

   --------------
   -- Finalize --
   --------------

   procedure Finalize (S : in out Suspension_Object) is
      pragma Unmodified (S);
      --  S may be modified on other targets, but not on FreeRTOS

   begin
      --  Destroy internal mutex

      vSemaphoreDelete (S.L);

      --  Destroy internal condition variable

      vSemaphoreDelete (S.CV);
   end Finalize;

   -------------------
   -- Current_State --
   -------------------

   function Current_State (S : Suspension_Object) return Boolean is
   begin
      --  We do not want to use lock on this read operation. State is marked
      --  as Atomic so that we ensure that the value retrieved is correct.

      return S.State;
   end Current_State;

   ---------------
   -- Set_False --
   ---------------

   procedure Set_False (S : in out Suspension_Object) is
      In_Task_Context : constant Boolean := Operations.Is_Task_Context;

   begin
      SSL.Abort_Defer.all;

      Semaphore_Take (S.L, In_Task_Context);

      S.State := False;

      Semaphore_Give (S.L, In_Task_Context);

      SSL.Abort_Undefer.all;
   end Set_False;

   --------------
   -- Set_True --
   --------------

   procedure Set_True (S : in out Suspension_Object) is
      In_Task_Context : constant Boolean := Operations.Is_Task_Context;

   begin
      --  Set_True can be called from an interrupt context, in which case
      --  Abort_Defer is undefined.

      if In_Task_Context then
         SSL.Abort_Defer.all;
      end if;

      Semaphore_Take (S.L, In_Task_Context);

      --  If there is already a task waiting on this suspension object then we
      --  resume it, leaving the state of the suspension object to False, as it
      --  is specified in (RM D.10 (9)). Otherwise, it just leaves the state to
      --  True.

      if S.Waiting then
         S.Waiting := False;
         S.State := False;

         Semaphore_Give (S.CV, In_Task_Context);
      else
         S.State := True;
      end if;

      Semaphore_Give (S.L, In_Task_Context);

      --  Set_True can be called from an interrupt context, in which case
      --  Abort_Undefer is undefined.

      if In_Task_Context then
         SSL.Abort_Undefer.all;
      end if;
   end Set_True;

   ------------------------
   -- Suspend_Until_True --
   ------------------------

   procedure Suspend_Until_True (S : in out Suspension_Object) is
      Result : BaseType_t;

   begin
      SSL.Abort_Defer.all;

      Result := xSemaphoreTake (S.L, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);

      if S.Waiting then

         --  Program_Error must be raised upon calling Suspend_Until_True
         --  if another task is already waiting on that suspension object
         --  (RM D.10(10)).

         Result := xSemaphoreGive (S.L);
         pragma Assert (Result = pdTRUE);

         SSL.Abort_Undefer.all;

         raise Program_Error;

      else
         --  Suspend the task if the state is False. Otherwise, the task
         --  continues its execution, and the state of the suspension object
         --  is set to False (RM D.10 (9)).

         if S.State then
            S.State := False;

            Result := xSemaphoreGive (S.L);
            pragma Assert (Result = pdTRUE);

            SSL.Abort_Undefer.all;

         else
            S.Waiting := True;

            --  Release the mutex before sleeping

            Result := xSemaphoreGive (S.L);
            pragma Assert (Result = pdTRUE);

            SSL.Abort_Undefer.all;

            Result := xSemaphoreTake (S.CV, portMAX_DELAY);
            pragma Assert (Result = pdTRUE);
         end if;
      end if;
   end Suspend_Until_True;

   --------------------
   -- Check_No_Locks --
   --------------------

   function Check_No_Locks (Self_ID : ST.Task_Id) return Boolean is
      pragma Unreferenced (Self_ID);
   begin
      --  dummy version
      return True;
   end Check_No_Locks;

   ----------------------
   -- Environment_Task --
   ----------------------

   function Environment_Task return Task_Id is
   begin
      return Environment_Task_Id;
   end Environment_Task;

   --------------
   -- Lock_RTS --
   --------------

   procedure Lock_RTS is
   begin
      Write_Lock (Single_RTS_Lock'Access);
   end Lock_RTS;

   ----------------
   -- Unlock_RTS --
   ----------------

   procedure Unlock_RTS is
   begin
      Unlock (Single_RTS_Lock'Access);
   end Unlock_RTS;

   ---------------------
   -- Is_Task_Context --
   ---------------------

   function Is_Task_Context return Boolean is
   begin
      return System.FreeRTOS.xPortInIsrContext = System.FreeRTOS.pdFALSE;
   end Is_Task_Context;

   --------------------
   -- Semaphore_Give --
   --------------------

   procedure Semaphore_Give
     (xSemaphore      : SemaphoreHandle_t;
      In_Task_Context : Boolean)
   is
      Result                     : BaseType_t;
      Higher_Priority_Task_Woken : BaseType_t := pdFALSE;

   begin
      if In_Task_Context then
         Result := xSemaphoreGive (xSemaphore);
         pragma Assert (Result = pdTRUE);

      else
         Result :=
           xSemaphoreGiveFromISR (xSemaphore, Higher_Priority_Task_Woken);
         pragma Assert (Result = pdTRUE);

         portYIELD_FROM_ISR (Higher_Priority_Task_Woken);
         --  Yield to the higher priority task that was woken up by this give
         --  operation.
      end if;
   end Semaphore_Give;

   --------------------
   -- Semaphore_Take --
   --------------------

   procedure Semaphore_Take
     (xSemaphore      : SemaphoreHandle_t;
      In_Task_Context : Boolean)
   is
      Result                     : BaseType_t;
      Higher_Priority_Task_Woken : BaseType_t := pdFALSE;

   begin
      if In_Task_Context then
         Result := xSemaphoreTake (xSemaphore, portMAX_DELAY);
         pragma Assert (Result = pdTRUE);

      else
         Result :=
           xSemaphoreTakeFromISR (xSemaphore, Higher_Priority_Task_Woken);
         pragma Assert (Result = pdTRUE);

         portYIELD_FROM_ISR (Higher_Priority_Task_Woken);
         --  Yield to the higher priority task that was woken up by this take
         --  operation.
      end if;
   end Semaphore_Take;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Environment_Task : Task_Id) is
      --  act     : aliased struct_sigaction;
      --  old_act : aliased struct_sigaction;
      --  Tmp_Set : aliased sigset_t;
      --  Result  : Interfaces.C.int;
      --
      --  function State
      --    (Int : System.Interrupt_Management.Interrupt_ID) return Character;
      --  pragma Import (C, State, "__gnat_get_interrupt_state");
      --  --  Get interrupt state.  Defined in a-init.c
      --  --  The input argument is the interrupt number,
      --  --  and the result is one of the following:
      --
      --  Default : constant Character := 's';
      --  --    'n'   this interrupt not set by any Interrupt_State pragma
      --  --    'u'   Interrupt_State pragma set state to User
      --  --    'r'   Interrupt_State pragma set state to Runtime
      --  --    's'   Interrupt_State pragma set state to System (use "default"
      --  --           system handler)

   begin
      Environment_Task_Id := Environment_Task;

      Specific.Initialize (Environment_Task);

      Environment_Task.Common.LL.Thread := xTaskGetCurrentTaskHandle;

      --  Interrupt_Management.Initialize;
      --
      --  --  Prepare the set of signals that should unblocked in all tasks
      --
      --  Result := sigemptyset (Unblocked_Signal_Mask'Access);
      --  pragma Assert (Result = 0);
      --
      --  for J in Interrupt_Management.Interrupt_ID loop
      --     if System.Interrupt_Management.Keep_Unmasked (J) then
      --        Result := sigaddset (Unblocked_Signal_Mask'Access, Signal (J));
      --        pragma Assert (Result = 0);
      --     end if;
      --  end loop;

      if Locking_Policy = 'C' then
         Mutex_Protocol := Prio_Protect;
      elsif Locking_Policy = 'I' then
         Mutex_Protocol := Prio_Inherit;
      else
         Mutex_Protocol := Prio_None;
      end if;

      --  Initialize the lock used to synchronize chain of all ATCBs

      Initialize_Lock (Single_RTS_Lock'Access, RTS_Lock_Level);

      --  if Use_Alternate_Stack then
      --     Environment_Task.Common.Task_Alternate_Stack :=
      --       Alternate_Stack'Address;
      --  end if;
      --
      --  --  Make environment task known here because it doesn't go through
      --  --  Activate_Tasks, which does it for all other tasks.
      --
      --  Known_Tasks (Known_Tasks'First) := Environment_Task;
      --  Environment_Task.Known_Tasks_Index := Known_Tasks'First;

      Enter_Task (Environment_Task);

      --  if State
      --      (System.Interrupt_Management.Abort_Task_Interrupt) /= Default
      --  then
      --     act.sa_flags := 0;
      --     act.sa_handler := Abort_Handler'Address;
      --
      --     Result := sigemptyset (Tmp_Set'Access);
      --     pragma Assert (Result = 0);
      --     act.sa_mask := Tmp_Set;
      --
      --     Result :=
      --       sigaction
      --         (Signal (System.Interrupt_Management.Abort_Task_Interrupt),
      --          act'Unchecked_Access,
      --          old_act'Unchecked_Access);
      --     pragma Assert (Result = 0);
      --     Abort_Handler_Installed := True;
      --  end if;
   end Initialize;

   ---------------------
   -- Initialize_Lock --
   ---------------------

   procedure Initialize_Lock
     (Prio : System.Any_Priority;
      L    : not null access Lock)
   is
      Success : BaseType_t;

   begin
      L.Mutex := xSemaphoreCreateBinary;
      pragma Assert (L.Mutex /= Null_SemaphoreHandle_t);
      L.Prio_Ceiling := int (Prio);
      L.Protocol := Mutex_Protocol;

      Success := xSemaphoreGive (L.Mutex);
      pragma Assert (Success = pdTRUE);
      --  Binary semaphore (opposite to mutex) is in "unavailable" state after
      --  creation and must be "given" first.
   end Initialize_Lock;

   procedure Initialize_Lock
     (L     : not null access RTS_Lock;
      Level : Lock_Level with Unreferenced)
   is
      Success : BaseType_t;

   begin
      L.Mutex := xSemaphoreCreateBinary;
      pragma Assert (L.Mutex /= Null_SemaphoreHandle_t);
      L.Prio_Ceiling := int (System.Any_Priority'Last);
      L.Protocol := Mutex_Protocol;

      Success := xSemaphoreGive (L.Mutex);
      pragma Assert (Success = pdTRUE);
      --  Binary semaphore (opposite to mutex) is in "unavailable" state after
      --  creation and must be "given" first.
   end Initialize_Lock;

   -------------------
   -- Finalize_Lock --
   -------------------

   procedure Finalize_Lock (L : not null access Lock) is
   begin
      vSemaphoreDelete (L.Mutex);
   end Finalize_Lock;

   procedure Finalize_Lock (L : not null access RTS_Lock) is
   begin
      vSemaphoreDelete (L.Mutex);
   end Finalize_Lock;

   ----------------
   -- Write_Lock --
   ----------------

   procedure Write_Lock
     (L                 : not null access Lock;
      Ceiling_Violation : out Boolean) is
   begin
      if L.Protocol = Prio_Protect
        and then int (Self.Common.Current_Priority) > L.Prio_Ceiling
      then
         Ceiling_Violation := True;
         return;
      else
         Ceiling_Violation := False;
      end if;

      Semaphore_Take (L.Mutex, Is_Task_Context);
   end Write_Lock;

   procedure Write_Lock (L : not null access RTS_Lock) is
      Result : BaseType_t;
   begin
      Result := xSemaphoreTake (L.Mutex, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);
   end Write_Lock;

   procedure Write_Lock (T : Task_Id) is
      Result : BaseType_t;
   begin
      Result := xSemaphoreTake (T.Common.LL.L.Mutex, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);
   end Write_Lock;

   ---------------
   -- Read_Lock --
   ---------------

   procedure Read_Lock
     (L                 : not null access Lock;
      Ceiling_Violation : out Boolean) is
   begin
      Write_Lock (L, Ceiling_Violation);
   end Read_Lock;

   ------------
   -- Unlock --
   ------------

   procedure Unlock (L : not null access Lock) is
   begin
      Semaphore_Give (L.Mutex, Is_Task_Context);
   end Unlock;

   procedure Unlock (L : not null access RTS_Lock) is
      Result : BaseType_t;
   begin
      Result := xSemaphoreGive (L.Mutex);
      pragma Assert (Result = pdTRUE);
   end Unlock;

   procedure Unlock (T : Task_Id) is
      Result : BaseType_t;
   begin
      Result := xSemaphoreGive (T.Common.LL.L.Mutex);
      pragma Assert (Result = pdTRUE);
   end Unlock;

   -----------------
   -- Set_Ceiling --
   -----------------

   --  XXX Dynamic priority ceilings are not supported by the underlying system

   procedure Set_Ceiling
     (L    : not null access Lock;
      Prio : System.Any_Priority)
   is
      pragma Unreferenced (L, Prio);
   begin
      null;
   end Set_Ceiling;

   ------------
   -- Wakeup --
   ------------

   procedure Wakeup (T : Task_Id; Reason : System.Tasking.Task_States) is
      pragma Unreferenced (Reason);
      Result : BaseType_t;
   begin
      Result := xSemaphoreGive (T.Common.LL.CV);
      pragma Assert (Result = pdTRUE);
   end Wakeup;

   -----------
   -- Yield --
   -----------

   procedure Yield (Do_Yield : Boolean := True) is
      pragma Unreferenced (Do_Yield);
   begin
      vTaskDelay (0);
   end Yield;

   ------------------
   -- Set_Priority --
   ------------------

   procedure Set_Priority
     (T                   : Task_Id;
      Prio                : System.Any_Priority;
      Loss_Of_Inheritance : Boolean := False with Unreferenced)
   is
   begin
      vTaskPrioritySet (T.Common.LL.Thread, To_FreeRTOS_Priority (Prio));

      T.Common.Current_Priority := Prio;
   end Set_Priority;

   ------------------
   -- Get_Priority --
   ------------------

   function Get_Priority (T : Task_Id) return System.Any_Priority is
   begin
      return T.Common.Current_Priority;
   end Get_Priority;

   ----------------
   -- Enter_Task --
   ----------------

   procedure Enter_Task (Self_ID : Task_Id) is
   begin
      --  Store the user-level task id in the Thread field (to be used
      --  internally by the run-time system) and the kernel-level task id in
      --  the LWP field (to be used by the debugger).

      Self_ID.Common.LL.Thread := xTaskGetCurrentTaskHandle;
--      Self_ID.Common.LL.LWP := getpid;

      Specific.Set (Self_ID);

--      --  Properly initializes the FPU for PPC/MIPS systems
--
--      System.Float_Control.Reset;
--
--      --  Install the signal handlers
--
--      --  This is called for each task since there is no signal inheritance
--      --  between VxWorks tasks.
--
--      Install_Signal_Handlers;
--
--      --  If stack checking is enabled, set the stack limit for this task
--
--      if Set_Stack_Limit_Hook /= null then
--         Set_Stack_Limit_Hook.all;
--      end if;
   end Enter_Task;

   -------------------
   -- Is_Valid_Task --
   -------------------

   function Is_Valid_Task return Boolean renames Specific.Is_Valid_Task;

   -----------------------------
   -- Register_Foreign_Thread --
   -----------------------------

   function Register_Foreign_Thread return Task_Id is
   begin
      if Is_Valid_Task then
         return Self;
      else
         return Register_Foreign_Thread (xTaskGetCurrentTaskHandle);
      end if;
   end Register_Foreign_Thread;

end System.Task_Primitives.Operations;
