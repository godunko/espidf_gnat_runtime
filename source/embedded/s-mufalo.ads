--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with System.OS_Interface;

package System.Multiprocessors.Fair_Locks is
   pragma Preelaborate;

   --  The upstream name is retained for the protected-object interface.
   --  This backend uses task mutexes, not per-CPU spinning or FIFO handoff.
   --  Task context only; interrupt access is implemented in a later stage.
   type Fair_Lock is limited private;
   procedure Initialize (Flock : in out Fair_Lock);
   procedure Lock (Flock : in out Fair_Lock);
   function Locked (Flock : Fair_Lock) return Boolean;
   procedure Try_Lock (Flock : in out Fair_Lock; Succeeded : out Boolean);
   procedure Unlock (Flock : in out Fair_Lock);
private
   type Fair_Lock is limited record
      Storage : aliased OS_Interface.StaticSemaphore_t;
      Handle  : OS_Interface.SemaphoreHandle_t;
   end record;
end System.Multiprocessors.Fair_Locks;
