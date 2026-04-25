
pragma Restrictions (No_Elaboration_Code);

package System.IniFin is
   pragma Preelaborate;

   procedure Runtime_Initialize (Install_Handler : Integer);
   pragma Export (C, Runtime_Initialize, "__gnat_runtime_initialize");
   --  This procedure is called by adainit before the elaboration of other
   --  units. It usually installs handler for the synchronous signals. The C
   --  profile here is what is expected by the binder-generated main.

   procedure Runtime_Finalize;
   pragma Export (C, Runtime_Finalize, "__gnat_runtime_finalize");
   --  This procedure is called by adafinal.

   procedure Initialize;
   pragma Export (C, Initialize, "__gnat_initialize");

   procedure Finalize;
   pragma Export (C, Finalize, "__gnat_finalize");

private

   Gl_Main_Priority : Integer := -1;
   pragma Export (C, Gl_Main_Priority, "__gl_main_priority");

   Gl_Main_CPU : Integer := -1;
   pragma Export (C, Gl_Main_CPU, "__gl_main_cpu");

   Gl_Time_Slice_Val : Integer := -1;
   pragma Export (C, Gl_Time_Slice_Val, "__gl_time_slice_val");

   Gl_Wc_Encoding : Character := 'n';
   pragma Export (C, Gl_Wc_Encoding, "__gl_wc_encoding");

   Gl_Locking_Policy : Character := ' ';
   pragma Export (C, Gl_Locking_Policy, "__gl_locking_policy");

   Gl_Queuing_Policy : Character := ' ';
   pragma Export (C, Gl_Queuing_Policy, "__gl_queuing_policy");

   Gl_Task_Dispatching_Policy : Character := ' ';
   pragma Export (C, Gl_Task_Dispatching_Policy,
                     "__gl_task_dispatching_policy");

   Gl_Priority_Specific_Dispatching : Address := Null_Address;
   pragma Export (C, Gl_Priority_Specific_Dispatching,
                     "__gl_priority_specific_dispatching");

   Gl_Num_Specific_Dispatching : Integer := 0;
   pragma Export (C, Gl_Num_Specific_Dispatching,
                  "__gl_num_specific_dispatching");

   Gl_Interrupt_States : Address := Null_Address;
   pragma Export (C, Gl_Interrupt_States, "__gl_interrupt_states");

   Gl_Num_Interrupt_States : Integer := 0;
   pragma Export (C, Gl_Num_Interrupt_States, "__gl_num_interrupt_states");

   Gl_Unreserve_All_Interrupts : Integer := 0;
   pragma Export (C, Gl_Unreserve_All_Interrupts,
                  "__gl_unreserve_all_interrupts");

   Gl_Exception_Tracebacks : Integer := 0;
   pragma Export (C, Gl_Exception_Tracebacks, "__gl_exception_tracebacks");

--   Gl_Exception_Tracebacks_Symbolic : Integer := 0;
--   pragma Export (C, Gl_Exception_Tracebacks_Symbolic,
--                  "__gl_exception_tracebacks_symbolic");

   Gl_Detect_Blocking : Integer := 0;
   pragma Export (C, Gl_Detect_Blocking, "__gl_detect_blocking");

   Gl_Default_Stack_Size : Integer := -1;
   pragma Export (C, Gl_Default_Stack_Size, "__gl_default_stack_size");

   Gl_Leap_Seconds_Support : Integer := 0;
   pragma Export (C, Gl_Leap_Seconds_Support, "__gl_leap_seconds_support");

--   Gl_Canonical_Streams : Integer := 0;
--   pragma Export (C, Gl_Canonical_Streams, "__gl_canonical_streams");

--   Gl_Bind_Env_Addr : Address := Null_Address;
--   pragma Export (C, Gl_Bind_Env_Addr, "__gl_bind_env_addr");

   Gl_XDR_Stream : Integer := 0;
   pragma Export (C, Gl_XDR_Stream, "__gl_xdr_stream");

--   Gl_Interrupts_Default_To_System : Integer := 0;
--   pragma Export (C, Gl_Interrupts_Default_To_System,
--                     "__gl_interrupts_default_to_system");

end System.IniFin;
