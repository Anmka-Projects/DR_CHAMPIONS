# Flutter Handoff: Lesson-Level Exams

هذا الملف لفريق Flutter بخصوص دعم الامتحان على مستوى:

- الدورة (`course`)
- أو درس محدد (`lesson`)

---

## 1) Admin Contract (Create/Update)

## إنشاء امتحان

`POST /api/admin/exams`

### Body

```json
{
  "title": "اختبار الدرس الأول",
  "description": "مراجعة سريعة",
  "courseId": "uuid-course",
  "lessonId": "uuid-lesson",
  "passingScore": 60,
  "maxAttempts": 3,
  "duration": 30,
  "isActive": true
}
```

### قواعد الربط

- لو `lessonId = null` => الامتحان على مستوى الدورة.
- لو `lessonId` موجود => الامتحان على مستوى الدرس.
- لازم `lessonId` يكون تابع لنفس `courseId` (وإلا يرجع خطأ).

## تعديل امتحان

`PUT /api/admin/exams/{id}`

يمكن إرسال `courseId` و/أو `lessonId` لتغيير النطاق.

---

## 2) Admin Response Fields الجديدة

في list/details:

- `targetType`: `"course"` أو `"lesson"`
- `lessonId`: `string | null`
- `lessonName`: `string | null`

---

## 3) Student/Mobile Endpoints

## قائمة امتحانات الدورة

`GET /api/courses/{courseId}/exams`

### فلترة اختياريًا بدرس معيّن

`GET /api/courses/{courseId}/exams?lesson_id={lessonId}`

### لكل امتحان في القائمة

```json
{
  "id": "uuid",
  "title": "اختبار الدرس",
  "course_id": "uuid-course",
  "course_name": "Course name",
  "lesson_id": "uuid-lesson",
  "lesson_name": "Lesson name",
  "target_type": "lesson",
  "questions_count": 10,
  "duration_minutes": 30,
  "passing_score": 60,
  "max_attempts": 3,
  "attempts_used": 0,
  "best_score": null,
  "is_passed": false,
  "can_start": true
}
```

## تفاصيل امتحان

`GET /api/courses/{courseId}/exams/{examId}`

يرجع نفس حقول النطاق:

- `lesson_id`
- `lesson_name`
- `target_type`

---

## 4) Flutter UI Behavior

- في شاشة الدرس:
  - اطلب:
    - `GET /api/courses/{courseId}/exams?lesson_id={currentLessonId}`
  - اعرض فقط امتحانات هذا الدرس.
- في شاشة الدورة:
  - اطلب:
    - `GET /api/courses/{courseId}/exams`
  - اعرض كل امتحانات الدورة + امتحانات الدروس.
- Badge مقترح:
  - `target_type == "lesson"` => "امتحان الدرس"
  - `target_type == "course"` => "امتحان الدورة"

---

## 5) Backward Compatibility

- الامتحانات القديمة (قبل التحديث) ستبقى تعمل طبيعيًا.
- غالبًا ستكون:
  - `lesson_id = null`
  - `target_type = "course"`
