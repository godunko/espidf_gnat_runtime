
package body System.Multiprocessors is

   --------------------
   -- Number_Of_CPUs --
   --------------------

   function Number_Of_CPUs return CPU is
   begin
      return CPU_Range'Last;
   end Number_Of_CPUs;

end System.Multiprocessors;
