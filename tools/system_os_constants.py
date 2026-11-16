#!/usr/bin/env python3
"""Extract target C constants using SDK nm without executing target code."""

import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nm", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("objects", nargs="+")
    args = parser.parse_args()
    symbols = subprocess.check_output(
        [args.nm, "-S", "--radix=d", "--defined-only", *args.objects], text=True
    )
    constants = {}
    for line in symbols.splitlines():
        fields = line.split()
        if len(fields) == 4 and fields[3].startswith("gnat_system_os_constants_"):
            name = fields[3].removeprefix("gnat_system_os_constants_")
            if name in constants:
                raise ValueError(f"Duplicate constant: {name}")
            constants[name] = int(fields[1], 10) - 1

    names = (
        "configMAX_PRIORITIES", "configTICK_RATE_HZ",
        "portMUX_TYPE_Size", "portMUX_TYPE_Alignment",
        "StaticTask_t_Size", "StaticTask_t_Alignment",
        "StaticSemaphore_t_Size", "StaticSemaphore_t_Alignment", "ATCB_Slot",
    )
    if set(constants) != set(names):
        raise ValueError(f"Unexpected constants extracted: {sorted(constants)}")
    content = (
        "--\n"
        "--  Generated from ESP-IDF headers and sdkconfig. Do not edit.\n"
        "--\n"
        "--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1\n"
        "--\n\n"
        "package System.OS_Constants is\n\n   pragma Pure;\n\n"
        + "".join(f"   {name:<27} : constant := {constants[name]};\n" for name in names)
        + "\nend System.OS_Constants;\n"
    )
    # Avoid rebuilding Ada when the resulting constants have not changed.
    if not args.output.exists() or args.output.read_text() != content:
        temporary = args.output.with_suffix(".ads.tmp")
        temporary.write_text(content)
        temporary.replace(args.output)


if __name__ == "__main__":
    main()
