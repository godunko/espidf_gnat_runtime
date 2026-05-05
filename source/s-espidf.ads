
with Interfaces.C;

package System.ESPIDF is
   pragma Preelaborate;

   subtype int is Interfaces.C.int;

   type esp_err_t is new int;

   ESP_OK : constant esp_err_t := 0;

   type intr_handle_data_t is limited private;

   type intr_handle_t is access all intr_handle_data_t
     with Convention => C, Storage_Size => 0;

   type intr_handler_t is access procedure (arg : System.Address)
     with Convention => C;

   ESP_INTR_FLAG_LEVEL1 : constant int := 2#0000_0010#;
   ESP_INTR_FLAG_LEVEL2 : constant int := 2#0000_0100#;
   ESP_INTR_FLAG_LEVEL3 : constant int := 2#0000_1000#;
   ESP_INTR_FLAG_LEVEL4 : constant int := 2#0001_0000#;
   ESP_INTR_FLAG_LEVEL5 : constant int := 2#0010_0000#;
   ESP_INTR_FLAG_LEVEL6 : constant int := 2#0100_0000#;
   ESP_INTR_FLAG_NMI    : constant int := 2#1000_0000#;

   function esp_intr_alloc
     (source     : int;
      flags      : int;
      handler    : intr_handler_t;
      arg        : System.Address;
      ret_handle : access intr_handle_t) return esp_err_t
      with Import, Convention => C, Link_Name => "esp_intr_alloc";

   function To_Flags
     (Priority : Interrupt_Priority) return System.ESPIDF.int;
   --  Convert an interrupt priority into the corresponding ESP-IDF flag value

private

   type intr_handle_data_t is null record with Convention => C;

end System.ESPIDF;