
--  This is the FreeRTOS version of this package

--  This package contains all the GNULL primitives that interface directly with
--  the underlying OS.

with Interfaces.C;

with System.FreeRTOS;
with System.OS_Interface;
with System.Parameters;

package body System.Task_Primitives.Operations is

   use System.FreeRTOS;
   use System.OS_Interface;
   use System.OS_Locks;
   use System.Parameters;
   use System.Tasking;

   use type Interfaces.C.int;

   subtype int is Interfaces.C.int;

   ----------------
   -- Local Data --
   ----------------

   --  The followings are logically constants, but need to be initialized at
   --  run time.

   --  Environment_Task_Id : Task_Id with Unreferenced;
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

   ----------
   -- Self --
   ----------

   function Self return Task_Id renames Specific.Self;

   ---------------------
   -- Monotonic_Clock --
   ---------------------

   function Monotonic_Clock return Duration is
   begin
      raise Program_Error;
      return 0.0;
   end Monotonic_Clock;

   --------------------
   -- Initialize_TCB --
   --------------------

   procedure Initialize_TCB (Self_ID : Task_Id; Succeeded : out Boolean) is
   begin
      Self_ID.Common.LL.Thread := Null_Thread_Id;
      --  Self_ID.Common.LL.CV := semBCreate (SEM_Q_PRIORITY, SEM_EMPTY);

      --  if Self_ID.Common.LL.CV = 0 then
      --     Succeeded := False;
      --
      --  else
         Succeeded := True;
         Initialize_Lock (Self_ID.Common.LL.L'Access, ATCB_Level);
      --  end if;
   end Initialize_TCB;

   --------------------
   -- Check_No_Locks --
   --------------------

   function Check_No_Locks (Self_ID : ST.Task_Id) return Boolean is
      pragma Unreferenced (Self_ID);
   begin
      --  dummy version
      return True;
   end Check_No_Locks;

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
      --  Environment_Task_Id := Environment_Task;

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

   procedure Finalize_Lock (L : not null access RTS_Lock) is
   begin
      vSemaphoreDelete (L.Mutex);
   end Finalize_Lock;

   ----------------
   -- Write_Lock --
   ----------------

   procedure Write_Lock
     (L                 : not null access Lock;
      Ceiling_Violation : out Boolean)
   is
      Result : BaseType_t;

   begin
      if L.Protocol = Prio_Protect
        and then int (Self.Common.Current_Priority) > L.Prio_Ceiling
      then
         Ceiling_Violation := True;
         return;
      else
         Ceiling_Violation := False;
      end if;

      Result := xSemaphoreTake (L.Mutex, portMAX_DELAY);
      pragma Assert (Result = pdTRUE);
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

   ------------
   -- Unlock --
   ------------

   procedure Unlock (L : not null access Lock) is
      Result : BaseType_t;
   begin
      Result := xSemaphoreGive (L.Mutex);
      pragma Assert (Result = pdTRUE);
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
