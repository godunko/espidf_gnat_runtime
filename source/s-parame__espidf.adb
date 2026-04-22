
--  This is ESP-IDF/FreeRTOS version of the package

package body System.Parameters is

   -------------------------
   -- Adjust_Storage_Size --
   -------------------------

   function Adjust_Storage_Size (Size : Size_Type) return Size_Type is
   begin
      if Size = Unspecified_Size then
         return Default_Stack_Size;
      elsif Size < Minimum_Stack_Size then
         return Minimum_Stack_Size;
      else
         return Size;
      end if;
   end Adjust_Storage_Size;

   ------------------------
   -- Default_Stack_Size --
   ------------------------

   function Default_Stack_Size return Size_Type is
      Default_Stack_Size : constant Integer;
      pragma Import (C, Default_Stack_Size, "__gl_default_stack_size");
   begin
      if Default_Stack_Size = -1 then
         return 20 * 1024;
      elsif Size_Type (Default_Stack_Size) < Minimum_Stack_Size then
         return Minimum_Stack_Size;
      else
         return Size_Type (Default_Stack_Size);
      end if;
   end Default_Stack_Size;

   ------------------------
   -- Minimum_Stack_Size --
   ------------------------

   function Minimum_Stack_Size return Size_Type is
   begin
      --  12K is required for stack-checking to work reliably on most platforms
      --  when using the GCC scheme to propagate an exception in the ZCX case.
      --  16K is the value of PTHREAD_STACK_MIN under Linux, so is a reasonable
      --  default.

      --  Stack check is not implemented for ESP-IDF, so limit is to 8K

      return 8 * 1024;
   end Minimum_Stack_Size;

end System.Parameters;
