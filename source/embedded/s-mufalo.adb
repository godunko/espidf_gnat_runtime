--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

package body System.Multiprocessors.Fair_Locks is
   package OSI renames System.OS_Interface;
   use type OSI.SemaphoreHandle_t;
   use type OSI.BaseType_t;
   use type OSI.UBaseType_t;

   procedure Initialize (Flock : in out Fair_Lock) is
   begin
      Flock.Handle := OSI.xSemaphoreCreateMutexStatic (Flock.Storage'Access);
      pragma Assert (Flock.Handle /= OSI.SemaphoreHandle_t (Null_Address));
   end Initialize;

   procedure Lock (Flock : in out Fair_Lock) is
      Result : OSI.BaseType_t;
   begin
      pragma Assert (OSI.Is_Task_Context);
      Result := OSI.xSemaphoreTake (Flock.Handle, OSI.portMAX_DELAY);
      pragma Assert (Result = OSI.pdTRUE);
   end Lock;

   function Locked (Flock : Fair_Lock) return Boolean is
     (OSI.uxSemaphoreGetCount (Flock.Handle) = 0);

   procedure Try_Lock (Flock : in out Fair_Lock; Succeeded : out Boolean) is
   begin
      pragma Assert (OSI.Is_Task_Context);
      Succeeded := OSI.xSemaphoreTake (Flock.Handle, 0) = OSI.pdTRUE;
   end Try_Lock;

   procedure Unlock (Flock : in out Fair_Lock) is
      Result : OSI.BaseType_t;
   begin
      Result := OSI.xSemaphoreGive (Flock.Handle);
      pragma Assert (Result = OSI.pdTRUE);
   end Unlock;
end System.Multiprocessors.Fair_Locks;
