# ESP-IDF GNAT Runtime

[![ACATS](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml/badge.svg)](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml)
[![Alire](https://img.shields.io/badge/Alire-Crate-blue)](https://alire.ada.dev)
[![License: GPL-3.0 w/ GCC Exception](https://img.shields.io/badge/License-GPL--3.0--with--GCC--exception-blue.svg)](https://spdx.org/licenses/GPL-3.0-with-GCC-exception.html)

The **`espidf_gnat_runtime`** provides the GNAT runtime libraries for **Ada**
and **SPARK** applications on Espressif SoCs running ESP-IDF.

## Supported architectures and features

* **Xtensa:** ESP32 and ESP32-S3.
* **RISC-V:** ESP32-C3.
* Exception handling, controlled types, and secondary stacks.
* Standard packages including `Ada.Numerics`, `Ada.Strings`, and `Ada.Containers`.
* Ada tasks and protected objects, with support for the Jorvik profile subject
  to the scheduling limitations below.
* Interoperability with ESP-IDF services and tasks created outside Ada.

## Requirements

This repository is both an **Alire crate** and an **ESP-IDF component**. Use the
same checkout for both systems. The component manifest requires ESP-IDF `>=6.0`.

You need:

1. **[Alire](https://alire.ada.dev/)**, the Ada package manager.
2. **ESP-IDF SDK**, installed and configured in your environment path.
3. **GNAT cross-compiler**, supplied through Alire dependencies
   (`xtensa-esp32-elf` or `riscv64-elf`).

## Getting started

Projects require specific toolchain, linker, and build settings. Initialize a
project using one of these templates or the project-generation skill:

* **ESP32 (Xtensa, LX6):** [esp32_template](https://github.com/RREE/esp32_template)
* **ESP32-C3 (RISC-V):** [esp32c3_template](https://github.com/godunko/esp32c3_template)
* **ESP32-S3 (Xtensa, LX7):** [esp32s3_template](https://github.com/godunko/esp32s3_template)
* **AI-assisted project generation:** the
  [ada-espidf-skeleton agent skill](https://github.com/godunko/ada_espidf_skills/tree/main/ada-espidf-skeleton).

### Connecting an Alire application to ESP-IDF

After registering the application component and requiring `espidf_gnat_runtime`,
include the helper by the runtime's component directory:

```cmake
idf_component_get_property(runtime_dir espidf_gnat_runtime COMPONENT_DIR)
include("${runtime_dir}/cmake/ada-application.cmake")

espidf_add_ada_application(
    TARGET "${COMPONENT_LIB}"
    PROJECT_DIR "${PROJECT_DIR}"
    OBJECT ".objs/app_main.o")
```

`PROJECT_DIR` identifies the Alire application directory. `OBJECT` is the
relocatable object produced by its GPR project, relative to that directory or
absolute. The application must configure runtime generation, GPR and binder
settings, and produce that object. Build with `idf.py build`, which invokes
`alr -n build` for the Ada application.

The ESP-IDF build generates required runtime constants automatically. Before a
standalone `alr build`, run `idf.py gnat_system_os_constants`.

## GNAT runtime configuration for ESP32-S3

Set the target with `idf.py set-target esp32s3`. Configure the application with
`idf.py menuconfig`, or put settings in `sdkconfig.defaults`. Defaults supply
values only for settings not already present in `sdkconfig`; changing defaults
does not override an existing configured value.

With the ESP-IDF 6.1 GCC toolchain, use these required selections:

```ini
CONFIG_COMPILER_CXX_EXCEPTIONS=y
CONFIG_LIBC_NEWLIB=y
CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS=2
```

* Enable C++ exceptions even if the application contains no C++ code; Ada
  exception propagation requires this setting.
* Select Newlib. Picolibc is not supported for this runtime.
* Reserve a FreeRTOS TLS pointer slot for Ada. In **Component config > GNAT
  Runtime**, `CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT` defaults to 1. Slot 0 is
  reserved for pthread, and other components must not use the selected Ada
  slot. The current runtime settings use slot 1 and exactly two TLS slots.
* Retain `CONFIG_FREERTOS_HZ=100` and keep
  `CONFIG_FREERTOS_UNICORE` disabled to match the current runtime settings.
  Changing either option requires corresponding runtime changes.

The menu locations are **Compiler options > Enable C++ exceptions**,
**Component config > LibC > LibC to build application with**, and
**Component config > FreeRTOS > Kernel** for TLS slots, tick rate, and single-core
selection.

Configure `CONFIG_ESP_MAIN_TASK_STACK_SIZE` and `CONFIG_FREERTOS_ISR_STACKSIZE`
to suit the application's workload, including initialization, interrupt nesting,
and exception handling. The runtime requires no fixed values for these sizes.
Size Ada-created task stacks separately with Ada task storage settings.
Ada elaboration and execution of the Ada main subprogram
run sequentially on the same task. If that task is not the ESP-IDF main task,
size its stack to cover both elaboration and execution of
the Ada main subprogram.
The ISR stack size is per CPU and separate from Ada secondary stacks.
When using `-fstack-check`, increase each affected task or ISR stack by
**12 KiB** above its application workload budget; see below.

### Secondary-stack sizing

Reserve a default secondary stack for the environment task, one per CPU for
interrupt handlers, and one for each additional foreign thread needing a
secondary stack. For dual-core ESP32-S3
with no additional foreign threads, add these switches to the application's GPR
file, preserving its other binder switches:

```ada
package Binder is
   for Switches ("Ada") use ("-D4k", "-Q3");
end Binder;
```

`-Qnnn` allocates additional secondary stacks. The Ada environment task requires
one, and each CPU requires its own for handling nested interrupts. With F
foreign threads, use `-Q(1+F+N)` where N is the number of CPUs; for example,
two CPUs with four foreign threads require `-Q7`.

`-D4k` sets the default secondary-stack size to 4096 bytes. Each CPU's nested
interrupt handlers share a secondary stack; size it for their maximum combined
live allocations.

### Primary stack checking

Enable `-fstack-check` in the application's GPR compiler switches for each Ada
unit needing primary stack checking. It is disabled by default. Keep the
runtime and exception machinery compiled without it. A failed check raises
`Storage_Error`.

Increase each task or ISR stack executing code compiled with `-fstack-check`
by **12 KiB** above the size needed for its application workload. This covers
the current compiler's 12,284-byte allowance for exception recovery and
unchecked frame growth. Without a current FreeRTOS task and outside interrupt
context, checks are skipped.

## Usage and limitations

### Interrupt handlers and callbacks

* Ada handlers and callbacks support **hardware interrupt levels `1`..`3`**. The
  three `System.Interrupt_Priority` values map to these levels; the default
  selects level 3. Levels `4`..`7`, including `NMI`, require assembly handlers.
* Nested interrupts and direct calls from ESP-IDF ISR callbacks are supported
  without an Ada entry adapter or prior registration of the interrupted task.
  Use only nonblocking, ISR-compatible operations in ISR code.
* Exceptions must stay inside callback boundaries. The runtime contains
  exceptions escaping protected handlers. Ordinary callbacks
  exported to C must catch exceptions before returning to ESP-IDF.

### Scheduling and time

FreeRTOS scheduling does not fully implement Ada `FIFO_Within_Priorities`:
equal-priority tasks can time-slice. Full Jorvik scheduling conformance is not
claimed.

`Ada.Real_Time.Clock` is monotonic and boot-relative. `Ada.Calendar.Clock` uses
ESP-IDF wall time, which the application or SDK must initialize or synchronize.
Delays use FreeRTOS ticks (10 ms at `CONFIG_FREERTOS_HZ=100`), plus scheduling
latency; microsecond clock units do not imply microsecond wakeups.

### Threads created outside Ada

After Ada partition elaboration complete, C or ESP-IDF tasks
can call Ada without an application registration call. First use of Ada task
context allocates runtime resources; subsequent calls reuse them. Validate the
native task's primary stack budget for its Ada workload.

Ada restores the native priority observed at attachment after protected
actions, including priority 0. Independent C-side priority changes and native
priority inheritance are not tracked by Ada's priority metadata.

## License

This project is licensed under **GPL-3.0 or later with GCC-exception-3.1** — see
[LICENSE](LICENSE) for details.
