--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

with Interfaces;
with System.Multiprocessors;
with System.OS_Constants;
with System.Storage_Elements;

package System.OS_Interface is

   pragma Preelaborate;

   type StaticTask_t is private;

   type Thread_Id is new Address;
   Null_Thread_Id : constant Thread_Id := Thread_Id (Null_Address);
   subtype Time is Interfaces.Unsigned_64;
   subtype Time_Span is Interfaces.Integer_64;
   Ticks_Per_Second : constant := 1_000_000;
   function Clock return Time;
   procedure Delay_Until (T : Time);
   procedure Initialize (ATCB : Address);
   function Thread_Self return Thread_Id;
   function Get_ATCB return Address;
   function Thread_Create
     (Code, Arg, Stack, Task_Buffer : Address;
      Stack_Size : Storage_Elements.Storage_Offset;
      Priority : Integer;
      Base_CPU : Multiprocessors.CPU_Range) return Thread_Id;
   procedure Set_Priority (Priority : Integer);
   function Get_Priority (Id : Thread_Id) return Integer;
   function Get_Affinity (Id : Thread_Id) return Multiprocessors.CPU_Range;
   function Get_CPU (Id : Thread_Id) return Multiprocessors.CPU;
   procedure Sleep;
   procedure Wakeup (Id : Thread_Id);
   function Is_Task_Context return Boolean;

private

   type StaticTask_t is
     new System.Storage_Elements.Storage_Array
          (1 .. System.OS_Constants.StaticTask_t_Size)
   with Alignment => System.OS_Constants.StaticTask_t_Alignment;

   pragma Compile_Time_Error
     (StaticTask_t'Size /=
        System.OS_Constants.StaticTask_t_Size * System.Storage_Unit,
      "StaticTask_t storage size mismatch");

end System.OS_Interface;