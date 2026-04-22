# Backend Contract: Course Has Plan Boolean

هذا الملف لمطور الـ Backend لتوفير **boolean واضح** يحدد هل الكورس لديه خطط أسعار أم لا، بحيث Flutter يعرض رسالة على كارت الكورس بسهولة.

---

## الهدف

بدل ما الـ frontend يعتمد فقط على تحليل `course_subscription_plans`، نحتاج حقل مباشر:

- `has_subscription_plans: true | false`

ويكون موجود في جميع استجابات الكورسات (list + details).

---

## الحقل المطلوب

### الاسم (Recommended)

- `has_subscription_plans` (boolean)

### القاعدة

- `true` إذا كان الكورس يحتوي على **أي خطة صالحة للشراء**.
- `false` إذا لا يوجد خطط.

> مفضل أن يكون الحساب Backend-side وفق قواعد البزنس (active/published/available plans فقط).

---

## أين يجب أن يظهر؟

1. `GET /courses` (أي endpoint list للكورسات)
2. `GET /courses/{id}` (course details)
3. أي endpoints أخرى ترجع Course object في التطبيق

---

## مثال Response (List Item)

```json
{
  "id": "course_123",
  "title": "Biology Masterclass",
  "price_egp": 1200,
  "course_subscription_plans": [
    { "id": "plan_m", "name": "Monthly", "price_egp": 250 }
  ],
  "has_subscription_plans": true
}
```

## مثال Response (No Plans)

```json
{
  "id": "course_456",
  "title": "Chemistry Basics",
  "price_egp": 900,
  "course_subscription_plans": [],
  "has_subscription_plans": false
}
```

---

## ملاحظات تكامل Flutter

- Flutter الآن يقرأ `has_subscription_plans` أولًا لعرض badge:
  - English: `Plans available`
  - Arabic: `يوجد خطط أسعار`
- إذا الحقل غير موجود مؤقتًا، يوجد fallback على `course_subscription_plans` لضمان عدم كسر الواجهة.

---

## توافق Backward Compatibility

لتجنب كسر أي clients قديمة:

- استمر في إرسال `course_subscription_plans` كما هو.
- أضف فقط `has_subscription_plans` كتحسين.

