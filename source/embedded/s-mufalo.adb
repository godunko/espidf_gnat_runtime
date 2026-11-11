--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

package body System.Multiprocessors.Fair_Locks is

   use type System.OS_Interface.BaseType_t;

   ----------------------------------
   -- Initialize_Interrupt_Context --
   ----------------------------------

   procedure Initialize_Interrupt_Context (Flock : in out Fair_Lock) is
   begin
      Flock.Interrupt_Lock := True;
      System.OS_Interface.portMUX_INITIALIZE (Flock.Mux);
   end Initialize_Interrupt_Context;

   -----------------------------
   -- Initialize_Task_Context --
   -----------------------------

   procedure Initialize_Task_Context (Flock : in out Fair_Lock) is
      use type System.OS_Interface.SemaphoreHandle_t;

   begin
      Flock.Interrupt_Lock := False;
      Flock.Semaphore_Handle :=
        System.OS_Interface.xSemaphoreCreateMutexStatic
          (Flock.Semaphore_Storage'Access);
      pragma
        Assert
          (Flock.Semaphore_Handle
           /= System.OS_Interface.Null_SemaphoreHandle_t);
   end Initialize_Task_Context;

   ----------
   -- Lock --
   ----------

   procedure Lock (Flock : in out Fair_Lock) is
      Result : System.OS_Interface.BaseType_t;

   begin
      if Flock.Interrupt_Lock then
         System.OS_Interface.portENTER_CRITICAL_SAFE (Flock.Mux);

         return;

      elsif System.OS_Interface.Is_Task_Context then
         Result :=
           System.OS_Interface.xSemaphoreTake
             (Flock.Semaphore_Handle, System.OS_Interface.portMAX_DELAY);
         pragma Assert (Result = System.OS_Interface.pdTRUE);

      else
         raise Program_Error;
      end if;
   end Lock;

   --------------
   -- Try_Lock --
   --------------

   procedure Try_Lock (Flock : in out Fair_Lock; Succeeded : out Boolean) is
   begin
      if Flock.Interrupt_Lock then
         Succeeded :=
           System.OS_Interface.Try_Critical (Flock.Mux)
           = System.OS_Interface.pdTRUE;

      elsif System.OS_Interface.Is_Task_Context then
         Succeeded :=
           System.OS_Interface.xSemaphoreTake (Flock.Semaphore_Handle, 0)
           = System.OS_Interface.pdTRUE;

      else
         raise Program_Error;
      end if;
   end Try_Lock;

   ------------
   -- Unlock --
   ------------

   procedure Unlock (Flock : in out Fair_Lock) is
      Result : System.OS_Interface.BaseType_t;

   begin
      if Flock.Interrupt_Lock then
         System.OS_Interface.portEXIT_CRITICAL_SAFE (Flock.Mux);

      else
         Result := System.OS_Interface.xSemaphoreGive (Flock.Semaphore_Handle);
         pragma Assert (Result = System.OS_Interface.pdTRUE);
      end if;
   end Unlock;

end System.Multiprocessors.Fair_Locks;
