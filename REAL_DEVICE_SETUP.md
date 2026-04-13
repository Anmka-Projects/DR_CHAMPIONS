# 🎯 إعداد المشروع للتشغيل على جهاز iPhone حقيقي

## ✅ تم إصلاح المشاكل التالية:

1. ✅ تحديث iOS Deployment Target إلى 13.0
2. ✅ إصلاح UIScene Configuration في Info.plist
3. ✅ تنظيف كامل للمشروع

## 🚀 خطوات التشغيل على جهاز حقيقي

### 1️⃣ في Xcode

1. **افتح المشروع:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **إعداد التوقيع (Signing):**
   - اختر **Runner** من القائمة الجانبية
   - اذهب إلى **Signing & Capabilities**
   - اختر **Team** الخاص بك (أو "Personal Team" للتطوير)
   - غيّر **Bundle Identifier** إلى شيء فريد:
     ```
     com.yourname.educationalapp
     ```

3. **اختر الجهاز:**
   - من القائمة العلوية، اختر **iPhone الحقيقي** المتصل
   - تأكد من أن الجهاز موصول بـ USB وموثوق به

4. **اختر Configuration:**
   - **❌ لا تستخدم Debug** - سيسبب crash
   - **✅ استخدم Profile أو Release**

### 2️⃣ تغيير Configuration في Xcode

**الطريقة 1: من القائمة**
- **Product** → **Scheme** → **Edit Scheme...**
- اختر **Run** من القائمة اليسرى
- في **Build Configuration** اختر **Profile** أو **Release**
- اضغط **Close**

**الطريقة 2: من Terminal**
```bash
# Profile mode
flutter run --profile -d <device-id>

# Release mode  
flutter run --release -d <device-id>
```

### 3️⃣ تشغيل التطبيق

**من Xcode:**
- اضغط `Cmd + R` أو زر التشغيل (▶️)

**من Terminal:**
```bash
# عرض الأجهزة المتاحة
flutter devices

# تشغيل في Profile mode (موصى به)
flutter run --profile -d <device-id>

# أو Release mode
flutter run --release -d <device-id>
```

## ⚠️ ملاحظات مهمة

### Debug vs Profile vs Release

| Mode | الاستخدام | JIT | على جهاز حقيقي |
|------|----------|-----|----------------|
| **Debug** | التطوير | ✅ | ❌ Crash |
| **Profile** | اختبار الأداء | ❌ | ✅ يعمل |
| **Release** | النشر | ❌ | ✅ يعمل |

### لماذا Debug لا يعمل على جهاز حقيقي؟

- Debug يستخدم **JIT compilation** (Just-In-Time)
- iOS الحقيقي يمنع JIT لأسباب أمنية
- Profile و Release يستخدمان **AOT compilation** (Ahead-Of-Time) ✅

## 🔧 استكشاف الأخطاء

### خطأ: "Code signing error"
- تأكد من اختيار Team في Xcode
- للتطوير، استخدم "Personal Team"

### خطأ: "Device not trusted"
- على iPhone: **Settings** → **General** → **VPN & Device Management**
- اضغط "Trust" للكمبيوتر

### خطأ: "mprotect failed"
- تأكد من استخدام **Profile** أو **Release**
- لا تستخدم Debug على جهاز حقيقي

## 📝 Checklist قبل التشغيل

- [ ] تم تحديث iOS Deployment Target إلى 13.0
- [ ] تم إصلاح UIScene في Info.plist
- [ ] تم تنظيف المشروع (`flutter clean`)
- [ ] تم تثبيت CocoaPods (`pod install`)
- [ ] تم إعداد التوقيع في Xcode
- [ ] تم اختيار Profile أو Release (ليس Debug)
- [ ] تم اختيار الجهاز الحقيقي في Xcode

---

**جاهز! شغّل التطبيق الآن** 🚀


