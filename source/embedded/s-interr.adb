--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Interfaces.C;
with System.Storage_Elements;
with System.Tasking.Restricted.Stages;

package body System.Interrupts is
   use type Interfaces.C.int;

   type C_Handler is access procedure (Arg : Address) with Convention => C;
   function Allocate
     (Source : Interfaces.C.int; Flags : Interfaces.C.int;
      Handler : C_Handler; Arg : Address; Handle : Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "esp_intr_alloc";

   type Handler_Entry is record
      Handler : Parameterless_Handler := null;
      Priority : Interrupt_Priority := Interrupt_Priority'First;
      Installed : Boolean := False;
   end record;
   User_Handlers : array (Interrupt_ID) of Handler_Entry;

   procedure Dispatch (Arg : Address) with Convention => C;
   procedure Dispatch (Arg : Address) is
      Id : constant Interrupt_ID :=
        Interrupt_ID (Storage_Elements.To_Integer (Arg));
   begin
      begin
         User_Handlers (Id).Handler.all;
      exception
         when others => null; --  ARM C.3: contain exceptions from handlers.
      end;
   end Dispatch;

   procedure Install (Id : Interrupt_ID);
   procedure Install (Id : Interrupt_ID) is
      Result : Interfaces.C.int;
      Level : constant Integer :=
        User_Handlers (Id).Priority - Interrupt_Priority'First + 1;
   begin
      if User_Handlers (Id).Installed then
         return;
      end if;
      --  System.Interrupt_Priority covers the C-callable levels 1..3.
      Result := Allocate
        (Interfaces.C.int (Id), Interfaces.C.int (2 ** Level),
         Dispatch'Access,
         Storage_Elements.To_Address (Storage_Elements.Integer_Address (Id)),
         Null_Address);
      if Result /= 0 then
         User_Handlers (Id).Handler := null;
         raise Program_Error with "ESP-IDF interrupt allocation failed";
      end if;
      User_Handlers (Id).Installed := True;
   end Install;

   procedure Install_Restricted_Handlers
     (Prio : Interrupt_Priority; Handlers : Handler_Array)
   is
      use System.Tasking.Restricted.Stages;
   begin
      for Item of Handlers loop
         if Item.Handler = null
           or else User_Handlers (Item.Interrupt).Handler /= null
         then
            raise Program_Error with "invalid or duplicate interrupt handler";
         end if;
         User_Handlers (Item.Interrupt) := (Item.Handler, Prio, False);
         if Partition_Elaboration_Policy /= 'S' then
            Install (Item.Interrupt);
         end if;
      end loop;
   end Install_Restricted_Handlers;

   procedure Install_Restricted_Handlers_Sequential is
   begin
      for Id in User_Handlers'Range loop
         if User_Handlers (Id).Handler /= null then
            Install (Id);
         end if;
      end loop;
   end Install_Restricted_Handlers_Sequential;
end System.Interrupts;
