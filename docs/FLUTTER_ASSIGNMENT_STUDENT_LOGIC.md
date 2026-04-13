# Flutter Student Assignment Logic

هذا المستند جاهز للإرسال لمطور Flutter لتطبيق منطق "الواجبات" للطالب.

## 1) الهدف

تطبيق رحلة الطالب كاملة للواجب:

1. عرض واجبات الكورس.
2. فتح تفاصيل الواجب والأسئلة.
3. رفع ملفات/صور الإجابة.
4. تسليم الواجب (وأيضًا إعادة التسليم قبل الموعد النهائي).
5. عرض حالة التصحيح والدرجة وملاحظة المعلم.

---

## 2) المتطلبات الأساسية

- كل endpoints تحتاج `Authorization: Bearer <token>`.
- الـBase API Path: `/api`.
- الطالب يجب أن يكون مشتركًا في الكورس ولديه صلاحية خطة نشطة.

---

## 3) Endpoints المطلوبة

### A) قائمة واجبات الكورس

- `GET /api/courses/{courseId}/assignments`

**تُرجع لكل واجب:**

- `id`
- `title`
- `description`
- `source_image_url`
- `source_file_url`
- `due_date`
- `total_points`
- `questions_count`
- `submission` (قد تكون `null` إذا لم يسلّم الطالب)

---

### B) تفاصيل واجب واحد

- `GET /api/courses/{courseId}/assignments/{assignmentId}`

**تُرجع:**

- بيانات الواجب الأساسية.
- `questions[]` (الأسئلة).
- `my_submission` (آخر تسليم للطالب، أو `null`).

**مهم داخل الأسئلة:**

- `question_format`: `text | image | audio`
- `answer_format`: `multiple-choice | text | image | audio`
- `options` و `option_images` قد يكونان فارغين.

---

### C) تسليم / إعادة تسليم الواجب

- `POST /api/courses/{courseId}/assignments/{assignmentId}/submit`

**Body:**

```json
{
  "answer_text": "optional",
  "answer_images": ["/uploads/images/....jpg"],
  "answer_files": ["/uploads/documents/....pdf"]
}
```

**قواعد مهمة منطقية:**

- لازم يوجد عنصر واحد على الأقل من:
  - `answer_text` (بعد trim)
  - `answer_images` (length > 0)
  - `answer_files` (length > 0)
- إذا `due_date` انتهى -> السيرفر يرفض التسليم.
- نفس endpoint يعمل create أول مرة و upsert في إعادة التسليم.

---

### D) شاشة "تسليماتي"

- `GET /api/my-assignment-submissions?page=1&per_page=20&course_id={optional}`

---

### E) رفع الصور/الملفات قبل التسليم

- `POST /api/upload` أو `/api/uploads/upload`
- `FormData` field: `file` أو `image`
- استخدم `url` الناتج داخل `answer_images` / `answer_files`.

---

## 4) UX Flow المطلوب في Flutter

## 4.1 Assignment List Screen

لكل واجب اعرض:

- العنوان + الموعد النهائي.
- Badge حالة التسليم:
  - `لم يتم التسليم` إذا `submission == null`
  - `تم التسليم` إذا `submission.status == submitted`
  - `تمت المراجعة` إذا `reviewed`
  - `مقبول` إذا `accepted`
  - `مرفوض` إذا `rejected`
- إذا `score != null` اعرض الدرجة.

---

## 4.2 Assignment Details Screen

اعرض:

- وصف الواجب.
- صورة/ملف المصدر (إن وُجد).
- قائمة الأسئلة بالترتيب.
- قسم "تسليمي الأخير" من `my_submission` (إن وجد).

زر الإجراء الرئيسي:

- إذا قبل الموعد النهائي: `تسليم الواجب` أو `إعادة التسليم`.
- إذا الموعد انتهى: زر Disabled مع نص `انتهى موعد التسليم`.

---

## 4.3 Submit Sheet / Screen

عناصر الإدخال:

- TextField للإجابة النصية.
- مرفقات صور (multiple).
- مرفقات ملفات (multiple).

Validation محلي قبل `POST`:

1. `text.trim()`
2. لو النص فارغ والصور فارغة والملفات فارغة -> امنع الإرسال مع رسالة واضحة.
3. أثناء الإرسال: Disable للزر + Loading.

بعد نجاح الإرسال:

- Toast نجاح.
- إعادة تحميل تفاصيل الواجب + القائمة.
- العودة للشاشة السابقة أو تحديث `my_submission` مباشرة.

---

## 5) State Management (اقتراح)

يمكن باستخدام Bloc / Cubit / Riverpod (أي نمط متفق عليه)، لكن يلزم نفس الحالات:

- `Idle`
- `LoadingList`
- `ListLoaded`
- `LoadingDetails`
- `DetailsLoaded`
- `UploadingAttachment`
- `Submitting`
- `SubmitSuccess`
- `Error(message)`

مهم: فصل State الرفع عن State الإرسال حتى لا يختلط progress الرفع مع progress التسليم.

---

## 6) Error Handling المطلوب

### HTTP 400

- غير مشترك في الكورس.
- لا يوجد محتوى إجابة.
- انتهى موعد التسليم.

**UI Action:** Show message من السيرفر كما هي.

### HTTP 401

- Token منتهي/غير صالح.

**UI Action:** Logout + الذهاب لشاشة تسجيل الدخول.

### HTTP 404

- الواجب غير موجود.

**UI Action:** شاشة Not Found + رجوع.

### Network error / timeout

**UI Action:** Retry button + الحفاظ على المدخلات الحالية.

---

## 7) Business Rules ملخص سريع

1. لا يمكن عرض/تسليم الواجب إلا لطالب مشترك بخطة نشطة.
2. التسليم مسموح حتى `due_date` فقط.
3. يمكن إعادة التسليم قبل `due_date` (آخر تسليم هو المعتمد).
4. التصحيح يتم من لوحة الإدارة، والطالب يشاهد:
   - `status`
   - `score`
   - `teacher_note`

---

## 8) DTOs مقترحة داخل Flutter

```dart
class AssignmentItem {
  final String id;
  final String title;
  final String description;
  final String? sourceImageUrl;
  final String? sourceFileUrl;
  final DateTime? dueDate;
  final int totalPoints;
  final int questionsCount;
  final AssignmentSubmissionLite? submission;
}

class AssignmentSubmissionLite {
  final String id;
  final String status; // submitted|reviewed|accepted|rejected
  final double? score;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
}

class SubmitAssignmentRequest {
  final String answerText;
  final List<String> answerImages;
  final List<String> answerFiles;
}
```

---

## 9) Checklist التسليم لفريق Flutter

- [ ] Assignment list endpoint مربوط.
- [ ] Assignment details endpoint مربوط.
- [ ] Upload endpoint مربوط قبل submit.
- [ ] Local validation قبل submit مفعّل.
- [ ] التعامل مع deadline (disable submit) مفعّل.
- [ ] Resubmission flow مفعّل.
- [ ] Error handling (400/401/404/network) مفعّل.
- [ ] عرض status/score/teacher_note بعد المراجعة مفعّل.
