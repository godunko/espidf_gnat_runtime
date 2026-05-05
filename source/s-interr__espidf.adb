
--  This is the ESP-IDF version of this package

pragma Restrictions (No_Elaboration_Code);

with System.ESPIDF;
with System.Storage_Elements;
with System.Tasking.Restricted.Stages;

package body System.Interrupts is

   ----------------
   -- Local Data --
   ----------------

   type Handler_Entry is record
      Handler : Parameterless_Handler;
      --  The protected subprogram

      PO_Priority : Interrupt_Priority;
      --  The priority of the protected object in which the handler is declared
   end record;
   pragma Suppress_Initialization (Handler_Entry);

   type Handlers_Table is array (Interrupt_ID) of Handler_Entry;
   pragma Suppress_Initialization (Handlers_Table);
   --  Type used to represent the procedures used as interrupt handlers. No
   --  need to create an initializer, as the only object declared with this
   --  type is just below and has an expression to initialize it.

   User_Handlers : Handlers_Table :=
                     (others => (null, Interrupt_Priority'First));
   --  Table containing user handlers. Must be explicitly initialized to detect
   --  interrupts without attached handlers.

   -----------------------
   -- Local Subprograms --
   -----------------------

   procedure Install_Handler (Interrupt : Interrupt_ID);
   --  Install the runtime umbrella handler for a hardware interrupt

   procedure Default_Handler (arg : System.Address)
     with Convention => C;
   --  Default interrupt handler

   ---------------------
   -- Default_Handler --
   ---------------------

   procedure Default_Handler (arg : System.Address) is
      Interrupt : constant Interrupt_ID :=
        Interrupt_ID (System.Storage_Elements.To_Integer (arg));
      Handler   : constant Parameterless_Handler :=
        User_Handlers (Interrupt).Handler;

   begin
      if Handler = null then

         --  Be sure to properly report spurious interrupts even if the run
         --  time is compiled with checks suppressed.

         --  The ravenscar-sfp profile has a No_Exception_Propagation
         --  restriction. Discard compiler warning on the raise statement.

         pragma Warnings (Off);
         raise Program_Error;
         pragma Warnings (On);
      end if;

      --  As exception propagated from a handler that is invoked by an
      --  interrupt must have no effect (ARM C.3 par. 7), interrupt handlers
      --  are wrapped by a null exception handler to avoid exceptions to be
      --  propagated further.

      --  The ravenscar-sfp profile has a No_Exception_Propagation
      --  restriction. Discard compiler warning on the handler.

      pragma Warnings (Off);

      begin
         Handler.all;

      exception

         --  Avoid any further exception propagation

         when others =>
            null;
      end;

      pragma Warnings (On);
   end Default_Handler;

   --  Depending on whether exception propagation is supported or not, the
   --  implementation will differ; exceptions can never be propagated through
   --  this procedure (see ARM C.3 par. 7).

   ---------------------
   -- Install_Handler --
   ---------------------

   procedure Install_Handler (Interrupt : Interrupt_ID) is
      use type System.ESPIDF.esp_err_t;

      Error : System.ESPIDF.esp_err_t;

   begin
      --  Attach the default handler to the specified interrupt. This handler
      --  will in turn call the user handler.

      Error :=
        System.ESPIDF.esp_intr_alloc
          (source     => System.ESPIDF.int (Interrupt),
           flags      =>
             System.ESPIDF.To_Flags (User_Handlers (Interrupt).PO_Priority),
           handler    => Default_Handler'Access,
           arg        =>
             System.Storage_Elements.To_Address
               (System.Storage_Elements.Integer_Address (Interrupt)),
           ret_handle => null);
      pragma Assert (Error = System.ESPIDF.ESP_OK);
   end Install_Handler;

   ---------------------------------
   -- Install_Restricted_Handlers --
   ---------------------------------

   procedure Install_Restricted_Handlers
     (Prio     : Interrupt_Priority with Unreferenced;
      Handlers : New_Handler_Array)
   is
      use System.Tasking.Restricted.Stages;

   begin
      for J in Handlers'Range loop
         --  Copy the handler in the table that contains the user handlers

         User_Handlers (Handlers (J).Interrupt) :=
           (Handlers (J).Handler, Prio);

         --  Install the handler now, unless attachment is deferred because of
         --  sequential partition elaboration policy.

         if Partition_Elaboration_Policy /= 'S' then
            Install_Handler (Handlers (J).Interrupt);
         end if;
      end loop;
   end Install_Restricted_Handlers;

end System.Interrupts;
