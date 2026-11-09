--  Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--  Embedded stack sizes must be static for compiler-preallocated task stacks.

package System.Parameters with Pure is
   pragma Elaborate_Body;

   type Size_Type is range -Memory_Size / 2 .. Memory_Size / 2 - 1;

   Unspecified_Size : constant Size_Type := Size_Type'First;

   Default_Stack_Size : constant Size_Type := 20 * 1_024;

   Minimum_Stack_Size : constant Size_Type := 8 * 1_024;

   function Adjust_Storage_Size (Size : Size_Type) return Size_Type is
     (if Size = Unspecified_Size then Default_Stack_Size
      elsif Size < Minimum_Stack_Size then Minimum_Stack_Size
      else Size);

   Stack_Grows_Down : constant Boolean := True;

   Runtime_Default_Sec_Stack_Size : constant Size_Type := 4096;

   Sec_Stack_Dynamic : constant Boolean := False;

   long_bits : constant := Long_Integer'Size;

   ptr_bits  : constant := Standard'Address_Size;
   subtype C_Address is System.Address;

   C_Malloc_Linkname : constant String := "__gnat_malloc";

   No_Abort : constant Boolean := True;

   Max_Attribute_Count : constant := 4;

   Max_Task_Image_Length : constant := 32;

   Default_Exception_Msg_Max_Length : constant := 200;

end System.Parameters;
