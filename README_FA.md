# Buildino Public Runner Template v0.10.0

این Repository عمومی توسط GitHub App رسمی Buildino مدیریت می‌شود و برای Buildهای ایزوله Android استفاده می‌شود.

## Frameworkهای پشتیبانی‌شده

- Flutter → APK / AAB
- Native Android Java/Kotlin با Gradle → APK / AAB
- React Native CLI و Expo سازگار با prebuild → APK / AAB
- Python Android: Buildozer/python-for-android، BeeWare Briefcase و Chaquopy → APK / AAB

## موتور Native Android

- تشخیص `settings.gradle` و `settings.gradle.kts` در ZIPهای تو‌در‌تو.
- تشخیص ماژول دارای `com.android.application` بدون وابستگی به نام `app`.
- پشتیبانی از `build.gradle` و `build.gradle.kts`.
- اجرای `assembleRelease`، `bundleRelease` و Taskهای ماژول انتخاب‌شده.
- انتخاب Java براساس Gradle و AGP.
- استفاده از Gradle Wrapper و fallback موقت در صورت نبود Wrapper.
- جمع‌آوری تمام خروجی‌های Release و امضای آن‌ها در Job ایزوله انتشار.

## سایر قابلیت‌ها

- تشخیص خودکار نوع پروژه و ریشه واقعی.
- Retry محدود خطاهای موقت شبکه.
- گزارش فارسی شامل Framework، مرحله شکست، Java، Gradle، AGP، علت و راه‌حل.
- Symbolic Linkهای پروژه تا حد ممکن به فایل عادی تبدیل می‌شوند.

## فایل‌های فعال

```text
.github/workflows/buildino-runner-wf14.yml
.github/workflows/buildino-cleanup-wf11.yml
scripts/run_android_build.sh
scripts/run_native_android_build.sh
scripts/native_android_preflight.py
scripts/run_flutter_build.sh
scripts/run_react_native_build.sh
scripts/run_python_android_build.sh
scripts/find_android_project.py
```
