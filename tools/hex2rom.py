#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROM_BASE = 0xFE000
ROM_SIZE = 0x2000


def build_rom(hex_path: Path, rom_path: Path) -> None:
    memory: dict[int, int] = {}
    base = 0
    start_segment = None
    start_offset = None

    for lineno, raw_line in enumerate(hex_path.read_text().splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        if not line.startswith(":"):
            raise ValueError(f"{hex_path}:{lineno}: missing ':'")
        payload = bytes.fromhex(line[1:])
        if len(payload) < 5:
            raise ValueError(f"{hex_path}:{lineno}: short record")
        count = payload[0]
        addr = (payload[1] << 8) | payload[2]
        rectype = payload[3]
        data = payload[4:-1]
        checksum = payload[-1]
        if ((sum(payload[:-1]) + checksum) & 0xFF) != 0:
            raise ValueError(f"{hex_path}:{lineno}: bad checksum")
        if len(data) != count:
            raise ValueError(f"{hex_path}:{lineno}: byte count mismatch")

        if rectype == 0x00:
            absolute = base + addr
            for i, value in enumerate(data):
                memory[absolute + i] = value
        elif rectype == 0x01:
            break
        elif rectype == 0x02:
            if count != 2:
                raise ValueError(f"{hex_path}:{lineno}: bad extended segment record")
            base = ((data[0] << 8) | data[1]) << 4
        elif rectype == 0x03:
            if count != 4:
                raise ValueError(f"{hex_path}:{lineno}: bad start segment record")
            start_segment = (data[0] << 8) | data[1]
            start_offset = (data[2] << 8) | data[3]
        else:
            raise ValueError(
                f"{hex_path}:{lineno}: unsupported record type {rectype:02X}"
            )

    if start_segment is None or start_offset is None:
        raise ValueError(f"{hex_path}: missing start-segment record")

    rom = bytearray([0xFF] * ROM_SIZE)
    for absolute, value in memory.items():
        if ROM_BASE <= absolute < ROM_BASE + ROM_SIZE:
            rom[absolute - ROM_BASE] = value

    rom_path.parent.mkdir(parents=True, exist_ok=True)
    rom_path.write_bytes(rom)
    print(f"ROM image saved to {rom_path}")
    print(f"Load base: 0x{ROM_BASE:05X}")
    print(
        f"Entry point: {start_segment:04X}:{start_offset:04X} (0x{((start_segment << 4) + start_offset):05X})"
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} <input.hex> <output.bin>", file=sys.stderr
        )
        raise SystemExit(2)
    build_rom(Path(sys.argv[1]), Path(sys.argv[2]))
