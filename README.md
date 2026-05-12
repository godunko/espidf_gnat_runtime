# ESP-IDF GNAT Runtime

[![ACATS](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml/badge.svg)](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml)
[![Alire](https://img.shields.io/badge/Alire-Crate-blue)](https://alire.ada.dev)
[![License](https://img.shields.io/badge/License-Apache%202.0-red.svg)](https://opensource.org/licenses/Apache-2.0)

The **`espidf_gnat_runtime`** provides the GNAT runtime support libraries required to develop **Ada** and **SPARK** applications for Espressif SoCs. It serves as the foundational layer enabling the GNAT compiler to target Espressif’s hardware, bridging Ada language features with the underlying system.

## Supported Architectures

* **Xtensa:** Full support for the **ESP32-S3** series.
* **RISC-V:** Full support for the **ESP32-C3** series.

## Key Features

* **Ada Language Support:** Implementation of essential features, including exception handling, controlled types, and secondary stacks.
* **Standard Library:** Support for a rich set of standard packages, including `Ada.Numerics`, `Ada.Strings`, `Ada.Containers`, and more.
* **Real-Time Concurrency:** Support for the **Jorvik profile**, enabling safe, deterministic Ada tasks and protected objects.
* **Hardware Interoperability:** Support for applications running alongside the **ESP-IDF** environment, allowing Ada code to coexist with Espressif’s system services.
* **Verified Quality:** Validated using the **ACATS** (Ada Conformity Assessment Test Suite) to ensure language compliance on both supported architectures.

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
* **For ESP32-C3 (RISC-V):** [esp32c3_template](https://github.com/godunko/esp32c3_template)
* **For ESP32-S3 (Xtensa):** [esp32s3_template](https://github.com/godunko/esp32s3_template)

### 2. Using the Agent Skill
If you are using an AI-assisted workflow, you can generate a complete project skeleton using the specialized agent skill:
* **Skill:** [ada-espidf-skeleton](https://github.com/godunko/ada_espidf_skills/tree/main/ada-espidf-skeleton)

---

## License

This project is licensed under the **Apache License 2.0** with Runtime Exception — see the [LICENSE](LICENSE) file for details.
