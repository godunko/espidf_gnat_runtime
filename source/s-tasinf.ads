
--  This package contains the definitions and routines associated with the
--  implementation and use of the Task_Info pragma. It is specialized
--  appropriately for targets that make use of this pragma.

--  Note: the compiler generates direct calls to this interface, via Rtsfind.
--  Any changes to this interface may require corresponding compiler changes.

--  The functionality in this unit is now provided by the predefined package
--  System.Multiprocessors and the CPU aspect. This package is obsolescent.

--  This is the FreeRTOS version of this package

with Interfaces.C;

package System.Task_Info is
   pragma Obsolescent (Task_Info, "use System.Multiprocessors and CPU aspect");
   pragma Preelaborate;

   -----------------------------------------
   -- Implementation of Task_Info Feature --
   -----------------------------------------

   --  The Task_Info pragma:

   --    pragma Task_Info (EXPRESSION);

   --  allows the specification on a task by task basis of a value of type
   --  System.Task_Info.Task_Info_Type to be passed to a task when it is
   --  created. The specification of this type, and the effect on the task
   --  that is created is target dependent.

   --  The Task_Info pragma appears within a task definition (compare the
   --  definition and implementation of pragma Priority). If no such pragma
   --  appears, then the value Unspecified_Task_Info is passed. If a pragma
   --  is present, then it supplies an alternative value. If the argument of
   --  the pragma is a discriminant reference, then the value can be set on
   --  a task by task basis by supplying the appropriate discriminant value.

   --  Note that this means that the type used for Task_Info_Type must be
   --  suitable for use as a discriminant (i.e. a scalar or access type).

   ------------------
   -- Declarations --
   ------------------

   subtype Task_Info_Type is Interfaces.C.int;
   --  This is a CPU number (natural - CPUs are 0-indexed on VxWorks)

   use type Interfaces.C.int;

   Unspecified_Task_Info : constant Task_Info_Type := -1;
   --  Value passed to task in the absence of a Task_Info pragma
   --  This value means do not try to set the CPU affinity

end System.Task_Info;
