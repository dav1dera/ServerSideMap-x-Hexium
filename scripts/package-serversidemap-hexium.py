#!/usr/bin/env python3
"""Build a Hexium-compatible ServerSideMap package ZIP."""

from __future__ import annotations

import binascii
import json
import re
import shutil
import struct
import zlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "scripts" / "build-serversidemap-1.0.sh"
BUILD_DIR = ROOT / "dist" / "build"
DIST = ROOT / "dist" / "hexium"
PACKAGE_NAME = "ServerSideMap_Valheim1Fix"
UPSTREAM_URL = "https://github.com/Mydayyy/Valheim-ServerSideMap"
SOURCE_URL = "https://github.com/dav1dera/ServerSideMap-x-Hexium"


def read_pin() -> tuple[str, str, str, int]:
    text = BUILD_SCRIPT.read_text(encoding="utf-8")
    upstream_version = re.search(r'^SSM_VERSION="([^"]+)"$', text, re.MULTILINE)
    package_version = re.search(r'^SSM_PACKAGE_VERSION="([^"]+)"$', text, re.MULTILINE)
    commit = re.search(r'^SSM_COMMIT="([0-9a-f]+)"$', text, re.MULTILINE)
    revision = re.search(r'^SSM_PACKAGE_REVISION="(\d+)"$', text, re.MULTILINE)
    if not upstream_version or not package_version or not commit or not revision:
        raise SystemExit("Could not read ServerSideMap upstream/package pin")
    return (
        upstream_version.group(1),
        package_version.group(1),
        commit.group(1),
        int(revision.group(1)),
    )


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", binascii.crc32(kind + data) & 0xFFFFFFFF)
    )


def make_icon(path: Path) -> None:
    width = height = 256
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            r, g, b, a = 42, 55, 48, 255
            if x % 32 in (0, 1) or y % 32 in (0, 1):
                r, g, b = 71, 87, 72
            dx = x - 128
            dy = y - 108
            radius2 = dx * dx + dy * dy
            if radius2 <= 38 * 38:
                r, g, b = 204, 148, 58
            if radius2 <= 16 * 16:
                r, g, b = 42, 55, 48
            if 108 <= y <= 184:
                half = max(0, (184 - y) // 2)
                if abs(x - 128) <= half and y >= 136:
                    r, g, b = 204, 148, 58
            row.extend((r, g, b, a))
        rows.append(bytes(row))

    raw = b"".join(rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(raw, 9))
    png += png_chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    upstream_version, package_version, commit, revision = read_pin()
    dll = BUILD_DIR / "ServerSideMap.dll"
    license_file = BUILD_DIR / "LICENSE-MIT"
    if not dll.is_file() or dll.stat().st_size == 0:
        raise SystemExit("ServerSideMap.dll is missing; run build-serversidemap-1.0.sh first")
    if not license_file.is_file():
        raise SystemExit("ServerSideMap MIT license is missing")

    package_dir = DIST / f"{PACKAGE_NAME}-{package_version}"
    zip_path = DIST / f"{PACKAGE_NAME}-{package_version}-hexium.zip"
    if package_dir.exists():
        shutil.rmtree(package_dir)
    DIST.mkdir(parents=True, exist_ok=True)
    package_dir.mkdir(parents=True)

    shutil.copy2(dll, package_dir / "ServerSideMap.dll")
    shutil.copy2(license_file, package_dir / "LICENSE-MIT")
    make_icon(package_dir / "icon.png")

    manifest = {
        "name": PACKAGE_NAME,
        "description": (
            "Unofficial Valheim 1.0 compatibility build of Mydayyy's ServerSideMap, "
            "compiled from unmodified upstream source. Install on server and client."
        ),
        "version_number": package_version,
        "website_url": SOURCE_URL,
        "dependencies": [],
    }
    (package_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    readme = f"""# ServerSideMap — Valheim 1.0 compatibility build

This is an unofficial compatibility build of Mydayyy's ServerSideMap for current Valheim 1.0.

- Automation/source: {SOURCE_URL}
- Original project: {UPSTREAM_URL}
- Upstream author: Mydayyy
- Upstream version: {upstream_version}
- Hexium package version: {package_version}
- Same-upstream revision: {revision}
- Upstream commit: `{commit}`
- License: MIT (included as `LICENSE-MIT`)

The ServerSideMap source is not modified. The DLL is compiled from the exact upstream
commit above against the current public Valheim dedicated-server assemblies.

Install the package on both the Valheim server and every modded client that connects to it.
For manual installation, place `ServerSideMap.dll` in `BepInEx/plugins` and restart.

Config file: `BepInEx/config/eu.mydayyy.plugins.serversidemap.cfg`
"""
    (package_dir / "README.md").write_text(readme, encoding="utf-8")

    changelog = f"""# Changelog

## {package_version}

- Upstream ServerSideMap version: {upstream_version}.
- Same-upstream revision: {revision}.
- Built from Mydayyy/Valheim-ServerSideMap commit `{commit}`.
- Compiled against the current public Valheim dedicated-server assemblies.
- No ServerSideMap source-code modifications.
- Packaged for Hexium/Gale installation.
"""
    (package_dir / "CHANGELOG.md").write_text(changelog, encoding="utf-8")

    if zip_path.exists():
        zip_path.unlink()
    with ZipFile(zip_path, "w", ZIP_DEFLATED) as zf:
        for file in sorted(package_dir.iterdir()):
            zf.write(file, file.name)

    required = {"manifest.json", "icon.png", "README.md", "ServerSideMap.dll", "LICENSE-MIT"}
    with ZipFile(zip_path) as zf:
        names = set(zf.namelist())
    missing = required - names
    if missing:
        raise SystemExit(f"Hexium package missing required files: {sorted(missing)}")

    print(f"Hexium package ready: {zip_path}")
    print(f"Upstream ServerSideMap version: {upstream_version}")
    print(f"Hexium package version: {package_version}")
    print(f"Same-upstream revision: {revision}")
    print(f"Upstream commit: {commit}")


if __name__ == "__main__":
    main()
