
--  This is ESP-IDF/FreeRTOS version of this package

with Interfaces;

with System.FreeRTOS;

package System.OS_Interface is
   pragma Preelaborate;

   -------------
   -- Threads --
   -------------

   subtype Thread_Id is System.FreeRTOS.TaskHandle_t;

   Null_Thread_Id : constant Thread_Id := System.FreeRTOS.Null_TaskHandle_t;

   ----------------
   -- Interrupts --
   ----------------

   Max_Interrupt : constant := 98;
   --  Max number of peripheral interrupt sources on ESP32S3.
   --
   --  XXX Should it be declared in MCU specific package?

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

   function To_Ticks (D : Duration) return System.FreeRTOS.TickType_t;
   --  Convert a duration value (in seconds) into FreeRTOS ticks. Negative
   --  durations are converted to zero. Durations that are too large to be
   --  represented in the underlying tasking system are converted to the
   --  maximum representable value (portMAX_DELAY).

   function To_Duration (Ticks : System.FreeRTOS.TickType_t) return Duration;
   --  Convert FreeRTOS ticks into a duration value (in seconds)

end System.OS_Interface;
