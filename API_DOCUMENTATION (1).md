 # توثيق API – جميع الـ Endpoints والـ Responses

**Base URL:** `https://stp.anmka.com/api` (أو حسب البيئة)

**صيغة الطلبات:** JSON في Body مع الهيدر `Content-Type: application/json`  
**المسارات المحمية:** تحتاج الهيدر `Authorization: Bearer <ACCESS_TOKEN>`

---

## صيغة الرد القياسية

### نجاح
```json
{
  "success": true,
  "message": "رسالة اختيارية",
  "data": { ... }
}
```

### فشل
```json
{
  "success": false,
  "message": "رسالة الخطأ",
  "data": null,
  "errors": { "field": "تفاصيل الخطأ" }
}
```

---

## 1. المصادقة (Auth)

| Method | Endpoint | الوصف |
|--------|----------|--------|
| POST | `/api/auth/login` | تسجيل الدخول |
| POST | `/api/auth/register` | تسجيل مستخدم جديد |
| GET | `/api/auth/me` | المستخدم الحالي |
| PUT / POST | `/api/auth/profile` | تحديث الملف الشخصي |
| POST | `/api/auth/social-login` | تسجيل دخول اجتماعي (Google/Apple) |

### POST `/api/auth/login`

**Request Body (بريد):**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Request Body (هاتف):**
```json
{
  "phone": "+201000000000",
  "password": "password123"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "jwt_token_here",
    "refreshToken": "refresh_token_here",
    "user": {
      "id": "uuid",
      "name": "اسم المستخدم",
      "email": "user@example.com",
      "role": "student",
      "avatar": null
    }
  }
}
```

**ملاحظة:** عند النجاح يُضبط كوكي `adminToken` أو `accessToken` حسب السياق.

---

### POST `/api/auth/register`

**Request Body (طالب):**
```json
{
  "name": "Ahmed Ali",
  "email": "ahmed@example.com",
  "phone": "+201000000000",
  "password": "StrongPass123",
  "role": "student",
  "student_type": "online"
}
```

**Request Body (مدرس):**
```json
{
  "name": "Instructor Test",
  "email": "instructor@example.com",
  "password": "StrongPass123",
  "role": "instructor"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "تم التسجيل بنجاح",
  "data": {
    "accessToken": "jwt_token_here",
    "user": { "id": "uuid", "name": "...", "email": "...", "role": "..." }
  }
}
```

**Response (400):** عند إرسال body غير JSON أو بيانات غير صحيحة.

---

### GET `/api/auth/me`

**Headers:** `Authorization: Bearer <ACCESS_TOKEN>`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "اسم المستخدم",
    "email": "user@example.com",
    "phone": "+201000000000",
    "role": "student",
    "avatar": "/uploads/images/avatar.jpg",
    "student_type": "online"
  }
}
```

---

### PUT `/api/auth/profile`

**Headers:** `Authorization: Bearer <ACCESS_TOKEN>`

**Request Body (JSON):**
```json
{
  "name": "الاسم الجديد",
  "phone": "+201234567890",
  "avatar": "https://cdn.example.com/avatar.png"
}
```

**Request (multipart/form-data):** يمكن إرسال `avatar` (ملف صورة)، `name`، `phone`.

**Response (200):**
```json
{
  "success": true,
  "message": "تم تحديث الملف الشخصي",
  "data": {
    "id": "uuid",
    "name": "الاسم الجديد",
    "email": "...",
    "avatar": "/uploads/images/..."
  }
}
```

**Response (400):** نوع ملف غير مسموح أو حجم صورة أكبر من 5MB.

---

### POST `/api/auth/social-login`

**Request Body (Google):**
```json
{
  "provider": "google",
  "id_token": "<GOOGLE_ID_TOKEN>",
  "access_token": "<GOOGLE_ACCESS_TOKEN>",
  "fcm_token": "<optional>",
  "device": { "platform": "web" }
}
```

**Request Body (Apple):**
```json
{
  "provider": "apple",
  "id_token": "<APPLE_ID_TOKEN>",
  "nonce": "<optional>"
}
```

**Response (200):** نفس هيكل `/api/auth/login` مع `accessToken` و `user`.

---

## 2. الصفحة الرئيسية والدورات (عامة/مستخدم)

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/home` | بيانات الصفحة الرئيسية |
| GET | `/api/courses` | قائمة الدورات (مع query) |
| GET | `/api/courses/:id` | تفاصيل دورة |
| GET | `/api/enrollments` | تسجيلات المستخدم (مع query) |
| GET | `/api/progress` | تقدم المستخدم (مع query) |

### GET `/api/home`

**Headers (اختياري):** `Authorization: Bearer <token>` للبيانات الشخصية.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "banners": [],
    "featuredCourses": [],
    "categories": [],
    "stats": {}
  }
}
```

---

### GET `/api/courses`

**Query:** يُمرَّر كما هو للـ backend (مثل `limit`, `page`, `category`, `search`).

**Response (200):**
```json
{
  "success": true,
  "data": {
    "courses": [],
    "meta": { "total": 0, "page": 1, "limit": 10 }
  }
}
```

---

### GET `/api/courses/:id`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "title": "عنوان الدورة",
    "description": "...",
    "instructor": {},
    "curriculum": [],
    "price": 0,
    "status": "published"
  }
}
```

---

### GET `/api/enrollments`

**Headers:** `Authorization: Bearer <token>`  
**Query:** يُمرَّر للـ backend.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "enrollments": [],
    "meta": {}
  }
}
```

---

### GET `/api/progress`

**Headers:** `Authorization: Bearer <token>`  
**Query:** يُمرَّر للـ backend.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "progress": [],
    "meta": {}
  }
}
```

---

## 3. الإشعارات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/notifications` | قائمة الإشعارات |
| POST | `/api/notifications/:id/read` | تعليم إشعار كمقروء |
| POST | `/api/notifications/read-all` | تعليم الكل كمقروء |

### GET `/api/notifications`

**Headers:** `Authorization: Bearer <token>`  
**Query:** يُمرَّر للـ backend (مثل `page`, `limit`).

**Response (200):**
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": "uuid",
        "title": "عنوان",
        "body": "نص الإشعار",
        "read": false,
        "createdAt": "2026-01-01T00:00:00.000Z"
      }
    ],
    "meta": {}
  }
}
```

### POST `/api/notifications/:id/read`

**Response (200):**
```json
{
  "success": true,
  "message": "تم تعليم الإشعار كمقروء",
  "data": { "id": "uuid", "read": true }
}
```

### POST `/api/notifications/read-all`

**Response (200):**
```json
{
  "success": true,
  "message": "تم تعليم جميع الإشعارات كمقروءة",
  "data": {}
}
```

---

## 4. الحضور والـ QR

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/attendance/session` | جلسة الحضور (مع query) |
| POST | `/api/attendance/scan` | مسح QR للحضور |
| GET | `/api/attendance/qr-code/:userId` | الحصول على QR للمستخدم |
| GET | `/api/my-qr-code` | QR الخاص بالمستخدم الحالي |

**Headers:** `Authorization: Bearer <token>` حيث يلزم.

**Response (200):** حسب الـ backend (جلسة، نتيجة مسح، بيانات QR).

---

## 5. الرفع والإعدادات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| POST | `/api/upload` | رفع ملف (صورة/فيديو/PDF) |
| GET | `/api/config/app` | إعدادات التطبيق |
| GET | `/api/videos/cache` | حالة كاش الفيديو |

### POST `/api/upload`

**Content-Type:** `multipart/form-data`  
**Body:** `image` أو `file` (الملف)، واختياري `type` (مثل `video`).

**Response (200):**
```json
{
  "success": true,
  "url": "/uploads/images/123456_abc.jpg",
  "filename": "123456_abc.jpg",
  "message": "تم رفع الصورة بنجاح"
}
```

**ملاحظات:** صور حتى 5MB، فيديو حتى 500MB، PDF حتى 50MB.

---

### GET `/api/config/app`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "appName": "...",
    "features": {},
    "settings": {}
  }
}
```

---

### GET `/api/videos/cache`

**Response (200):**
```json
{
  "success": true,
  "message": "Video cache API",
  "data": {
    "cacheSupported": true
  }
}
```

---

### GET `/api/uploads/[...path]`

يعيد الملفات الثابتة من مسار الرفع (مثل `/api/uploads/images/xxx.jpg`). الرد قد يكون صورة أو ملف وليس JSON.

---

## 6. لوحة الإدارة – الداشبورد

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/dashboard/overview` | نظرة عامة |
| GET | `/api/admin/dashboard/charts` | بيانات الرسوم البيانية |

**Headers:** `Authorization: Bearer <admin_token>` (أو استخدام admin تلقائي من الـ proxy).

**Response (200):**
```json
{
  "success": true,
  "data": {
    "totalUsers": 0,
    "totalCourses": 0,
    "totalRevenue": 0,
    "recentEnrollments": [],
    "charts": {}
  }
}
```

---

## 7. لوحة الإدارة – المستخدمون

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/users` | قائمة المستخدمين |
| POST | `/api/admin/users` | إنشاء مستخدم |
| POST | `/api/admin/users/new` | إنشاء مستخدم (body كما يُرسل) |
| GET | `/api/admin/users/:id` | تفاصيل مستخدم |
| PUT | `/api/admin/users/:id` | تحديث مستخدم |
| DELETE | `/api/admin/users/:id` | حذف مستخدم |
| GET | `/api/admin/users/:id/details` | تفاصيل إضافية |
| PATCH | `/api/admin/users/:id/status` | تغيير الحالة (مثلاً active/suspended) |

**GET `/api/admin/users`**  
**Query:** `limit`, `page`, `role`, `status`, `search` وغيرها.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "uuid",
        "name": "...",
        "email": "...",
        "role": "student",
        "status": "active",
        "createdAt": "..."
      }
    ],
    "meta": { "total": 0, "page": 1, "limit": 20 }
  }
}
```

**POST `/api/admin/users`**  
**Body:** حقول المستخدم (name, email, password, role, إلخ).

**PATCH `/api/admin/users/:id/status`**  
**Body:** مثل `{ "status": "active" }` أو `{ "status": "suspended" }`.

---

## 8. لوحة الإدارة – الدورات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/courses` | قائمة الدورات |
| POST | `/api/admin/courses` | إنشاء دورة |
| GET | `/api/admin/courses/:id` | تفاصيل دورة |
| PUT | `/api/admin/courses/:id` | تحديث دورة |
| DELETE | `/api/admin/courses/:id` | حذف دورة |
| POST | `/api/admin/courses/:id/approve` | الموافقة على دورة |
| POST | `/api/admin/courses/:id/reject` | رفض دورة |
| GET | `/api/admin/courses/:id/curriculum` | المنهج |
| PUT | `/api/admin/courses/:id/curriculum` | تحديث المنهج |
| GET | `/api/admin/courses/:id/lectures` | قائمة المحاضرات |
| POST | `/api/admin/courses/:id/lectures` | إضافة محاضرة |
| GET | `/api/admin/courses/:id/lectures/:lectureId` | محاضرة واحدة |
| PUT | `/api/admin/courses/:id/lectures/:lectureId` | تحديث محاضرة |
| DELETE | `/api/admin/courses/:id/lectures/:lectureId` | حذف محاضرة |

**Query للقوائم:** يُمرَّر للـ backend (مثل `limit`, `status`, `search`).

**Response (200) للقوائم:**  
`data`: مصفوفة أو كائن يحتوي `courses`/`lectures` و `meta` حسب الـ backend.

---

## 9. لوحة الإدارة – الامتحانات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/exams` | قائمة الامتحانات |
| POST | `/api/admin/exams` | إنشاء امتحان |
| GET | `/api/admin/exams/:id` | تفاصيل امتحان |
| PUT | `/api/admin/exams/:id` | تحديث امتحان |
| DELETE | `/api/admin/exams/:id` | حذف امتحان |
| GET | `/api/admin/exams/:id/questions` | أسئلة الامتحان |
| POST | `/api/admin/exams/:id/questions` | إضافة سؤال |
| PUT | `/api/admin/exams/:id/questions/:questionId` | تحديث سؤال |
| DELETE | `/api/admin/exams/:id/questions/:questionId` | حذف سؤال |
| GET | `/api/admin/exams/attempts` | محاولات الامتحانات (مع query) |

**Response (200) للأسئلة:**
```json
{
  "success": true,
  "data": {
    "questions": [
      {
        "id": "uuid",
        "text": "نص السؤال",
        "type": "multiple_choice",
        "options": [],
        "order": 1
      }
    ]
  }
}
```

---

## 10. لوحة الإدارة – التصنيفات والبانرات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/categories` | قائمة التصنيفات |
| POST | `/api/admin/categories` | إنشاء تصنيف |
| GET | `/api/admin/categories/:id` | تفاصيل تصنيف |
| PUT | `/api/admin/categories/:id` | تحديث تصنيف |
| DELETE | `/api/admin/categories/:id` | حذف تصنيف |
| GET | `/api/admin/banners` | قائمة البانرات |
| POST | `/api/admin/banners` | إنشاء بانر |
| GET | `/api/admin/banners/:id` | تفاصيل بانر |
| PUT | `/api/admin/banners/:id` | تحديث بانر |
| DELETE | `/api/admin/banners/:id` | حذف بانر |

**Response (200):** `data` يحتوي العنصر أو القائمة و`meta` عند الحاجة.

---

## 11. لوحة الإدارة – الكوبونات والمدفوعات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/coupons` | قائمة الكوبونات (نفس payments/coupons) |
| POST | `/api/admin/coupons` | إنشاء كوبون |
| GET | `/api/admin/coupons/:id` | تفاصيل كوبون |
| PUT | `/api/admin/coupons/:id` | تحديث كوبون |
| DELETE | `/api/admin/coupons/:id` | حذف كوبون |
| GET | `/api/admin/payments` | قائمة المدفوعات |
| GET | `/api/admin/payments/coupons` | قائمة كوبونات المدفوعات |
| POST | `/api/admin/payments/coupons` | إنشاء كوبون |
| POST | `/api/admin/payments/coupons/bulk` | إنشاء كوبونات بالجملة |
| GET | `/api/admin/payments/coupons/export` | تصدير كوبونات Excel |
| GET | `/api/admin/payments/coupons/:id` | تفاصيل كوبون |
| PUT | `/api/admin/payments/coupons/:id` | تحديث كوبون |
| DELETE | `/api/admin/payments/coupons/:id` | حذف كوبون |

### POST `/api/admin/payments/coupons/bulk`

**Request Body:**
```json
{
  "count": 100,
  "type": "percentage",
  "value": 20,
  "maxUses": 50,
  "minPurchase": 100,
  "expiresAt": "2026-12-31T23:59:59.000Z",
  "isActive": true,
  "codeLength": 8,
  "codePrefix": "DISCOUNT"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "تم إنشاء 100 كوبون بنجاح",
  "data": {
    "success": 100,
    "failed": 0,
    "total": 100,
    "coupons": [],
    "errors": null
  }
}
```

### GET `/api/admin/payments/coupons/export`

**Query:** `isActive`, `search`.  
**Response:** ملف Excel (`.xlsx`) مع الهيدر المناسب للتحميل.

---

## 12. لوحة الإدارة – الخزينة (Treasury)

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/treasury` | قائمة/حالة الخزينة |
| POST | `/api/admin/treasury` | إضافة حركة |
| GET | `/api/admin/treasury/:id` | تفاصيل حركة |
| PUT | `/api/admin/treasury/:id` | تحديث حركة |
| DELETE | `/api/admin/treasury/:id` | حذف حركة |
| POST | `/api/admin/treasury/expense` | مصروف |
| GET | `/api/admin/treasury/statistics` | إحصائيات الخزينة |
| GET | `/api/admin/treasury/transactions` | المعاملات |

**Response (200):** `data` حسب المورد (قائمة، عنصر واحد، إحصائيات).

---

## 13. لوحة الإدارة – المدرسون والمرتبات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/teachers/reports` | تقارير المدرسين (مع query) |
| GET | `/api/admin/teachers/salary-settings` | إعدادات المرتبات العامة |
| PUT | `/api/admin/teachers/salary-settings` | تحديث إعدادات المرتبات |
| GET | `/api/admin/teachers/:teacherId/salary-settings` | إعدادات مرتب معلم |
| PUT | `/api/admin/teachers/:teacherId/salary-settings` | تحديث إعدادات مرتب معلم |
| GET | `/api/admin/teachers/:teacherId/calculate-salary` | حساب مرتب معلم |
| GET | `/api/admin/teachers/me/calculate-salary` | حساب مرتبي (المستخدم الحالي) |
| GET | `/api/admin/teachers/me/salary-settings` | إعدادات مرتبي |

**Response (200):** `data` يحتوي التقارير أو إعدادات المرتب أو نتيجة الحساب.

---

## 14. لوحة الإدارة – الطلاب والديون

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/students/debts` | قائمة الديون |
| GET | `/api/admin/students/debts/financial` | ديون مالية (مع query: `studentId`) |
| POST | `/api/admin/students/debts/pay` | سداد دين (body: `debtId` ومبلغ إن وُجد) |

**Query لـ financial:** يُمرَّر للـ backend (مثل `studentId`).

---

## 15. لوحة الإدارة – التقارير الشهرية والمرتبات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| POST | `/api/admin/monthly-reports/students/:studentId` | إرسال تقرير شهري لطالب |
| POST | `/api/admin/monthly-reports/students/bulk` | إرسال تقارير لجميع الطلاب |
| POST | `/api/admin/monthly-reports/teachers/:teacherId/salary` | إرسال كشف مرتب لمدرس |
| POST | `/api/admin/monthly-reports/teachers/salary/bulk` | إرسال كشوف مراتب لجميع المدرسين |
| POST | `/api/admin/monthly-reports/employees/:employeeId/salary` | إرسال كشف مرتب لموظف |
| POST | `/api/admin/monthly-reports/employees/salary/bulk` | إرسال كشوف مراتب لموظفين (مع مصفوفة مرتبات) |

### POST `/api/admin/monthly-reports/students/:studentId`

**Request Body:**
```json
{
  "month": 1,
  "year": 2026
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "تم إرسال التقرير الشهري بنجاح",
  "data": {
    "success": true,
    "studentId": "uuid",
    "studentName": "اسم الطالب",
    "month": 1,
    "year": 2026,
    "coursesCount": 5,
    "lessonsCompleted": 12,
    "notificationId": "uuid"
  }
}
```

### POST `/api/admin/monthly-reports/teachers/salary/bulk`

**Request Body:**
```json
{
  "month": 1,
  "year": 2026
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "تم إرسال 25 كشف مرتب بنجاح",
  "data": {
    "success": 25,
    "failed": 0,
    "total": 25,
    "errors": []
  }
}
```

### POST `/api/admin/monthly-reports/employees/salary/bulk`

**Request Body:**
```json
{
  "month": 1,
  "year": 2026,
  "employeeSalaries": [
    { "employeeId": "uuid-1", "salaryAmount": 3000.00 },
    { "employeeId": "uuid-2", "salaryAmount": 4000.00 }
  ]
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "تم إرسال 10 كشف مرتب بنجاح",
  "data": {
    "success": 10,
    "failed": 1,
    "total": 11,
    "errors": [{ "employeeId": "uuid", "error": "الموظف غير موجود" }]
  }
}
```

---

## 16. لوحة الإدارة – الحضور والإشعارات والإعدادات

| Method | Endpoint | الوصف |
|--------|----------|--------|
| GET | `/api/admin/attendance` | قائمة الحضور |
| POST | `/api/admin/attendance/register` | تسجيل حضور |
| GET | `/api/admin/notifications` | إشعارات الإدارة (مع query) |
| POST | `/api/admin/notifications` | إنشاء إشعار |
| GET | `/api/admin/reports` | تقارير (مع query) |
| GET | `/api/admin/reports/financial` | التقرير المالي (مع query) |
| GET | `/api/admin/live-sessions` | الجلسات المباشرة (مع query) |
| POST | `/api/admin/live-sessions` | إنشاء جلسة مباشرة |
| GET | `/api/admin/certificates` | الشهادات (مع query) |
| GET | `/api/admin/certificate-templates` | قوالب الشهادات |
| POST | `/api/admin/certificate-templates` | إنشاء قالب شهادة |
| GET | `/api/admin/app-config` | إعدادات التطبيق (للإدارة) |
| PUT | `/api/admin/app-config` | تحديث إعدادات التطبيق |

**Response (200):** في كل حالة `data` يحتوي القائمة أو العنصر أو الإحصائيات حسب الـ endpoint.

---

## 17. أخطاء شائعة

| Status | المعنى | مثال Response |
|--------|--------|----------------|
| 400 | طلب غير صحيح | `{ "success": false, "message": "يجب إرسال البيانات في body كـ JSON", "data": null }` |
| 401 | غير مصرح | `{ "success": false, "message": "غير مصرح", "data": null }` |
| 404 | غير موجود | `{ "success": false, "message": "المورد غير موجود", "data": null }` |
| 429 | تجاوز حد الطلبات | `{ "success": false, "message": "تم تجاوز الحد المسموح من الطلبات...", "data": null }` |
| 503 | الخادم غير متاح | `{ "success": false, "message": "الخادم غير متاح حالياً", "data": null }` |
| 500 | خطأ داخلي | `{ "success": false, "message": "خطأ في الاتصال بالخادم", "data": null }` |

---

## 18. Postman

- **GET** `/api/postman-collection`  
  يعيد ملف مجموعة Postman (JSON) للتحميل.

---

## ملاحظات عامة

1. معظم مسارات الـ API تعمل كـ **proxy** للـ backend؛ الردود الفعلية قد تحتوي حقولاً إضافية حسب الـ backend.
2. مسارات `/api/admin/*` قد تستخدم تلقائياً توكن admin من الـ proxy إذا لم يُرسل `Authorization`.
3. للتفاصيل الإضافية: راجع `AUTH_API_DOC.md`، `API_MONTHLY_REPORTS.md`، `API_VIDEO_CACHE.md`، `API_COUPONS_BULK.md`.
