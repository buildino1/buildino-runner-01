# Buildino Public Runner Template v0.7.0

این Repository عمومی توسط GitHub App رسمی Buildino مدیریت می‌شود و برای Buildهای ایزوله Android استفاده می‌شود.

## Frameworkهای پشتیبانی‌شده

- Flutter → APK / AAB
- React Native CLI و Expo سازگار با prebuild → APK / AAB
- Python Android: Buildozer/python-for-android، BeeWare Briefcase و Chaquopy → APK / AAB

پروژه‌های Python عمومی مانند Django، Flask، FastAPI، ربات‌ها، اسکریپت‌های معمولی و برنامه‌های دسکتاپ پذیرفته نمی‌شوند.

## موتور Multi-Framework Android

- تشخیص خودکار نوع پروژه و ریشه واقعی در ZIPهای تو‌در‌تو.
- انتخاب خودکار Flutter، Node.js، Python، Java، Gradle، Android SDK و NDK.
- npm، Yarn و pnpm برای React Native با Retry محدود خطاهای شبکه.
- ساخت Android برای Expo فقط در صورت وجود تنظیمات معتبر Expo.
- Buildozer/python-for-android، Briefcase Android و Gradle/Chaquopy برای Python Android.
- امضای اصلی پروژه یا fallback پایدار بیلدینو در Job ایزوله انتشار.
- گزارش فارسی شامل Framework، مرحله شکست، ابزارها، علت، راه‌حل و خلاصه فنی.
- حفظ کامل موتور Universal Adaptive Flutter نسخه 0.6.0.

## امنیت

- ZIP، Path Traversal، Symlink، ZIP Bomb و فایل رمزگذاری‌شده بررسی می‌شوند.
- سورس به Secretهای Worker یا Keystore پایدار دسترسی ندارد.
- Keystore fallback فقط در Job انتشار دریافت و پس از امضا حذف می‌شود.
- Workspace بعد از Build پاک می‌شود.
- Retry و زمان Build محدود است.

## فایل‌های فعال

```text
.github/workflows/buildino-runner-wf10.yml
.github/workflows/buildino-cleanup-wf7.yml
scripts/run_android_build.sh
scripts/run_flutter_build.sh
scripts/run_react_native_build.sh
scripts/run_python_android_build.sh
scripts/find_android_project.py
```
