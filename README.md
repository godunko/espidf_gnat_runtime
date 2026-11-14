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
  provide three nesting contexts per CPU. Secondary stacks are shared with the
  interrupted Ada task; if it has no Ada secondary stack, nested handlers share
  one 4 KiB fallback stack per CPU. Stack capacity must cover all live allocations
  across the interrupted task and nested handlers.
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
[validation results](tests/stage4/RESTORED-ATCB-RESULTS.md) for tested scope and
configuration requirements.

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
