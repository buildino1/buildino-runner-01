# Buildino Public Runner Template v0.6.0

این Repository عمومی توسط GitHub App رسمی Buildino مدیریت می‌شود و برای Buildهای ایزوله Flutter استفاده می‌شود.

## موتور Universal Adaptive Build

- جست‌وجوی کامل ZIP و انتخاب ریشه پروژه با امتیازدهی، حتی در پوشه‌های تو‌در‌تو.
- پذیرش پروژه Flutter فاقد `android/` یا دارای Android ناقص.
- تولید خودکار پلتفرم Android با `flutter create` در Workspace موقت.
- شناسایی و ادغام Android Overlay از مسیرهای متداول و ساختارهای مشابه.
- تشخیص Java 8، 11، 17 یا 21، Gradle، SDK/NDK، Flavorها و Entry Pointهای main*.dart.
- نصب best-effort اجزای Android SDK موردنیاز پیش از Build.
- Retry محدود برای خطاهای موقت شبکه.
- Auto-Fix قطعی برای مهاجرت‌های رسمی Flutter Theme و خطاهای مشخص Android/Gradle مانند namespace، minSdk، compileSdk و exported.
- گزارش فارسی شامل ریشه انتخاب‌شده، نوع آماده‌سازی، تغییرات، اولین و آخرین خطا.
- امضای fallback پایدار فقط در Job ایزوله انتشار.

## مرزهای امنیتی

- ZIP اصلی کاربر تغییر نمی‌کند؛ تمام تغییرات فقط در Workspace موقت هستند.
- Keystore پایدار بیلدینو وارد Job اجرای سورس نمی‌شود.
- Path Traversal، Symlink، ZIP Bomb، فایل رمزگذاری‌شده، Timeout و Retry نامحدود مسدود می‌شوند.
- منطق برنامه، Package Name، Firebase و Secretهای پروژه بدون Diagnostic قطعی تغییر داده نمی‌شوند.
- خروجی‌ها حدود ۱۲ ساعت در Release عمومی موقت نگهداری می‌شوند.

## فایل‌های فعال

```text
.github/workflows/buildino-runner-wf9.yml
.github/workflows/buildino-cleanup-wf6.yml
scripts/find_flutter_project.py
scripts/prepare_source.py
scripts/prepare_flutter_platform.py
scripts/validate_zip.py
scripts/buildino_preflight.py
scripts/ensure_android_components.py
scripts/apply_flutter_compat_fixes.py
scripts/apply_adaptive_project_fixes.py
scripts/analyze_build_error.py
scripts/run_flutter_build.sh
README_FA.md
LICENSE
```
