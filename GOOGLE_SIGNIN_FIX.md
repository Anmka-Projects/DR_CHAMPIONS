# إصلاح مشكلة تسجيل الدخول عبر Google

## المشكلة
عند محاولة تسجيل الدخول عبر Google، يظهر الخطأ:
```
PlatformException(sign_in_failed, com.google.android.gms.common.api.Api10:, null, null)
```

## السبب
الملف `android/app/google-services.json` يحتوي على مصفوفة `oauth_client` فارغة. هذا يعني أن OAuth Client IDs غير مُعدة في Firebase Console، وهي ضرورية لتسجيل الدخول عبر Google على Android.

## الحل

### الخطوة 1: تفعيل Google Sign-In في Firebase Console

1. افتح [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `anmka-stp`
3. اذهب إلى **Authentication** → **Sign-in method**
4. اضغط على **Google**
5. فعّل **Enable** واحفظ

### الخطوة 2: إضافة OAuth Client ID للـ Android App

1. في Firebase Console، اذهب إلى **Project Settings** (⚙️ → Project settings)
2. افتح تبويب **Your apps**
3. اختر تطبيق Android الخاص بك (`com.anmka.stpnew`)
4. تأكد من أن:
   - **Package name**: `com.anmka.stpnew` (يجب أن يطابق `applicationId` في `android/app/build.gradle`)
   - **SHA-1 certificate fingerprint**: موجود ومحدث

### الخطوة 3: إضافة SHA-1 Fingerprint (إن لم يكن موجوداً)

1. افتح Terminal/Command Prompt
2. اذهب إلى مجلد المشروع: `cd android`
3. شغّل الأمر:
   ```bash
   ./gradlew signingReport
   ```
   (على Windows: `gradlew.bat signingReport`)
4. انسخ SHA-1 و SHA-256 من النتيجة
5. في Firebase Console → Project Settings → Your apps → Android app
6. اضغط **Add fingerprint** وأضف SHA-1 و SHA-256
7. احفظ التغييرات

### الخطوة 4: تحميل ملف google-services.json المحدث

1. في Firebase Console → Project Settings → Your apps
2. اضغط على **Download google-services.json**
3. استبدل الملف القديم في `android/app/google-services.json` بالملف الجديد
4. تأكد من أن الملف الجديد يحتوي على `oauth_client` مع بيانات OAuth Client IDs:

```json
{
  "project_info": { ... },
  "client": [
    {
      "client_info": { ... },
      "oauth_client": [
        {
          "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
          "client_type": 3
        },
        {
          "client_id": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
          "client_type": 1
        }
      ],
      ...
    }
  ]
}
```

### الخطوة 5: تنظيف وإعادة بناء المشروع

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

## التحقق من الحل

بعد تطبيق الخطوات أعلاه:

1. تأكد من أن `google-services.json` يحتوي على `oauth_client` غير فارغة
2. تأكد من تطابق `package_name` في `google-services.json` مع `applicationId` في `build.gradle`
3. جرّب تسجيل الدخول عبر Google مرة أخرى

## ملاحظات إضافية

- إذا كان التطبيق يستخدم **signing config** للإنتاج، تأكد من إضافة SHA-1 للإنتاج أيضاً
- قد تحتاج إلى الانتظار بضع دقائق بعد تحديث Firebase Console حتى تتأثر التغييرات
- تأكد من أن Google Play Services مثبتة ومحدثة على الجهاز

