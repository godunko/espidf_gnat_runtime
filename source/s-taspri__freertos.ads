
--  This is a FreeRTOS version of this package

--  This package and its children provide a binding to the underlying platform.
--  The base types are defined here while the functional implementations
--  are in ``Task_Primitives.Operations``.

with System.FreeRTOS;
with System.OS_Interface;
with System.OS_Locks;

package System.Task_Primitives is
   pragma Preelaborate;

   type Lock is limited private;
   --  Should be used for implementation of protected objects

   type Private_Data is limited private;
   --  Any information that the GNULLI needs maintained on a per-task basis.
   --  A component of this type is guaranteed to be included in the
   --  Ada_Task_Control_Block.

   Task_Address_Size : constant := Standard'Address_Size;
   --  Type used for task addresses and its size

private

   type Lock is new System.OS_Locks.RTS_Lock;

   type Private_Data is limited record
      Thread : aliased System.OS_Interface.Thread_Id :=
        System.OS_Interface.Null_Thread_Id;
      pragma Atomic (Thread);
      --  Thread field may be updated by two different threads of control.
      --  (See, Enter_Task and Create_Task in s-taprop.adb).
      --  They put the same value (thr_self value). We do not want to
      --  use lock on those operations and the only thing we have to
      --  make sure is that they are updated in atomic fashion.

--      LWP : aliased System.OS_Interface.t_id := 0;
      --  The purpose of this field is to provide a better tasking support on
      --  gdb. The order of the two first fields (Thread and LWP) is important.
      --  On targets where lwp is not relevant, this is equivalent to Thread.

      CV : aliased System.FreeRTOS.SemaphoreHandle_t;
      --  Condition variable used to queue threads until condition is signaled

      L  : aliased System.OS_Locks.RTS_Lock;
      --  Protection for all components is lock L
   end record;

end System.Task_Primitives;
