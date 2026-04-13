## توثيق طلب/استجابة تسجيل الدخول الاجتماعي (Google / Apple)

- **البيئة:** `https://stp.anmka.com/v1`
- **الهدف:** إرسال توكن Google أو Apple (المولّد من Firebase/SDK) إلى السيرفر لإصدار توكن التطبيق (`accessToken` + `refreshToken`) المتوافق مع نماذج `AuthResponse` في المشروع.
- **الهيدر المطلوب:** `Content-Type: application/json`

### 1) تسجيل الدخول عبر Google

**الطلب**
```
POST /auth/social-login
Host: stp.anmka.com
Content-Type: application/json

{
  "provider": "google",                 // ثابت
  "id_token": "<google idToken>",       // من GoogleSignInAuthentication.idToken
  "access_token": "<google accessToken>", // اختياري، يفضَّل إرساله
  "fcm_token": "<device-fcm-token>",    // اختياري لإشعارات الجهاز
  "device": {
    "platform": "android|ios|web",
    "model": "Pixel 7",
    "app_version": "1.0.0"
  }
}
```

**استجابة ناجحة (مطابقة لـ `AuthResponse`)**
```
200 OK
{
  "success": true,
  "message": "Logged in successfully",
  "data": {
    "user": {
      "id": "123",
      "name": "Ahmed Mohamed",
      "email": "ahmed@example.com",
      "phone": "+201234567890",
      "avatar": "https://stp.anmka.com/storage/avatars/123.png",
      "avatar_thumbnail": "https://stp.anmka.com/storage/avatars/123_thumb.png",
      "role": "student",
      "is_verified": true,
      "created_at": "2024-01-01T10:00:00Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", // يلتقطه AuthResponse.token
    "refreshToken": "def50200c25b...",                       // يلتقطه AuthResponse.refreshToken
    "expires_at": "2025-12-31T23:59:59Z"
  }
}
```

**استجابة فشل**
```
401 Unauthorized
{
  "success": false,
  "message": "Invalid Google token"
}
```

### 2) تسجيل الدخول عبر Apple

**الطلب**
```
POST /auth/social-login
Host: stp.anmka.com
Content-Type: application/json

{
  "provider": "apple",                     // ثابت
  "id_token": "<apple identityToken>",     // من SignInWithAppleCredential.identityToken
  "nonce": "<rawNonce-used-in-client>",    // نفس الـ nonce المرسل لـ Apple
  "fcm_token": "<device-fcm-token>",       // اختياري
  "device": {
    "platform": "ios",
    "model": "iPhone 15 Pro",
    "app_version": "1.0.0"
  }
}
```

**استجابة ناجحة**
```
200 OK
{
  "success": true,
  "message": "Logged in successfully",
  "data": {
    "user": {
      "id": "456",
      "name": "Laila Ali",
      "email": "laila@example.com",
      "phone": "+201100000000",
      "avatar": null,
      "avatar_thumbnail": null,
      "role": "student",
      "is_verified": true,
      "created_at": "2024-05-10T12:30:00Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", // يلتقطه AuthResponse.token
    "refreshToken": "def50200aa7c...",                       // يلتقطه AuthResponse.refreshToken
    "expires_at": "2025-12-31T23:59:59Z"
  }
}
```

**استجابة فشل**
```
401 Unauthorized
{
  "success": false,
  "message": "Invalid Apple token"
}
```

### ملاحظات
- الحقلان `accessToken` و`refreshToken` يجب أن يكونا داخل `data` كما هو موضّح لضمان التقاطهما في `AuthResponse.fromJson`.
- في حال اعتماد تسميات مختلفة (مثل `access_token` أو وضع التوكن في الجذر)، لا يزال `AuthResponse` يدعم هذه السيناريوهات، لكن يُفضّل الالتزام بالشكل أعلاه.
- يمكن إضافة أي بيانات جهاز/موقع إضافية حسب الحاجة، مع الحفاظ على الحقول الأساسية (`provider`, `id_token`).

