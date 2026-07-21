#!/usr/bin/env python3
"""Safely extract a previously validated source ZIP."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
import zipfile
from pathlib import Path

from validate_zip import ZipValidationError, normalized_member, validate_zip


def extract_safely(archive_path: Path, destination: Path) -> None:
    validate_zip(archive_path)
    destination.mkdir(parents=True, exist_ok=True)
    destination_root = destination.resolve()

    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            relative = normalized_member(info.filename)
            target = (destination / Path(*relative.parts)).resolve()
            if destination_root not in target.parents and target != destination_root:
                raise ZipValidationError(f"Unsafe extraction destination: {info.filename}")

            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue

            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info, "r") as source, target.open("wb") as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)

            mode = info.external_attr >> 16
            if mode:
                safe_mode = stat.S_IMODE(mode) & 0o777
                safe_mode &= ~0o6000
                os.chmod(target, safe_mode or 0o644)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        extract_safely(args.archive, args.destination)
    except (ZipValidationError, zipfile.BadZipFile, OSError) as exc:
        print(f"Source extraction failed: {exc}", file=sys.stderr)
        return 2
    print(args.destination.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
