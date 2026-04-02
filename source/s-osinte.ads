
with Interfaces;

package System.OS_Interface is
   pragma Preelaborate;

   -------------------------------------------------------
   -- Declarations for Ada.Real_Time from `bb-runtimes` --
   -------------------------------------------------------

   ----------
   -- Time --
   ----------

   subtype Time is Interfaces.Unsigned_64;
   --  Representation of the time in the underlying tasking system

   subtype Time_Span is Interfaces.Integer_64;
   --  Represents the length of time intervals in the underlying tasking
   --  system.

   Ticks_Per_Second : constant := 1_000_000;
   --  Number of clock ticks per second
   --
   --  ESP/IDF use microsecond unit

end System.OS_Interface;
