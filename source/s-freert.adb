
package body System.FreeRTOS is

   --------------------------
   -- To_FreeRTOS_Priority --
   --------------------------

   function To_FreeRTOS_Priority
     (Priority : System.Priority) return UBaseType_t is
   begin
      --  FreeRTOS priorities are mapped directly to Ada priorities. Assert
      --  that the Ada priorities are starts at zero, and that the number of
      --  Ada priorities matches configured number of FreeRTOS priorities.
      pragma Assert (System.Priority'First = 0);
      pragma Assert
        (System.Priority'Last + 1 = System.FreeRTOS.configMAX_PRIORITIES);

      return UBaseType_t (Priority);
   end To_FreeRTOS_Priority;

end System.FreeRTOS;
