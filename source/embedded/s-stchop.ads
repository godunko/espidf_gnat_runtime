--
--  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

--  Package in charge of providing stack overflow checking in bare board
--  environments.

pragma Restrictions (No_Elaboration_Code);
--  We want to guarantee the absence of elaboration code because the
--  binder does not handle references to this package.

package System.Stack_Checking.Operations with Preelaborate is

   function Stack_Check
     (Stack_Address : System.Address) return System.Stack_Checking.Stack_Access
   with
     No_inline,
     Export,
     Convention    => C,
     External_Name => "__gnat_stack_check";
   --  Successful checks return null; no stack-info cache is provided.
   --  GCC passes the prospective low address, including its recovery and
   --  unchecked-frame allowances, before extending the downward stack.
   --  This routine, like the exception machinery, must be built without
   --  -fstack-check. The generated runtime projects use that configuration.

end System.Stack_Checking.Operations;
