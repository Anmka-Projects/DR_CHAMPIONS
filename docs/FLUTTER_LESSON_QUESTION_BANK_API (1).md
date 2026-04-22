# Flutter Integration: Lesson Question Bank

هذا الملف مخصص لمطور Flutter لتشغيل **بنك أسئلة الدرس** (Lesson-only Question Bank).

---

## 1) Base

- كل الطلبات تمر عبر نفس الـ API domain المستخدم في التطبيق.
- استخدم `Authorization`/Cookies بنفس آلية تسجيل الدخول الحالية.

---

## 2) Student Endpoints

## GET أسئلة الدرس

`GET /api/lesson-questions/lessons/{lessonId}`

### Success Response (شكل مختصر)

```json
{
  "success": true,
  "data": {
    "lessonId": "uuid",
    "questions": [
      {
        "id": "uuid",
        "lessonId": "uuid",
        "text": "ما هي عاصمة مصر؟",
        "type": "multiple-choice",
        "options": ["القاهرة", "الإسكندرية"],
        "explanation": "",
        "points": 1,
        "isActive": true,
        "order": 1
      }
    ],
    "stats": {
      "attemptsCount": 2,
      "bestScore": 80,
      "latestAttempt": {
        "id": "uuid",
        "score": 80,
        "totalQuestions": 5,
        "correctAnswers": 4,
        "isPassed": true,
        "submittedAt": "2026-04-20T10:00:00.000Z"
      }
    }
  }
}
```

### ملاحظات

- `questions` تأتي بدون `correctAnswer` للطالب (أمان).
- الأسئلة المعروضة هي `isActive=true` فقط.

---

## POST إرسال إجابات الطالب

`POST /api/lesson-questions/lessons/{lessonId}/submit`

### Request Body

```json
{
  "answers": [
    { "questionId": "uuid-1", "answer": "القاهرة" },
    { "questionId": "uuid-2", "answer": true },
    { "questionId": "uuid-3", "answer": "إجابة نصية" }
  ]
}
```

> نوع `answer` يقبل: `string | number | boolean | null`

### Success Response

```json
{
  "success": true,
  "data": {
    "attemptId": "uuid",
    "score": 80,
    "isPassed": true,
    "totalQuestions": 5,
    "correctAnswers": 4,
    "submittedAt": "2026-04-20T10:01:00.000Z"
  }
}
```

---

## 3) Admin/Instructor Endpoints (لو Flutter Admin)

## جلب أسئلة درس

`GET /api/admin/lesson-questions/lessons/{lessonId}/questions`

## إضافة سؤال

`POST /api/admin/lesson-questions/lessons/{lessonId}/questions`

```json
{
  "text": "نص السؤال",
  "type": "multiple-choice",
  "options": ["A", "B", "C"],
  "correctAnswer": "A",
  "explanation": "شرح",
  "points": 1,
  "isActive": true
}
```

## تعديل سؤال

`PUT /api/admin/lesson-questions/questions/{questionId}`

## حذف سؤال

`DELETE /api/admin/lesson-questions/questions/{questionId}`

## ترتيب الأسئلة

`PUT /api/admin/lesson-questions/lessons/{lessonId}/questions/reorder`

```json
{
  "questionIds": ["q1", "q2", "q3"]
}
```

## عداد الأسئلة لكل درس في كورس

`GET /api/admin/lesson-questions/courses/{courseId}/counts`

Response:

```json
{
  "success": true,
  "data": {
    "lesson-uuid-1": 8,
    "lesson-uuid-2": 3
  }
}
```

## استيراد Excel لأسئلة الدرس

`POST /api/admin/lesson-questions/lessons/{lessonId}/questions/import-xlsx`

- Content-Type: `multipart/form-data`
- field name: `file`
- الامتدادات: `xlsx/xls/csv`

أعمدة الملف المدعومة:

- `text`
- `type` (`multiple-choice` | `true-false` | `text`)
- `options` (مفصولة بعلامة `|`)
- `correctAnswer`
- `explanation`
- `points`
- `isActive`

---

## 4) Filters المقترحة في Flutter UI

> الـ API الحالي لا يطبق query filters على أسئلة الدرس، فالفلاتر تكون على مستوى الواجهة.

اعمل فلاتر client-side كالتالي:

- `All / Active / Inactive` حسب `isActive`
- `Type`: `multiple-choice` / `true-false` / `text`
- `Search` داخل `text`
- `Sort`: حسب `order` ثم `createdAt`

---

## 5) Error Handling

- لو `lessonId` غير صالح أو الدرس غير محفوظ -> خطأ 400/404.
- لو الطالب غير مشترك في الكورس -> 403.
- اعرض `message` القادمة من الـ API مباشرة في Snackbar/Dialog.

---

## 6) Flutter Implementation Checklist

- أضف models: `LessonQuestion`, `LessonQuestionBankStudentPayload`, `LessonQuestionAttemptResult`.
- عند فتح شاشة الدرس: نادِ `GET /lesson-questions/lessons/{lessonId}`.
- خزّن answers بـ `Map<String, dynamic>`.
- عند Submit: ابني payload بصيغة `answers[]`.
- بعد النجاح: اعرض score + pass/fail + حدّث state.
- في شاشة الأدمن: اعرض badge بعدد الأسئلة باستخدام `/counts`.
