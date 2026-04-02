--
--  This is a FreeRTOS version of this package

--  This package and its children provide a binding to the underlying platform.
--  The base types are defined here while the functional implementations
--  are in ``Task_Primitives.Operations``.

package System.Task_Primitives is
   pragma Preelaborate;

   Task_Address_Size : constant := Standard'Address_Size;
   --  Type used for task addresses and its size

end System.Task_Primitives;
