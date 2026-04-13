# دليل رفع تطبيق Dr Champions Academy على Google Play  
# Dr Champions Academy App - Google Play Upload Guide

دليل شامل لرفع تطبيق Dr Champions Academy التعليمي على متجر Google Play.

---

## المحتويات | Table of Contents

1. [المتطلبات | Prerequisites](#1-prerequisites)
2. [إعداد التوقيع | Signing Setup](#2-signing-setup)
3. [بناء التطبيق | Build the App](#3-build-the-app)
4. [حساب المطور | Developer Account](#4-developer-account)
5. [إنشاء التطبيق | Create the App](#5-create-the-app)
6. [قائمة المتجر | Store Listing](#6-store-listing)
7. [تصنيف المحتوى | Content Rating](#7-content-rating)
8. [سياسة الخصوصية | Privacy Policy](#8-privacy-policy)
9. [سلامة البيانات | Data Safety](#9-data-safety)
10. [التسعير والتوزيع | Pricing & Distribution](#10-pricing--distribution)
11. [رفع الملف | Upload the App](#11-upload-the-app)
12. [قائمة التحقق النهائية | Final Checklist](#12-final-checklist)

---

## 1. Prerequisites

### ما تحتاجه:
- حساب Google Play Developer ($25 مرة واحدة)
- تطبيق Flutter مكتمل ومختبر
- شهادة توقيع (keystore) للتطبيق
- عنوان بريد إلكتروني للدعم
- رابط سياسة الخصوصية
- شعار + لقطات شاشة

### Your app has:
- Package: `com.anmka.stpnew`
- Firebase configured
- Permissions: Camera, Storage, Internet, Notifications

---

## 2. Signing Setup

### 2.1 إنشاء Keystore (إذا لم يكن موجوداً)

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

احفظ **كلمة المرور** و **الـ alias** في مكان آمن. لا تفقدها أبداً.

### 2.2 ملف `key.properties`

يجب أن يكون في `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

⚠️ **لا تضف** `key.properties` إلى Git. تأكد أنه في `.gitignore`.

### 2.3 تكوين `android/app/build.gradle`

أضف في بداية الملف (بعد `plugins`):

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

ثم عدّل `buildTypes`:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.debug  // احذف هذا السطر
        // أضف:
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

والأفضل إضافة `signingConfigs` داخل `android { }`:

```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

**ملاحظة:** إذا كان `storeFile` مساراً نسبياً، ضعه في `android/app/` أو استخدم المسار الكامل.

---

## 3. Build the App

### 3.1 تحديث الإصدار

في `pubspec.yaml`:

```yaml
version: 1.0.0+1
#         ^     ^
#         |     versionCode (يجب أن يزيد مع كل رفع)
#         versionName (ما يراه المستخدم)
```

- عند كل رفع جديد: زد `versionCode` (الرقم بعد +) واختيارياً `versionName`.

### 3.2 بناء Android App Bundle (AAB) – مُوصى به

```bash
flutter clean
flutter pub get
flutter build appbundle
```

الملف الناتج: `build/app/outputs/bundle/release/app-release.aab`

### 3.3 (اختياري) بناء APK

```bash
flutter build apk --release
```

الملف: `build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Developer Account

1. ادخل إلى [Google Play Console](https://play.google.com/console)
2. سجّل الدخول بحساب Google
3. ادفع رسوم التسجيل ($25)
4. أكمل بيانات الملف الشخصي:
   - اسم المطور
   - البريد الإلكتروني
   - الموقع
   - تفاصيل الدفع (للتطبيقات المدفوعة فقط)

---

## 5. Create the App

1. من لوحة التحكم: **إنشاء تطبيق** | Create app
2. أدخل:
   - اسم التطبيق (مثلاً: Dr Champions Academy - منصة تعليمية)
   - اللغة الافتراضية
   - نوع التطبيق (تطبيق / لعبة)
   - هل هو مجاني أم مدفوع

---

## 6. Store Listing

### 6.1 المعلومات الأساسية

| الحقل | المطلوب | مثال |
|-------|---------|------|
| الاسم القصير | نعم (30 حرفاً) | Dr Champions Academy - تعليمي |
| الاسم الكامل | نعم (50 حرفاً) | Dr Champions Academy - منصة التعلم والتدريب |
| الوصف القصير | نعم (80 حرفاً) | تعلم وطور مهاراتك مع Dr Champions Academy |
| الوصف الكامل | نعم (4000 حرفاً) | وصف تفصيلي للتطبيق ومميزاته |

### 6.2 الرسومات

| العنصر | الحجم | ملاحظات |
|--------|-------|---------|
| أيقونة التطبيق | 512×512 px | PNG، 32-bit |
| لقطة شاشة (هاتف) | 320–3840 px (أصغر بعد ≥ 320) | جودة عالية |
| لقطة شاشة (تابلت) | اختياري | إن وُجدت أجهزة تابلت |

**عدد الصور:** على الأقل 2 لقطات شاشة، يُفضّل 4–8.

### 6.3 لقطات الشاشة المقترحة

1. شاشة الدخول / الرئيسية
2. قائمة الدورات
3. مشغل الدرس / الفيديو
4. شاشة التقدم أو الشهادات
5. الشات أو التواصل

---

## 7. Content Rating

1. من القائمة: **سياسة التطبيق** → **تصنيف المحتوى**
2. أجب على الاستبيان (استبيان IARC)
3. للتعليم: عادةً **جميع الأعمار** أو **3+**
4. احفظ التقييم وأرسله

---

## 8. Privacy Policy

يجب أن يكون لديك صفحة ويب لسياسة الخصوصية تحتوي على:

- ما هي البيانات التي تجمعها (حساب، بريد، صورة، إلخ)
- كيف تُستخدم البيانات
- هل يتم مشاركتها مع جهات ثالثة
- كيفية حذف البيانات
- معلومات الاتصال للاستفسارات

رابط السياسة يُضاف في:
**سياسة التطبيق** → **سياسة التطبيق** → **سياسة الخصوصية**

---

## 9. Data Safety

في **سياسة التطبيق** → **سلامة البيانات**:

- حدد نوع البيانات التي يجمعها التطبيق (حساب، بريد، صور، ملفات، إلخ)
- حدد ما إذا كانت إلزامية أم اختيارية
- حدد هل تُشارك مع طرف ثالث أم لا
- حدد هل يمكن حذفها أم لا

### بيانات التطبيق Dr Champions Academy المحتملة:

- **معلومات الحساب:** البريد، الاسم، الصورة (اختياري)
- **المحتوى:** ملفات يتم تنزيلها (إن وجد)
- **المعرفات:** معرف المستخدم (للجلسة والتوثيق)

---

## 10. Pricing & Distribution

1. **التسعير:** مجاني أو مدفوع
2. **البلدان:** حدد الدول التي ستُتاح فيها التطبيق
3. **الإعلانات:** حدد إن كان التطبيق يحتوي إعلانات أم لا

---

## 11. Upload the App

1. من القائمة: **الإنتاج** أو **الاختبار** → **إنشاء إصدار جديد**
2. ارفع ملف **AAB** (`app-release.aab`)
3. أدخل **ملاحظات الإصدار** (ما الجديد في هذا الإصدار)
4. راجع الصفحة وأرسل للتقييم
5. في حال وجود أخطاء، راجعها وعدّل التطبيق ثم أعد الرفع

---

## 12. Final Checklist

قبل الضغط على "إرسال للمراجعة":

- [ ] التطبيق يعمل بدون أخطاء على أجهزة حقيقية
- [ ] تم بناء AAB بالتوقيع الصحيح
- [ ] تم تعبئة كل حقول قائمة المتجر
- [ ] تم إرفاق لقطات الشاشة المطلوبة
- [ ] تم إكمال تصنيف المحتوى
- [ ] تم إضافة رابط سياسة الخصوصية
- [ ] تم تعبئة نموذج سلامة البيانات
- [ ] تم تحديد البلدان والتسعير والتوزيع
- [ ] تم اختبار التطبيق على مختلف الإصدارات (إن أمكن)

---

## أخطاء شائعة وحلولها

### "You need to use a different version code"
- زد قيمة `versionCode` في `pubspec.yaml` (الرقم بعد +)

### "App not signed correctly"
- تأكد من استخدام `signingConfigs.release` وملف `key.properties` الصحيح

### "Missing permission declaration"
- أضف تصريحات للأذونات الحساسة في لوحة التحكم و/أو في نموذج سلامة البيانات

### "Policy violation"
- راجع سياسات Google Play والتزم بها

### "READ_MEDIA_IMAGES / سياسة الصور"
- التطبيق يستخدم **Photo Picker** (file_picker) لاختيار الصور من المعرض – لا يلزم إذن READ_MEDIA_IMAGES
- الكاميرا تستخدم image_picker مع إذن CAMERA فقط
- تم إزالة READ_MEDIA_IMAGES من manifest عبر `tools:node="remove"`

**نص الرد (إن طُلب):**
> يستخدم التطبيق أداة اختيار الصور (Photo Picker) لاختيار صورة الملف الشخصي. لا يتم طلب إذن READ_MEDIA_IMAGES. الصور تُختار فقط عند تعديل الملف الشخصي عبر واجهة النظام.
- راجع سياسات Google Play والتزم بها، خاصةً سياسة الخصوصية والبيانات الحساسة

---

## روابط مفيدة

- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [Google Play policy center](https://play.google.com/about/developer-content-policy/)
