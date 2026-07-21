#!/usr/bin/env python3
"""Locate the shallowest Flutter project in an extracted source tree."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

IGNORED_DIRS = {".git", ".dart_tool", "build", "node_modules", ".gradle"}


def is_flutter_pubspec(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return "sdk: flutter" in text or "sdk: 'flutter'" in text or 'sdk: "flutter"' in text


def find_projects(root: Path) -> list[Path]:
    candidates: list[Path] = []
    for pubspec in root.rglob("pubspec.yaml"):
        if any(part in IGNORED_DIRS for part in pubspec.parts):
            continue
        if is_flutter_pubspec(pubspec):
            candidates.append(pubspec.parent)
    return sorted(candidates, key=lambda p: (len(p.relative_to(root).parts), str(p)))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    projects = find_projects(args.root)
    if not projects:
        print("No Flutter project with a Flutter SDK dependency was found", file=sys.stderr)
        return 3
    print(projects[0].resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
