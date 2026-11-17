--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

package body System.OS_Interface.ESPIDF is

   --------------
   -- To_Flags --
   --------------

   function To_Flags (Priority : Interrupt_Priority) return int is
   begin
      case Priority - Interrupt_Priority'First is
         when 0      =>
            return ESP_INTR_FLAG_LEVEL1;

         when 1      =>
            return ESP_INTR_FLAG_LEVEL2;

         when 2      =>
            return ESP_INTR_FLAG_LEVEL3;

         when others =>
            --  Should never happen, `Interrupt_Priority` is declared with a
            --  range of 3 values.

            raise Program_Error with "Invalid interrupt priority";
      end case;
   end To_Flags;

end System.OS_Interface.ESPIDF;