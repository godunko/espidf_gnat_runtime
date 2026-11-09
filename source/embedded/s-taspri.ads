--
--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

with System.OS_Interface;

package System.Task_Primitives is

   pragma Preelaborate;

   type Task_Body_Access is access procedure;
   --  Pointer to the task body's entry point (or possibly a wrapper
   --  declared local to the GNARL).

   type Private_Data;
   --  Any information that the GNULLI needs maintained on a per-task
   --  basis.  A component of this type is guaranteed to be included
   --  in the Ada_Task_Control_Block.

   subtype Task_Address is System.Address;
   Task_Address_Size : constant := Standard'Address_Size;
   --  Type used for task addresses and its size

   Alternate_Stack_Size : constant := 0;
   --  No alternate signal stack is used on this platform

   type Private_Data is limited record
      TCB        : aliased System.OS_Interface.StaticTask_t;
      CV         : System.OS_Interface.SemaphoreHandle_t;
      --  Binary event for startup and subsequent Sleep/Wakeup.
      CV_Storage : aliased System.OS_Interface.StaticSemaphore_t;
      Thread     : aliased System.OS_Interface.Thread_Id :=
        System.OS_Interface.Null_Thread_Id;
      Lwp        : aliased System.Address := System.Null_Address;
   end record;

end System.Task_Primitives;
