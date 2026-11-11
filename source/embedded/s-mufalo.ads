--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

--  This is ESP-IDF/FreeRTOS specific implementation of fair locks. Its API
--  doesn't provide `Locked` function to check the lock state. Two different
--  mechanisms are used depending on the context: critical sections for
--  interrupts and mutexes for tasks.

with System.OS_Interface;

package System.Multiprocessors.Fair_Locks
  with Preelaborate
is

   type Fair_Lock is limited private;

   procedure Initialize_Task_Context (Flock : in out Fair_Lock);
   --  Initialize the lock for use in task context

   procedure Initialize_Interrupt_Context (Flock : in out Fair_Lock);
   --  Initialize the lock for use in interrupt context

   procedure Lock (Flock : in out Fair_Lock);
   --  Loop until lock is acquired

   --  function Locked (Flock : Fair_Lock) return Boolean;
   --  Return the current state of the lock

   procedure Try_Lock (Flock : in out Fair_Lock; Succeeded : out Boolean);
   --  Return True if the lock has been acquired, otherwise don't wait for the
   --  lock and return False.

   procedure Unlock (Flock : in out Fair_Lock);
   --  Release the lock and wake up the next waiting CPU (if any)

private
   --  The upstream name is retained for the protected-object interface.
   --  Task ceilings use mutexes; interrupt ceilings use SDK critical sections.

   type Fair_Lock is limited record
      Interrupt_Lock    : Boolean;
      Mux               : System.OS_Interface.portMUX_TYPE;
      Semaphore_Storage : aliased System.OS_Interface.StaticSemaphore_t;
      Semaphore_Handle  : System.OS_Interface.SemaphoreHandle_t;
   end record;

end System.Multiprocessors.Fair_Locks;
