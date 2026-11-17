# ESP-IDF GNAT Runtime

[![ACATS](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml/badge.svg)](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml)
[![Alire](https://img.shields.io/badge/Alire-Crate-blue)](https://alire.ada.dev/crates/espidf_gnat_runtime)
[![License: GPL-3.0-or-later WITH GCC-exception-3.1](https://img.shields.io/badge/License-GPL--3.0--or--later_with_GCC--exception--3.1-blue.svg)](https://spdx.org/licenses/GCC-exception-3.1.html)

`espidf_gnat_runtime` is a GNAT runtime library for developing **Ada** and
**SPARK** applications on Espressif SoCs. It is built on top of ESP-IDF and
FreeRTOS, so Ada code runs alongside C code and ESP-IDF services in the same
firmware image.

## Contents

- [Features](#features)
- [Supported targets](#supported-targets)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Connecting an Alire application to ESP-IDF](#connecting-an-alire-application-to-esp-idf)
- [Configuration](#configuration)
- [Stack sizing](#stack-sizing)
- [Usage and limitations](#usage-and-limitations)
- [License](#license)

## Features

- Exception handling, controlled types, and secondary stacks.
- Standard library packages, including `Ada.Numerics`, `Ada.Strings`, and
  `Ada.Containers`.
- Ada tasks and protected objects under the Jorvik profile. Scheduling has
  limitations; see [Scheduling and time](#scheduling-and-time).
- Interoperability with ESP-IDF services and with tasks created outside Ada.
- Conformance testing with ACATS (see the badge above).

## Supported targets

| SoC      | Architecture    | Project template                                                    |
|----------|-----------------|---------------------------------------------------------------------|
| ESP32    | Xtensa (LX6)    | [esp32_template](https://github.com/RREE/esp32_template)            |
| ESP32-S3 | Xtensa (LX7)    | [esp32s3_template](https://github.com/godunko/esp32s3_template)     |
| ESP32-C3 | RISC-V          | [esp32c3_template](https://github.com/godunko/esp32c3_template)     |

## Requirements

This repository is both an **Alire crate** and an **ESP-IDF component**: the
same checkout serves both build systems. The component manifest requires
ESP-IDF `>=6.0`.

You need:

1. **[Alire](https://alire.ada.dev/)**, the Ada package manager.
2. **ESP-IDF SDK** `>=6.0`, installed and activated in your shell, so that
   `idf.py` is available on `PATH`.
3. **GNAT cross-compiler**, which Alire supplies as a dependency: the
   `xtensa-esp32-elf` toolchain for Xtensa targets or `riscv64-elf` for RISC-V
   targets.

## Getting started

Ada projects need specific toolchain, linker, and build settings. The easiest
way to get them is to start from a template for your SoC (see
[Supported targets](#supported-targets)).

Alternatively, you can generate a project with the
[ada-espidf-skeleton](https://github.com/godunko/ada_espidf_skills/tree/main/ada-espidf-skeleton)
agent skill, which creates the project structure with AI assistance.

## Connecting an Alire application to ESP-IDF

Register the application as an ESP-IDF component and add `espidf_gnat_runtime`
to its dependencies. Then include the helper script from the runtime's
component directory in the component's `CMakeLists.txt`:

```cmake
idf_component_get_property(runtime_dir espidf_gnat_runtime COMPONENT_DIR)
include("${runtime_dir}/cmake/ada-application.cmake")

espidf_add_ada_application(
    TARGET "${COMPONENT_LIB}"
    PROJECT_DIR "${PROJECT_DIR}"
    OBJECT ".objs/app_main.o")
```

- `PROJECT_DIR` is the directory of the Alire application.
- `OBJECT` is the relocatable object produced by the application's GPR
  project, given as an absolute path or relative to `PROJECT_DIR`.

The application's GPR project must configure runtime generation and the
compiler and binder settings, and it must produce that object.

Build the project with `idf.py build`; it runs `alr -n build` for the Ada
application. The ESP-IDF build generates the required runtime constants
automatically. To run `alr build` on its own, first run
`idf.py gnat_system_os_constants`.

## Configuration

The settings in this section are described for ESP32-S3. For other targets,
check the corresponding project template for the equivalent configuration.

Set the target with `idf.py set-target esp32s3`. Then configure the application
with `idf.py menuconfig`, or put the settings in `sdkconfig.defaults`.

> [!NOTE]
> `sdkconfig.defaults` provides values only for options that are not yet
> present in `sdkconfig`. Changing it does not override a value that is already
> stored there. To apply new defaults, remove `sdkconfig` (or the affected
> lines) and reconfigure.

### Required settings

With the ESP-IDF 6.1 GCC toolchain, select the following:

```ini
CONFIG_COMPILER_CXX_EXCEPTIONS=y
CONFIG_LIBC_NEWLIB=y
CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS=2
```

| Option | Why it is required | Menu location |
|--------|--------------------|---------------|
| `CONFIG_COMPILER_CXX_EXCEPTIONS` | Ada exception propagation needs C++ exceptions, even if the application has no C++ code. | **Compiler options > Enable C++ exceptions** |
| `CONFIG_LIBC_NEWLIB` | The runtime supports Newlib only; Picolibc is not supported. | **Component config > LibC > LibC to build application with** |
| `CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS` | Ada needs a FreeRTOS TLS pointer slot. The current runtime uses slot 1 and exactly two slots in total. | **Component config > FreeRTOS > Kernel** |

The TLS slot used by Ada is set by `CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT` in
**Component config > GNAT Runtime**; it defaults to 1. Slot 0 is reserved for
pthread, and no other component may use the slot selected for Ada.

## Stack sizing

### Task and interrupt stacks

The runtime does not require fixed values for `CONFIG_ESP_MAIN_TASK_STACK_SIZE`
and `CONFIG_FREERTOS_ISR_STACKSIZE`. Choose them for the needs of your
application, including initialization, interrupt nesting, and exception
handling.

- **ISR stack.** The size is per CPU and is separate from Ada secondary stacks.
- **Ada tasks.** Size the stacks of tasks created by Ada separately, using Ada
  task storage settings.
- **Environment task.** Ada elaboration and the execution of the Ada main
  subprogram run one after the other on the same task. If that task is not the
  ESP-IDF main task, size its stack to cover both.
- **Stack checking.** If you use `-fstack-check`, add **12 KiB** to the stack
  of each affected task or ISR; see
  [Primary stack checking](#primary-stack-checking).

### Secondary stacks

Reserve secondary stacks for:

- the environment task (one default secondary stack);
- interrupt handlers (one per CPU);
- each additional foreign thread that needs a secondary stack.

For a dual-core ESP32-S3 with no additional foreign threads, add these
switches to the application's GPR file, keeping its other binder switches:

```ada
package Binder is
   for Switches ("Ada") use ("-D4k", "-Q3");
end Binder;
```

- `-D4k` sets the default secondary stack size to 4096 bytes. Nested interrupt
  handlers on the same CPU share one secondary stack, so size it for their
  maximum combined live allocations.
- `-Qnnn` sets the number of secondary stacks to allocate. With `F` foreign
  threads and `N` CPUs, use `-Q(1+F+N)`: one stack for the environment task,
  one for each foreign thread, and one for each CPU. For example, two CPUs and
  four foreign threads require `-Q7`.

### Primary stack checking

Primary stack checking is disabled by default. To enable it, add
`-fstack-check` to the GPR compiler switches of each Ada unit that needs it.
Compile the runtime and the exception machinery without it. A failed check
raises `Storage_Error`.

Increase the stack of each task or ISR that runs code compiled with
`-fstack-check` by **12 KiB** above the size needed for its application
workload. This covers the 12,284-byte allowance the current compiler makes for
exception recovery and unchecked frame growth.

Checks are skipped when there is no current FreeRTOS task and the code is not
running in interrupt context.

## Usage and limitations

### Interrupt handlers and callbacks

- Ada handlers and callbacks support **hardware interrupt levels 1 to 3**. The
  three `System.Interrupt_Priority` values map to these levels, and the default
  priority selects level 3. Levels 4 to 7, including `NMI`, require handlers
  written in assembly.
- Nested interrupts are supported. ESP-IDF ISR callbacks can call Ada directly,
  without an Ada entry adapter or prior registration of the interrupted task.
  Use only nonblocking, ISR-compatible operations in ISR code.
- Exceptions must not leave a callback. The runtime contains exceptions that
  escape protected handlers. Ordinary callbacks exported to C must catch all
  exceptions before returning to ESP-IDF.

### Scheduling and time

FreeRTOS scheduling does not fully implement Ada `FIFO_Within_Priorities`:
tasks of equal priority can be time-sliced. Full conformance to Jorvik
scheduling is not claimed.

- `Ada.Real_Time.Clock` is monotonic and relative to boot.
- `Ada.Calendar.Clock` uses ESP-IDF wall time, which the application or the SDK
  must set or synchronize.
- Delays are counted in FreeRTOS ticks (10 ms at the default `CONFIG_FREERTOS_HZ=100`) plus
  scheduling latency. Microsecond clock units do not imply microsecond wakeup
  accuracy.

### Threads created outside Ada

Once Ada partition elaboration completes, C and ESP-IDF tasks can call Ada
without any registration call. The first use of Ada task context in a thread
allocates runtime resources; later calls reuse them. Check that the native
task's primary stack is large enough for its Ada workload.

After a protected action, Ada restores the native priority that the task had
when it first attached to Ada, including priority 0. Ada does not track
priority changes made independently on the C side, or native priority
inheritance, in its own priority metadata.

## License

This project is licensed under **GPL-3.0 or later with GCC-exception-3.1**.
See [LICENSE](LICENSE) for details.
