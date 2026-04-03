# GNAT Runtime for ESP-IDF

This crate provides GNAT Runtime to run Ada applications on boards with ESP32S3 MCU.

It should be used as component of ESP-IDF (Espressif IoT Development Framework).
See [project template](https://github.com/godunko/esp32s3_template).

It doesn't support Ada tasks and protected objects yet, however, most of other important Ada langugage features are supported. Some of them:
 * exceptions
 * secondary stack (static allocation)
 * controlled objects

Rich set of standard packages are supported:
 * `Ada.Containers.*`
 * `Ada.Exceptions`
 * `Ada.Finalization`
 * `Ada.Numerics.*`
 * `Ada.Strings.*`
 
Runtime is task-safe, it means Ada code can be executed by any FreeRTOS thread, including parallel execution on both cores. This allows to use components like ESP/TinyUSB and WiFi in Ada application (these components creates internal tasks and executes callbacks in context of these tasks).

Ada subprograms can be used as ISR subprograms, but language features that requires runtime lock should not be used.
