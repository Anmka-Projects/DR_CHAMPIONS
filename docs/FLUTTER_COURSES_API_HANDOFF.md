# Flutter Handoff: Courses API (Latest Backend Contract)

هذا الملف يلخص آخر تغييرات الـ Backend المطلوبة لتكامل Flutter مع الكورسات.

---

## 1) Course Listing Rule (Student App)

`GET /api/courses` الآن يعرض:

- كل الدورات
- **ما عدا** الدورات ذات الحالة `archived`

يعني لم يعد محصورًا في `published` فقط.

---

## 2) Discount Fields in Course List

في كل عنصر كورس داخل `/api/courses`:

- `price`: السعر النهائي (بعد الخصم لو موجود)
- `original_price`: السعر قبل الخصم
- `discount_price`: سعر الخصم (أو `null` لو لا يوجد خصم)

### مثال (يوجد خصم)

```json
{
  "id": "course-id",
  "price": 700,
  "original_price": 1000,
  "discount_price": 700
}
```

### مثال (لا يوجد خصم)

```json
{
  "id": "course-id",
  "price": 1000,
  "original_price": 1000,
  "discount_price": null
}
```

---

## 3) Subscription Plans Boolean

تم إضافة:

- `has_subscription_plans: true | false`

في responses الخاصة بالكورسات (list/details وغيرها من مخرجات `formatCourse`).

### القاعدة

- `true` إذا يوجد plan صالح للشراء (غير منتهي + سعره > 0)
- `false` خلاف ذلك

> لا يزال `course_subscription_plans` موجودًا للتوافق الخلفي.

---

## 4) Categories Endpoints (Next API)

تم توفير routes الصحيحة التي كانت ناقصة:

- `GET /api/categories`
- `GET /api/categories/{id}/courses`

لو ظهر 404 HTML سابقًا على `/api/categories`، تم إصلاحه.

---

## 5) Recommended Flutter Mapping

على كارت الكورس:

- السعر المعروض: `price`
- السعر المشطوب: `original_price` (فقط إذا `discount_price != null` و `discount_price < original_price`)
- شارة الخصم: إذا `discount_price != null`
- شارة الخطط: إذا `has_subscription_plans == true`

---

## 6) Quick Checklist for Flutter Team

- تحديث model بإضافة `discount_price` و `has_subscription_plans`.
- عدم الاعتماد على `published only` في منطق الفرز داخل Flutter.
- استخدام `/api/categories` بدل أي fallback قديم.
- إبقاء fallback على `course_subscription_plans` اختياريًا للتوافق.
