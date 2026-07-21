#!/usr/bin/env python3
"""Create a sanitized, user-facing Persian build failure report."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

RULES = [
    ("android_signing", [r"Missing android/key\.properties", r"keystore.*not found", r"signingConfig", r"Keystore was tampered"],
     "خطای امضای Android", "اطلاعات یا فایل امضای Release پروژه ناقص یا نامعتبر است.",
     "برای خروجی آزمایشی، بیلدینو از امضای fallback استفاده می‌کند. برای انتشار یا آپدیت اپ، Keystore اصلی همان برنامه لازم است."),
    ("java_gradle", [r"Unsupported class file major version", r"invalid source release", r"requires Java", r"JVM target compatibility"],
     "ناسازگاری Java و Gradle", "نسخه Java موردنیاز پروژه با Gradle، AGP یا Kotlin هماهنگ نیست.",
     "نسخه Java، Gradle Wrapper، Android Gradle Plugin و Kotlin را با هم هماهنگ کنید."),
    ("dependency_network", [r"Could not resolve", r"Could not GET", r"Could not HEAD", r"UnknownHostException", r"Read timed out", r"Connection reset"],
     "دریافت Dependency یا شبکه", "Gradle یا Pub نتوانسته یکی از وابستگی‌ها را از مخزن دریافت کند.",
     "آدرس Repository و نسخه Dependency را بررسی کنید؛ خطاهای موقت شبکه را دوباره اجرا کنید."),
    ("pub_get", [r"version solving failed", r"Because .* depends on", r"pub get failed", r"doesn't match any versions"],
     "تعارض Dependencyهای Flutter", "حل نسخه‌های pubspec ناموفق است یا یک Package با SDK سازگار نیست.",
     "محدوده نسخه Packageها، sdk constraint و dependency_overrides را بررسی کنید."),
    ("dart_compile", [r"Error: .*\.dart:", r"Target kernel_snapshot_program failed", r"Compilation failed", r"The getter .* isn't defined"],
     "خطای کدنویسی Dart/Flutter", "کامپایل سورس Dart به‌دلیل خطای نحوی، نوع داده یا API نامعتبر متوقف شده است.",
     "اولین خطای Dart را اصلاح کنید؛ خطاهای بعدی معمولاً پیامد همان خطای اول هستند."),
    ("manifest", [r"Manifest merger failed", r"uses-sdk:minSdkVersion", r"android:exported"],
     "خطای AndroidManifest", "Manifest اصلی یا Manifest یکی از Pluginها با تنظیمات پروژه تعارض دارد.",
     "گزارش Manifest merger را بررسی و minSdk، exported، permission یا placeholder متعارض را اصلاح کنید."),
    ("sdk_ndk", [r"NDK.*not found", r"failed to find target with hash", r"compileSdk", r"platforms;android", r"CMake"],
     "Android SDK/NDK", "نسخه SDK، Build Tools، NDK یا CMake موردنیاز پروژه نصب یا سازگار نیست.",
     "نسخه‌های compileSdk، ndkVersion و CMake را با محیط Build هماهنگ کنید."),
    ("kotlin", [r"Kotlin compilation error", r"e: file://", r"Compilation error\. See log", r"Inconsistent JVM-target"],
     "خطای Kotlin", "کامپایل کد Kotlin یا Plugin اندرویدی ناموفق شده است.",
     "اولین پیام e: را بررسی و نسخه Kotlin/JVM target یا کد Plugin را اصلاح کنید."),
    ("resource", [r"Android resource linking failed", r"resource .* not found", r"AAPT2"],
     "خطای Resource اندروید", "یک Resource، Theme، Attribute یا فایل XML نامعتبر یا مفقود است.",
     "اولین فایل و شماره خط گزارش‌شده توسط AAPT2 را اصلاح کنید."),
    ("disk_memory", [r"No space left on device", r"Java heap space", r"OutOfMemoryError", r"Killed"],
     "کمبود منابع Runner", "فضای دیسک یا حافظه Runner برای این Build کافی نبوده است.",
     "Cacheها و خروجی‌های اضافی را حذف یا مصرف حافظه Gradle را کاهش دهید؛ این خطا سهمیه کاربر را مصرف نمی‌کند."),
]

SECRET_PATTERNS = [
    re.compile(r"(?i)(storePassword|keyPassword|password|token|secret|api[_-]?key)\s*[=:]\s*\S+"),
    re.compile(r"gh[oprsu]_[A-Za-z0-9_]{20,}"),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
]


def sanitize(line: str) -> str:
    result = line.strip().replace("\x1b", "")
    for pattern in SECRET_PATTERNS:
        result = pattern.sub(lambda m: m.group(0).split(m.group(1), 1)[0] + m.group(1) + "=<redacted>" if m.lastindex else "<redacted>", result)
    result = re.sub(r"/home/runner/work/[^/]+/[^/]+/work/project/", "<project>/", result)
    return result[:600]


def select_excerpt(lines: list[str]) -> list[str]:
    markers = ("FAILURE:", "* What went wrong:", "Error:", "Exception", "BUILD FAILED", "e: file://")
    indices = [i for i, line in enumerate(lines) if any(marker.lower() in line.lower() for marker in markers)]
    start = indices[0] if indices else max(0, len(lines) - 30)
    candidates = lines[start:start + 26]
    cleaned = [sanitize(line) for line in candidates if sanitize(line)]
    return cleaned[:18]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", required=True)
    parser.add_argument("--code", type=int, required=True)
    parser.add_argument("--log", action="append", default=[])
    parser.add_argument("--preflight")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    text_parts = []
    for value in args.log:
        path = Path(value)
        if path.is_file():
            text_parts.append(path.read_text(encoding="utf-8", errors="replace"))
    text = "\n".join(text_parts)
    category = "unknown"
    title = "خطای نامشخص Build"
    cause = "فرآیند Build متوقف شد اما الگوی خطا هنوز در دسته‌بندی‌های شناخته‌شده ثبت نشده است."
    solution = "جزئیات فنی زیر و Workflow Run را بررسی کنید؛ برای توسعه موتور تشخیص، همین گزارش کافی است."
    for rule_category, patterns, rule_title, rule_cause, rule_solution in RULES:
        if any(re.search(pattern, text, re.I | re.M) for pattern in patterns):
            category, title, cause, solution = rule_category, rule_title, rule_cause, rule_solution
            break
    preflight = {}
    if args.preflight and Path(args.preflight).is_file():
        preflight = json.loads(Path(args.preflight).read_text(encoding="utf-8"))
    excerpt = select_excerpt(text.splitlines())
    report = {
        "category": category,
        "title": title,
        "stage": args.stage,
        "exit_code": args.code,
        "cause": cause,
        "solution": solution,
        "technical_excerpt": excerpt,
        "java_version": preflight.get("java_version"),
        "gradle_version": preflight.get("gradle_version"),
        "flavors": preflight.get("flavors", []),
        "fallback_signing_used": bool(preflight.get("fallback_signing_used", False)),
        "signing_reason": preflight.get("signing_reason"),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
