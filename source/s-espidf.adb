
package body System.ESPIDF is

   --------------
   -- To_Flags --
   --------------

   function To_Flags
     (Priority : Interrupt_Priority) return System.ESPIDF.int is
   begin
      case Priority - Interrupt_Priority'First is
         when 0 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL1;
         when 1 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL2;
         when 2 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL3;
         when 3 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL4;
         when 4 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL5;
         when 5 =>
            return System.ESPIDF.ESP_INTR_FLAG_LEVEL6;
         when 6 =>
            return System.ESPIDF.ESP_INTR_FLAG_NMI;
         when others =>
            --  Should never happen, `Interrupt_Priority` is declared with a
            --  range of 7 values.

            raise Program_Error with "Invalid interrupt priority";
      end case;
   end To_Flags;

end System.ESPIDF;