# Flutter Handoff: Exam Start 404 Fix

## المشكلة

عند بدء الامتحان من Flutter كان يظهر:

- `HTTP 404`
- Body عبارة عن HTML (`<!DOCTYPE html...>`)

هذا يعني أن الطلب كان يذهب لمسار غير صحيح في Next API ويرجع صفحة 404 للواجهة بدل JSON API.

---

## السبب الجذري

### 1) استخدام مسار Admin بدل مسار الطالب

تم استخدام:

- `POST /api/admin/exams/{examId}/start`

وهذا ليس مسار بدء امتحان للطالب.

المسار الصحيح للطالب مربوط بالكورس:

- `POST /api/courses/{courseId}/exams/{examId}/start`

### 2) Authorization Header غير صحيح

كان يصل أحيانًا بهذا الشكل:

- `Authorization: Bearer Bearer <token>`

الصحيح:

- `Authorization: Bearer <token>`

---

## المسارات الصحيحة للطالب (Exams)

1. `GET /api/courses/{courseId}/exams`
2. `GET /api/courses/{courseId}/exams/{examId}`
3. `POST /api/courses/{courseId}/exams/{examId}/start`
4. `POST /api/courses/{courseId}/exams/{examId}/submit`
5. `GET /api/my-exam-results?page=1&per_page=20&course_id={optional}`

---

## ما تم إصلاحه على السيرفر

تم إضافة وتفعيل Next.js proxy routes التالية:

- `GET /api/courses/[id]/exams/[examId]`
- `POST /api/courses/[id]/exams/[examId]/start`
- `POST /api/courses/[id]/exams/[examId]/submit`
- `GET /api/my-exam-results`

ثم تم:

- Build جديد
- Restart لخدمة الواجهة

---

## نتيجة التحقق

اختبار `POST` على المسار الصحيح الآن يرجع **JSON** (مثل `401` بدون توكن)، وليس HTML 404.

يعني مشكلة routing اتحلت، وأي خطأ لاحق سيكون منطقيًا من الـAPI (auth/enrollment/etc).

---

## المطلوب من Flutter

1. استبدال URL بدء الامتحان إلى:

`POST /api/courses/{courseId}/exams/{examId}/start`

2. التأكد أن الهيدر:

`Authorization: Bearer <token>`

بدون تكرار كلمة `Bearer`.

3. التعامل مع الأخطاء بصيغة JSON:

- `401`: token invalid/expired
- `400`: قيود منطقية (مثل عدم أهلية الطالب أو محاولة غير صحيحة)
- `404`: exam/course غير موجود

