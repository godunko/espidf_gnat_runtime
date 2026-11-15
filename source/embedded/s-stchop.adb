--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

with Interfaces.C;
with System.OS_Interface;

package body System.Stack_Checking.Operations is

   use type System.OS_Interface.BaseType_t;
   use type System.OS_Interface.TaskHandle_t;

   function Frame_Address (Level : Interfaces.C.unsigned) return System.Address
   with
     Import,
     Convention    => Intrinsic,
     External_Name => "__builtin_frame_address";

   -----------------
   -- Stack_Check --
   -----------------

   function Stack_Check
     (Stack_Address : System.Address) return System.Stack_Checking.Stack_Access
   is
      Bottom : System.Address;
      Top    : System.Address;
      Thread : System.OS_Interface.TaskHandle_t;

   begin
      if System.OS_Interface.xPortInIsrContext /= 0 then
         System.OS_Interface.Get_Interrupt_Stack_Bounds (Bottom, Top);

         if Stack_Address < Bottom or else Stack_Address >= Top then
            raise Storage_Error with "interrupt stack exhausted";
         end if;

      else
         Thread := System.OS_Interface.xTaskGetCurrentTaskHandle;

         if Thread = System.OS_Interface.Null_TaskHandle_t then
            --  No current FreeRTOS task: its stack bounds are unavailable.

            return null;
         end if;

         Bottom := System.OS_Interface.xTaskGetStackStart (Thread);

         if Stack_Address < Bottom then
            raise Storage_Error with "task stack exhausted";
         end if;
      end if;

      --  Reject subtraction wrapping upward. GCC already includes its
      --  recovery allowance in Stack_Address; do not adjust that address.

      if Stack_Address > Frame_Address (0) then
         raise Storage_Error with "stack address wrapped";
      end if;

      --  Bounds are read directly, without a cache or ATCB registration.

      return null;
   end Stack_Check;

end System.Stack_Checking.Operations;
