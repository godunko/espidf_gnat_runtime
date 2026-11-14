# ESP-IDF GNAT Runtime

[![ACATS](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml/badge.svg)](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml)
[![Alire](https://img.shields.io/badge/Alire-Crate-blue)](https://alire.ada.dev)
[![License: GPL-3.0 w/ GCC Exception](https://img.shields.io/badge/License-GPL--3.0--with--GCC--exception-blue.svg)](https://spdx.org/licenses/GPL-3.0-with-GCC-exception.html)

The **`espidf_gnat_runtime`** provides the GNAT runtime support libraries required to develop **Ada** and **SPARK** applications for Espressif SoCs. It serves as the foundational layer enabling the GNAT compiler to target Espressif’s hardware, bridging Ada language features with the underlying system.

## Supported Architectures

* **Xtensa:** Full support for the **ESP32**, **ESP32-S3** series.
* **RISC-V:** Full support for the **ESP32-C3** series.

## Key Features

* **Ada Language Support:** Implementation of essential features, including exception handling, controlled types, and secondary stacks.
* **Standard Library:** Support for a rich set of standard packages, including `Ada.Numerics`, `Ada.Strings`, `Ada.Containers`, and more.
* **Real-Time Concurrency:** Support for the **Jorvik profile**, enabling safe, deterministic Ada tasks and protected objects.
* **Hardware Interoperability:** Support for applications running alongside the **ESP-IDF** environment, allowing Ada code to coexist with Espressif’s system services.
* **Verified Quality:** Validated using the **ACATS** (Ada Conformity Assessment Test Suite) to ensure language compliance on both supported architectures.

---

## Runtime limitations and implementation details

The following describes the experimental **embedded backend on ESP32-S3**
(`runtime-embedded-esp32s3.json`), validated with ESP-IDF 6.1. Its validation
results do not establish the same behavior on other SoCs or runtime backends.

### Interrupts

* **Only hardware interrupt levels 1–3 support Ada handlers and callbacks.**
  These are the C-callable Xtensa levels supported by ESP-IDF. The three Ada
  `System.Interrupt_Priority` values map to levels 1–3; the default interrupt
  priority selects level 3. Levels 4–7, including NMI, require assembly handlers
  and are outside this backend's Ada interrupt support.
* **Nested interrupts and direct calls from ESP-IDF ISR callbacks are supported.**
  No Ada-specific entry adapter or prior registration of the interrupted FreeRTOS
  task is required. ISR code must use nonblocking, ISR-compatible operations.
* **Interrupt contexts have separate exception state.** Six static ISR ATCBs
  provide three nesting contexts per CPU. Each CPU owns one secondary stack
  obtained from the binder pool during initialization. Nested handlers share
  that CPU's stack in LIFO order, independently of the interrupted task.
  Stack capacity must cover all live allocations across nested handlers.
  ISR entry does not read the interrupted task's FreeRTOS TLS.
* **Exceptions must remain inside the callback boundary.** The runtime contains
  exceptions escaping protected `Attach_Handler` handlers. Ordinary callbacks
  exported to C must catch escaping exceptions before returning to ESP-IDF.
* **Cache-disabled/IRAM execution is unvalidated.** Interrupt allocation omits
  `ESP_INTR_FLAG_IRAM`; the runtime and exception paths have not been audited for
  cache-safe execution. No worst-case interrupt latency is guaranteed.
* **ISR exception handling requires the unwinder integration.** Applications using
  this backend must include `cmake/embedded-unwind.cmake`, as the stage4 harness
  does. It adapts the selected SDK unwinder's blocking mutex references in a
  build-local object; revalidation is required when changing the toolchain.

### Scheduling and time

* FreeRTOS scheduling does not fully implement Ada `FIFO_Within_Priorities`.
  Equal-priority tasks can time-slice; full Jorvik scheduling conformance is not
  claimed. Protected-object exclusion uses explicit locks.
* `Ada.Real_Time.Clock` is monotonic and boot-relative; `Ada.Calendar.Clock` uses
  ESP-IDF wall time, which the application/SDK must initialize or synchronize.
  Microsecond clock units do not imply microsecond wakeups: delays use FreeRTOS
  ticks (10 ms in the validated configuration), plus scheduling latency.

See [stage4 documentation](tests/stage4/README.md) and
[validation results](tests/stage4/FINAL-RESULTS.md) for tested scope and
configuration requirements.

---

## Required ESP-IDF configuration

This section applies to the **ESP32-S3 embedded backend with the installed
ESP-IDF 6.1 GCC toolchain**. Defaults below are taken from that SDK's Kconfig
sources; they can change between releases. The default Picolibc choice described
below does not apply to the Clang toolchain.

Configure the application with `idf.py menuconfig`, or record settings in its
`sdkconfig.defaults`. ESP-IDF writes the effective configuration to `sdkconfig`.
Defaults files supply values for settings not already present in `sdkconfig`;
editing a defaults file does not override an existing configured value. Build
through `idf.py build`, which invokes the integrated Alire build.

### Required selections and ABI compatibility

| Setting | Required/current value | ESP-IDF 6.1 default | Reason |
| --- | --- | --- | --- |
| `CONFIG_COMPILER_CXX_EXCEPTIONS` | `y` | `n` — **change required** | Enables SDK startup registration of `.eh_frame` and retains the unwinder needed for Ada exception propagation, even in applications with no C++ code. |
| `CONFIG_LIBC_NEWLIB` | `y` | Picolibc with GCC — **change required** | The current runtime ABI and static FreeRTOS storage sizes are validated with Newlib; Picolibc is not validated. Select Newlib in the LibC choice. |
| `CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS` | `2` | `1` — **change required** | ATCB uses FreeRTOS TLS pointer slot 1; slot 0 is reserved by ESP-IDF for pthread TLS. The current static task storage ABI requires exactly two slots. |
| `CONFIG_FREERTOS_HZ` | `100` | `100` — unchanged | Must match `System.OS_Constants.configTICK_RATE_HZ`; the C bridge checks it at compile time. |
| `CONFIG_FREERTOS_UNICORE` | disabled | disabled on ESP32-S3 — unchanged | The current descriptor and tests use both CPUs; a single-core configuration requires a matching runtime configuration and separate validation. |

Menu locations: **Compiler options → Enable C++ exceptions**, **Component config
→ LibC → LibC to build application with**, and **Component config → FreeRTOS →
Kernel** for the tick rate, single-core selection and
**configNUM_THREAD_LOCAL_STORAGE_POINTERS**. Increase the latter from 1 to 2.
Set the target with
`idf.py set-target esp32s3` when creating/configuring an ESP32-S3 project.

The backend embeds opaque SDK structures in Ada-owned storage. The current
`System.OS_Constants` expects `StaticTask_t` = 348 bytes, `StaticSemaphore_t` =
84 bytes and `portMUX_TYPE` = 8 bytes, all aligned to 4 bytes. `embedded.c` has
static assertions for these sizes/alignments and for the SDK's fixed
`configMAX_PRIORITIES = 25`. A configuration or SDK change that trips an assertion
requires checking the ABI, updating the Ada constants and matching C checks,
and rebuilding/revalidating the runtime; increasing the buffers blindly is not
sufficient.

With `CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS=2`, the extra pointer and
its deletion callback increase `StaticTask_t` from 340 to 348 bytes. More slots
require another ABI update. The Ada ATCB accessors call
`pvTaskGetThreadLocalStoragePointer` / `vTaskSetThreadLocalStoragePointer` with
a null task handle (the current task) and index 1. Access uses preallocated task
storage; the accessors themselves do not allocate. First foreign-thread
attachment allocates an ATCB as described below; no deletion callback is installed.

Other relevant structure-layout settings currently use their SDK defaults:
`CONFIG_FREERTOS_TLSP_DELETION_CALLBACKS=y`,
`CONFIG_FREERTOS_MAX_TASK_NAME_LEN=16`,
`CONFIG_FREERTOS_TASK_NOTIFICATION_ARRAY_ENTRIES=1`,
`CONFIG_FREERTOS_USE_TRACE_FACILITY=n`, and
`CONFIG_FREERTOS_USE_APPLICATION_TASK_TAG=n`. These are ABI inputs, not a
requirement for the runtime to use those features.
Static allocation, mutexes and recursive mutexes are enabled by this SDK's
`FreeRTOSConfig.h`; no additional menuconfig switch is needed for them.

### Stack sizes and test-project choices

| Setting | Validated value | ESP-IDF 6.1 default | Scope |
| --- | --- | --- | --- |
| `CONFIG_ESP_MAIN_TASK_STACK_SIZE` | `16384` bytes | `3584` bytes — increased | Retained test startup stack budget. The SDK default has not been revalidated after removal of the temporary 4 KiB ISR secondary-stack initialization object. |
| `CONFIG_FREERTOS_ISR_STACKSIZE` | `8192` bytes **per CPU** | `1536` bytes (2096 with core dumps enabled) — increased | Tested with nested levels 1–3, live secondary-stack data and exception handling. Smaller sizes are unvalidated. This primary ISR stack is separate from the shared Ada secondary stack. |
| `CONFIG_ESP_TASK_WDT_EN` | disabled in tests | `y` — test-only change | The stress harness disables the task watchdog. Runtime use does not require disabling it; configure watchdog monitoring/timeouts for the application's task behavior. |
| `CONFIG_ESPTOOLPY_FLASHSIZE_16MB` | selected in tests | Board/configuration dependent | Describes the test board's flash. Use the actual device size; 16 MiB is not a runtime requirement. |

The validated stack sizes are tested budgets, not proven minimums or universal
bounds. Account for application code and nesting, and size Ada-created task
stacks separately with Ada task storage settings. If Ada startup runs in a task
other than `app_main`, that task needs the initialization stack budget instead.

For an ESP32-S3 project, the required non-default selections and validated stack
budgets can be recorded as:

```ini
CONFIG_COMPILER_CXX_EXCEPTIONS=y
CONFIG_LIBC_NEWLIB=y
CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS=2
CONFIG_ESP_MAIN_TASK_STACK_SIZE=16384
CONFIG_FREERTOS_ISR_STACKSIZE=8192
```

See the [test project's defaults](tests/stage1/sdkconfig.defaults) for the complete
harness configuration. Including `cmake/embedded-unwind.cmake` for ISR exception
support is an additional build integration requirement; menuconfig alone does
not provide that adaptation.

### Binder secondary-stack pool

The embedded backend requires **one additional default-sized secondary stack
per CPU for interrupt handlers**: two on the supported dual-core ESP32-S3.
Each foreign thread that is given an Ada secondary stack also needs one
additional pool entry. These contexts are not compiler-declared Ada tasks, so
the compiler/binder does not count them automatically. Set `-Qnnn` to **one
for the environment task, plus the number of CPUs, plus the number of additional
foreign threads requiring a pool-backed secondary stack, plus any other manual
pool consumers**. A C thread that only gets
interrupted does not need its own Ada stack: its handlers use the CPU's stack.
`-Q3` is the example for two CPUs and no additional foreign-thread consumers.
If `-Q` already reserves stacks for foreign threads or other consumers,
increase its existing count by the number of CPUs instead.
For example, in the application's GPR file:

```ada
package Binder is
   for Switches ("Ada") use ("-D4k", "-Q3");
end Binder;
```

Preserve any other application binder switches. In the installed GNAT 16 binder,
`-Qnnn` sets the initial pool count, replacing the implicit count of one for the
environment task; the binder then adds the stacks counted for ordinary Ada
tasks. Thus `-Q2` would leave the dual-core configuration one stack short.
This behavior is implemented in `Gen_Output_File` in
[GCC's bindgen.adb](https://github.com/gcc-mirror/gcc/blob/master/gcc/ada/bindgen.adb)
and confirmed by the generated binder file and the harness run.
`-D4k` sets the default secondary-stack size to
4096 bytes for both pool-backed tasks and interrupt contexts. Size this budget
for the maximum live allocations across nested handlers on one CPU; the two
CPUs use different stacks. The runtime obtains the stacks with `SS_Init` before
Ada interrupt attachment and keeps them for the lifetime of the application.
They are not reset on ISR entry.

This light-tasking/embedded `SS_Init` does not fall back to the heap: exhaustion
of a nonempty pool raises `Program_Error`. With no binder pool it leaves the
pointer null; this is outside the supported configuration, which requires the
nonempty pool described above.
The existing compiler/binder accounting for ordinary Ada tasks is unchanged;
tasks with explicit `Secondary_Stack_Size` use compiler-provided storage.

### Threads created outside Ada

After Ada partition initialization/elaboration has completed, a FreeRTOS task
created by C or ESP-IDF can call Ada without an application registration call.
The first runtime request for task context (including exception or secondary-stack
use) attaches a dynamically allocated full ATCB and its statically backed CV to
TLS slot 1. It does not create a native task or run Ada task activation. Later
calls on that native task reuse the same ATCB. A temporary primary-stack ATCB
protects allocator/error handling from recursive attachment during bootstrap.
Registration supplies a startup token and calls `Enter_Task`, sharing TLS/Lwp,
debug-list and native-priority setup with ordinary Ada tasks.

Secondary stacks **always come from the binder pool**, never the heap. For F
foreign attachments on two CPUs, reserve `-Q(3+F)`, plus any other manual pool
consumers; four foreign threads therefore use `-Q7`. This is a budget for total
attachments over application lifetime, not just simultaneously live threads.
ISR entry remains independent: it uses the existing ISR ATCB and CPU-owned stack
without attaching the interrupted native task.

The runtime captures the observed native priority at attachment and restores it
after protected actions, including native priority 0. Task priorities map
one-to-one between FreeRTOS and Ada. Independent C-side priority changes or
native priority inheritance are not tracked by the Ada priority metadata.
Primary native stack size is not discovered; the ATCB reports it as unknown (0).
Validate native callback stack budgets for their Ada workload; the stage5 tests
use 12 KiB native stacks and 4 KiB secondary stacks.

Foreign threads are expected to be long-lived. There is no reaper, polling or
termination hook. If a native task is deleted, its ATCB, CV and binder stack are
retained until application shutdown; do not rely on Ada termination reporting
or use its old task identity/handle after external deletion. Delete native tasks
only after returning from Ada with no owned Ada locks or queued calls.

First-attachment allocation/pool failure immediately calls
`System.Machine_Reset.Stop` (`__gnat_stop`), which reaches ESP-IDF `abort`
through `_exit`, without resource or TLS cleanup.
It is a fail-stop initialization error, not a recoverable exception returned to
an unregistered caller. Binder storage is never freed or recycled. These policies
avoid lifecycle tracking costs and common bb-runtime changes.
See [stage5 results](tests/stage5/RESULTS.md) for coverage and failure checks.

---

## Requirements

This project is managed exclusively via **Alire**. To use this runtime, you must have the following:

1.  **[Alire](https://alire.ada.dev/):** The Ada Package Manager.
2.  **ESP-IDF SDK:** Installed and configured in your environment path.
3.  **GNAT Cross-Compiler:** Handled via Alire dependencies (specifically `xtensa-esp32-elf` or `riscv64-elf`).

---

## Getting Started

Because this runtime requires specific toolchain, linker, and build system configurations, projects **must** be initialized using one of the following validated methods:

### 1. Using SoC-Specific Templates
The most straightforward way to start is to clone the template corresponding to your target hardware:
* **For ESP32 (Xtensa, LX6):** [esp32_template](https://github.com/RREE/esp32_template)
* **For ESP32-C3 (RISC-V):** [esp32c3_template](https://github.com/godunko/esp32c3_template)
* **For ESP32-S3 (Xtensa, LX7):** [esp32s3_template](https://github.com/godunko/esp32s3_template)

### 2. Using the Agent Skill
If you are using an AI-assisted workflow, you can generate a complete project skeleton using the specialized agent skill:
* **Skill:** [ada-espidf-skeleton](https://github.com/godunko/ada_espidf_skills/tree/main/ada-espidf-skeleton)

---

## License

This project is licensed under the **GPL-3.0** or later with **GCC-exception-3.1** — see the [LICENSE](LICENSE) file for details.
