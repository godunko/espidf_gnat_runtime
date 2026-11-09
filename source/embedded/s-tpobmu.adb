--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with System.Task_Primitives.Operations;

package body System.Tasking.Protected_Objects.Multiprocessors is
   procedure Served (Entry_Call : Entry_Call_Link) is
   begin
      --  FreeRTOS handles remote-core rescheduling. The binary CV retains
      --  this signal even if the caller has not entered Sleep yet.
      System.Task_Primitives.Operations.Wakeup
        (Entry_Call.Self, Entry_Caller_Sleep);
   end Served;

   procedure Wakeup_Served_Entry is
   begin
      --  No bare-board per-CPU served list or poke callback is installed.
      null;
   end Wakeup_Served_Entry;
end System.Tasking.Protected_Objects.Multiprocessors;
