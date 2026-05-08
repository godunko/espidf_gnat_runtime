[![ACATS](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml/badge.svg)](https://github.com/godunko/espidf_gnat_runtime/actions/workflows/acats.yaml)

# ESP-IDF GNAT Runtime

This repository provides a GNAT Runtime Library (RTS) tailored for Ada development on the ESP32 family using the ESP-IDF (Espressif IoT Development Framework).

Unlike standard "Bare Board" runtimes, this RTS is designed to coexist with the ESP-IDF ecosystem, allowing developers to leverage Ada's safety features alongside Espressif's robust C-based SDK.

## Key Features

While many embedded runtimes are "Zero Footprint", this runtime provides a rich subset of the Ada Standard Library, including:

 * Native and Foreign Tasking: Ada tasks and protected objects are supported with restrictions of Jorvik profile.
   Ada code can be safely executed within multiple FreeRTOS tasks and across multiple CPU cores.
 * Exceptions: Full support for exception propagation and `Ada.Exceptions`.
 * Memory Management: Static secondary stack support and Controlled Objects (`Ada.Finalization`).
 * Standard Library: Includes `Ada.Containers.*`, `Ada.Strings.*`, `Ada.Numerics.*`, and more.
 * ISR Compatibility: Ada subprograms can be used as Interrupt Service Routine (ISR) callbacks (note: avoid RTS-locking features within ISRs).

## Supported Architectures

Currently tested for:
 * ESP32-C3 (RISC-V)
 * ESP32-S3 (Xtensa)

Note: There are no known technical blockers for other ESP32 variants.

## Prerequisites

Before using this runtime, ensure your environment is set up with:

 * ESP-IDF SDK: Installed and configured (including the export.sh or export.bat step).
 * Alire Package Manager: Required to manage the Ada toolchain and dependencies. Get Alire here.
 * GNAT Toolchain: An appropriate cross-compiler (`gnat_xtensa_esp32_elf` or `gnat_riscv64_elf`) usually managed automatically via Alire.

## Getting Started

The most efficient way to start is by using one of the project template:
 * [ESP32C3](https://github.com/godunko/esp32c3_template),
 * [ESP32S3](https://github.com/godunko/esp32s3_template),
which handles the complex boilerplate of linking Ada with the ESP-IDF build system (CMake).

Follow the instructions in the template repository to initialize the environment and flash your device using `idf.py`.

There is AI Agent Skills that can be used to create Ada/ESP-IDF project, see https://github.com/godunko/ada_espidf_skills

## Important Considerations

 * RTS Locks: Features requiring runtime locking (like controlled objects) should not be used within ISR contexts to prevent deadlocks or crashes.

## Contributing

Contributions to expand support for unsupported MCUs or to implement further standard library packages are welcome. Please feel free to open Issues or Pull Requests.
