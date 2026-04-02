--
--  This is the FreeRTOS version of this package

--  This package contains all the GNULL primitives that interface directly with
--  the underlying OS.

package body System.Task_Primitives.Operations is

   function Monotonic_Clock return Duration is
   begin
      raise Program_Error;
      return 0.0;
   end Monotonic_Clock;

end System.Task_Primitives.Operations;
