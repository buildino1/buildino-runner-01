# Buildino Public Runner Template v0.4.0

این Repository عمومی توسط GitHub App رسمی Buildino مدیریت می‌شود و برای Buildهای آزمایشی Flutter استفاده می‌شود.

ساختار نصب‌شده:

```text
.github/workflows/buildino-runner-wf5.yml
.github/workflows/buildino-cleanup-wf2.yml
scripts/find_flutter_project.py
scripts/prepare_source.py
scripts/run_flutter_build.sh
scripts/validate_zip.py
README_FA.md
LICENSE
```

## اتصال به Buildino

1. GitHub App با نام `Buildino Runner Manager` روی حساب مالک Repository نصب شود.
2. هنگام نصب App، همین Repository در بخش `Only select repositories` انتخاب شود.
3. در پنل مدیریت تلگرام Buildino، لینک Repository ارسال شود.
4. Buildino نصب App را بررسی می‌کند، فایل‌های قالب را نصب یا به‌روزرسانی می‌کند و سلامت Workflowها را می‌سنجد.

برای Runner هیچ PAT، Secret یا رمز حساب لازم نیست. کنترل Repository از Installation Token کوتاه‌عمر GitHub App انجام می‌شود و ارتباط Workflow با Worker از GitHub Actions OIDC استفاده می‌کند.

## امنیت و نگهداری

- سورس پروژه در Commit، Release یا Actions Artifact قرار نمی‌گیرد.
- فقط خروجی نهایی APK/AAB در Release موقت عمومی منتشر می‌شود.
- Releaseها، Runهای تکمیل‌شده و Cacheهای موقت Buildino پس از حدود ۱۲ ساعت پاک می‌شوند.
- Repository باید Public، فعال و غیرآرشیوی باقی بماند.
