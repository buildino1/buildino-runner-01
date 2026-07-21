# Buildino Public Runner Template v0.5.0

این Repository عمومی توسط GitHub App رسمی Buildino مدیریت می‌شود و برای Buildهای ایزوله Flutter استفاده می‌شود.

ساختار نصب‌شده:

```text
.github/workflows/buildino-runner-wf7.yml
.github/workflows/buildino-cleanup-wf4.yml
scripts/find_flutter_project.py
scripts/prepare_source.py
scripts/validate_zip.py
scripts/buildino_preflight.py
scripts/analyze_build_error.py
scripts/run_flutter_build.sh
README_FA.md
LICENSE
```

## قابلیت‌های v0.5.0

- تشخیص Java 11، 17 یا 21 از تنظیمات واقعی Gradle/Kotlin.
- تشخیص Flavorهای Android و ساخت خروجی جدا برای هر Flavor.
- ساخت Keystore موقت فقط برای عبور امن Build پروژه‌های فاقد امضای معتبر.
- اعمال امضای پایدار fallback بیلدینو در Job جدا و پس از حذف سورس پروژه.
- گزارش خطای فارسی شامل دسته، مرحله، علت، راه‌حل و خلاصه فنی Sanitized.
- Workflow در شکست واقعی قرمز می‌شود، ولی نتیجه پیش از شکست به ربات ارسال می‌شود.

## امنیت

- سورس در Commit، Release یا Actions Artifact ذخیره نمی‌شود.
- Keystore پایدار بیلدینو هرگز وارد Job اجرای سورس نمی‌شود.
- Job Build فقط از Keystore موقت ۳۰روزه و تصادفی استفاده می‌کند.
- امضای پایدار در Job انتشار و بعد از حذف سورس انجام می‌شود.
- خروجی‌ها حدود ۱۲ ساعت در Release عمومی موقت نگهداری می‌شوند.
