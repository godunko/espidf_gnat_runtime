--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1

package System.ESPIDF_Activation is
   pragma Preelaborate;
   procedure Begin_Group
     with Import, Convention => C, External_Name => "__gnat_embedded_begin";
   procedure Commit_Group
     with Import, Convention => C, External_Name => "__gnat_embedded_commit";
   procedure Abort_Group
     with Import, Convention => C, External_Name => "__gnat_embedded_abort";
end System.ESPIDF_Activation;
