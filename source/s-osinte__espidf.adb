
--  This is ESP-IDF/FreeRTOS version of this package

with Interfaces.C;

package body System.OS_Interface is

   -----------------
   -- To_Duration --
   -----------------

   function To_Duration
     (Ticks : System.FreeRTOS.TickType_t) return Duration
   is
      MS : constant Interfaces.C.unsigned :=
        System.FreeRTOS.pdTICKS_TO_MS (Ticks);

   begin
      return Duration (MS) / 1_000.0;
   end To_Duration;

   --------------
   -- To_Ticks --
   --------------

   function To_Ticks (D : Duration) return System.FreeRTOS.TickType_t is
      use type System.FreeRTOS.TickType_t;

   begin
      if D <= 0.0 then
         return 0;

      elsif D > To_Duration (System.FreeRTOS.portMAX_DELAY - 1) then
         return System.FreeRTOS.portMAX_DELAY;

      else
         return Result : System.FreeRTOS.TickType_t :=
           System.FreeRTOS.pdMS_TO_TICKS (Interfaces.C.unsigned (D * 1_000.0))
         do
            if To_Duration (Result) < D then
               Result := @ + 1;
            end if;
         end return;
      end if;
   end To_Ticks;

end System.OS_Interface;
