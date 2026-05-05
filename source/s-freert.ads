
with Interfaces.C;

package System.FreeRTOS is
   pragma Preelaborate;

   subtype char     is Interfaces.C.char;
   subtype uint32_t is Interfaces.Unsigned_32;
   subtype size_t   is Interfaces.C.size_t;

   type BaseType_t is new Interfaces.C.int;

   pdFALSE : constant BaseType_t := 0;
   pdTRUE  : constant BaseType_t := 1;

   type UBaseType_t is new Interfaces.C.unsigned;

   type TickType_t is new uint32_t;

   portMAX_DELAY : constant TickType_t := TickType_t'Last;

   type configSTACK_DEPTH_TYPE is new uint32_t;

   configMAX_PRIORITIES : constant := 25;

   function To_FreeRTOS_Priority
     (Priority : System.Priority) return UBaseType_t;
   --  Converts Ada task priority into FreeRTOS task priority. Valid for
   --  software priorities only (doesn't support hardware interrupt
   --  priorities).

   function pdMS_TO_TICKS (MS : Interfaces.C.unsigned) return TickType_t
     with Import, Convention => C, External_Name => "__gnat_pdMS_TO_TICKS";

   function pdTICKS_TO_MS (Ticks : TickType_t) return Interfaces.C.unsigned
     with Import, Convention => C, External_Name => "__gnat_pdTICKS_TO_MS";

   function xTaskGetTickCount return TickType_t
     with Import, Convention => C, External_Name => "xTaskGetTickCount";

   function xPortInIsrContext return BaseType_t
     with Import, Convention => C, External_Name => "xPortInIsrContext";

   type TaskHandle_t is private;

   Null_TaskHandle_t : constant TaskHandle_t;

   type TaskFunction_t is access procedure (arg : System.Address)
     with Convention => C;

   function xTaskCreate
     (pvTaskCode    : TaskFunction_t;
      pcName        : access constant char;
      uxStackDepth  : configSTACK_DEPTH_TYPE;
      pvParameters  : System.Address;
      uxPriority    : UBaseType_t;
      pxCreatedTask : out TaskHandle_t) return BaseType_t
     with Import, Convention => C, External_Name => "__gnat_xTaskCreate";

   procedure vTaskDelete (xTask : TaskHandle_t)
     with Import, Convention => C, External_Name => "vTaskDelete";

   function xTaskGetCurrentTaskHandle return TaskHandle_t
     with Import, Convention => C,
          External_Name => "xTaskGetCurrentTaskHandle";

   procedure vTaskPrioritySet
     (xTask         : TaskHandle_t;
      uxNewPriority : UBaseType_t)
     with Import, Convention => C,
          External_Name => "vTaskPrioritySet";

   procedure vTaskDelay (xTicksToDelay : TickType_t)
     with Import, Convention => C, External_Name => "vTaskDelay";

   type SemaphoreHandle_t is private;

   Null_SemaphoreHandle_t : constant SemaphoreHandle_t;

   function xSemaphoreCreateBinary return SemaphoreHandle_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreCreateBinary";

   function xSemaphoreCreateMutex return SemaphoreHandle_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreCreateMutex";

   function xSemaphoreCreateRecursiveMutex return SemaphoreHandle_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreCreateRecursiveMutex";

   procedure vSemaphoreDelete
     (xSemaphore : SemaphoreHandle_t)
     with Import, Convention => C, External_Name => "__gnat_vSemaphoreDelete";

   function xSemaphoreTake
     (xSemaphore   : SemaphoreHandle_t;
      xTicksToWait : TickType_t) return BaseType_t
     with Import, Convention => C, External_Name => "__gnat_xSemaphoreTake";

   function xSemaphoreTakeFromISR
     (xSemaphore   : SemaphoreHandle_t;
      pxHigherPriorityTaskWoken : access BaseType_t) return BaseType_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreTakeFromISR";

   function xSemaphoreTakeRecursive
     (xMutex       : SemaphoreHandle_t;
      xTicksToWait : TickType_t) return BaseType_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreTakeRecursive";

   function xSemaphoreGive (xSemaphore : SemaphoreHandle_t) return BaseType_t
     with Import, Convention => C, External_Name => "__gnat_xSemaphoreGive";

   function xSemaphoreGiveFromISR
     (xSemaphore   : SemaphoreHandle_t;
      pxHigherPriorityTaskWoken : access BaseType_t) return BaseType_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreGiveFromISR";

   function xSemaphoreGiveRecursive
     (xMutex : SemaphoreHandle_t) return BaseType_t
     with Import, Convention => C,
          External_Name => "__gnat_xSemaphoreGiveRecursive";

private

   type TaskHandle_t is new System.Address;

   Null_TaskHandle_t : constant TaskHandle_t :=
     TaskHandle_t (System.Null_Address);

   type SemaphoreHandle_t is new System.Address;

   Null_SemaphoreHandle_t : constant SemaphoreHandle_t :=
     SemaphoreHandle_t (System.Null_Address);

end System.FreeRTOS;
