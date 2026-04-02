
package body System.OS_Interface is

   ATCB : aliased System.Address := System.Null_Address;
   pragma Thread_Local_Storage (ATCB);

   --------------
   -- Get_ATCB --
   --------------

   function Get_ATCB return System.Address is
   begin
      return ATCB;
   end Get_ATCB;

   --------------
   -- Set_ATCB --
   --------------

   procedure Set_ATCB (Self_ATCB : System.Address) is
   begin
      ATCB := Self_ATCB;
   end Set_ATCB;

end System.OS_Interface;
