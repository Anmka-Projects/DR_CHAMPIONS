# Backend Authentication Fixes Required

## المشكلة

المستخدم بعد تسجيل الدخول (خصوصاً عبر Google) لما بيحاول يشترك في كورس فري بيظهر خطأ:

```
401 Unauthorized - "يرجى تسجيل الدخول للوصول"
```

السبب إن الـ Token مش موجود أو منتهي الصلاحية، والتطبيق مش بيقدر يجدده.

---

## التعديلات المطلوبة

### 1. دعم Google في Social Login Endpoint

**Endpoint:** `POST /api/auth/social-login`

التطبيق دلوقتي بيبعت Google Firebase ID Token لنفس endpoint اللي Apple بيستخدمه.

**Request Body:**

```json
{
  "provider": "google",
  "id_token": "<Firebase ID Token>",
  "fcm_token": "<FCM Token for push notifications>",
  "device": {
    "platform": "android",
    "model": "Unknown",
    "app_version": "1.0.0"
  }
}
```

**المطلوب من الـ Backend:**

- التحقق إن `provider` = `"google"` مدعوم (مش بس `"apple"`)
- التحقق من صحة الـ `id_token` باستخدام Firebase Admin SDK أو Google's token verification
- إنشاء حساب جديد للمستخدم لو مش موجود (أو ربطه بحساب موجود بنفس الـ email)
- إرجاع `accessToken` و `refreshToken` زي ما بيحصل في Apple sign-in والـ login العادي

**Expected Response (Success):**

```json
{
  "success": true,
  "message": "تم تسجيل الدخول بنجاح",
  "data": {
    "user": {
      "id": "uuid",
      "name": "اسم المستخدم",
      "email": "user@gmail.com",
      "role": "student",
      "status": "ACTIVE"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

> **ملاحظة:** التطبيق بيدور على الـ token في أكتر من مكان في الـ response:
> `data.accessToken` → `data.token` → `data.access_token`
> فأي واحد من دول هيشتغل، بس الأفضل يكون `accessToken`.

---

### 2. التأكد من عمل Refresh Token Endpoint

**Endpoint:** `POST /api/auth/refresh`

التطبيق دلوقتي بيحاول يجدد الـ token تلقائياً لما يحصل 401.

**Request Body:**

```json
{
  "refreshToken": "<stored refresh token>"
}
```

**Expected Response (Success):**

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...<new token>",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...<new or same refresh token>"
  }
}
```

**Expected Response (Expired/Invalid Refresh Token):**

```json
{
  "success": false,
  "message": "انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى"
}
```

**المطلوب:**

- الـ endpoint يقبل الـ refresh token ويتحقق من صحته
- يرجع access token جديد
- (اختياري) يرجع refresh token جديد (Refresh Token Rotation) لأمان أفضل
- لو الـ refresh token منتهي أو غير صالح، يرجع `401` أو `403` مع `success: false`

---

### 3. مدة صلاحية الـ Tokens (مهم جداً)

| Token | المدة الحالية المقترحة | المدة الموصى بها لتطبيقات الموبايل |
|-------|----------------------|----------------------------------|
| Access Token | ؟ | **24 ساعة - 7 أيام** |
| Refresh Token | ؟ | **30 - 90 يوم** |

**ليه ده مهم؟**

- لو الـ Access Token بينتهي بسرعة (مثلاً 15 دقيقة)، المستخدم هيواجه 401 كتير
- تطبيقات الموبايل مش زي المواقع - المستخدم بيفتح التطبيق على فترات متباعدة
- الـ Refresh Token لازم يكون طويل علشان المستخدم ميحتاجش يسجل دخول كل يوم

**إعدادات JWT المقترحة (Node.js مثال):**

```javascript
// Access Token - صالح لمدة 7 أيام
const accessToken = jwt.sign(payload, ACCESS_SECRET, { expiresIn: '7d' });

// Refresh Token - صالح لمدة 60 يوم
const refreshToken = jwt.sign(payload, REFRESH_SECRET, { expiresIn: '60d' });
```

---

### 4. (اختياري) تسجيل كورس فري بدون Token

لو حبيتوا تحلوا المشكلة جذرياً للكورسات الفري:

**Endpoint:** `POST /api/courses/{id}/enroll`

**التعديل المقترح:**

```
- لو الكورس فري (price = 0) والـ request فيه Authorization header → سجل عادي
- لو الكورس فري ومفيش Authorization → ارجع رسالة واضحة:
  "يرجى تسجيل الدخول أولاً للاشتراك في الكورس"
  مع status code 401
```

> **ملاحظة:** مش بنقول تشيل الـ auth خالص من الـ enrollment - لأن لازم تعرف مين اللي بيشترك.
> بس الرسالة تكون واضحة والتطبيق هيتعامل معاها صح.

---

## ملخص التعديلات حسب الأولوية

| # | التعديل | الأولوية | التأثير |
|---|---------|---------|--------|
| 1 | دعم `provider: "google"` في `/api/auth/social-login` | **عالية جداً** | بدونه مستخدمي Google مش هيقدروا يعملوا أي حاجة |
| 2 | التأكد من `/api/auth/refresh` شغال | **عالية** | بدونه الـ auto-refresh مش هيشتغل |
| 3 | زيادة مدة صلاحية الـ Tokens | **متوسطة** | بيقلل عدد مرات انتهاء الـ token |
| 4 | رسالة واضحة للكورسات الفري | **منخفضة** | تحسين تجربة المستخدم |

---

## التعديلات اللي اتعملت في الـ Frontend

1. **`signInWithGoogle()`** - بقى بيكلم `/api/auth/social-login` بـ `provider: "google"` وبيحفظ الـ tokens
2. **Auto Token Refresh** - لما أي request يرجع 401، التطبيق بيحاول يجدد الـ token تلقائياً عن طريق `/api/auth/refresh` وبيعيد الـ request
3. **إيقاف مسح الـ Tokens التلقائي** - كان أي 401 بيمسح كل الـ tokens (death spiral). دلوقتي الـ tokens بتتمسح بس لو فشل الـ refresh
4. **إصلاح ApiException** - الـ status code كان بيضيع في الـ catch blocks

---

## اختبار بعد التعديلات

### سيناريو 1: Google Sign-In
1. المستخدم يضغط "تسجيل دخول بـ Google"
2. يختار حساب Google
3. التطبيق يبعت الـ `id_token` لـ `/api/auth/social-login`
4. **المتوقع:** الـ backend يرجع `accessToken` + `refreshToken` + بيانات المستخدم
5. المستخدم يقدر يشترك في كورسات

### سيناريو 2: Token Expiry + Auto Refresh
1. المستخدم مسجل دخول والـ access token انتهى
2. يحاول يشترك في كورس
3. الـ request يرجع 401
4. التطبيق يبعت الـ refresh token لـ `/api/auth/refresh`
5. **المتوقع:** الـ backend يرجع token جديد
6. التطبيق يعيد الـ enrollment request بالـ token الجديد
7. الاشتراك ينجح من غير ما المستخدم يحس بحاجة

### سيناريو 3: Refresh Token Expired
1. المستخدم مرجعش للتطبيق من فترة طويلة
2. الـ access token والـ refresh token انتهوا
3. يحاول يشترك في كورس → 401
4. التطبيق يحاول refresh → يفشل
5. **المتوقع:** التطبيق يمسح الـ tokens ويوجه المستخدم لتسجيل الدخول
