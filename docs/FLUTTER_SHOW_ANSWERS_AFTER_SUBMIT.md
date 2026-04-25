# Flutter — عرض إجابة الطالب + الإجابة الصحيحة بعد الـ Submit

**Site:** `drchampions-academy.anmka.com`
**Endpoint:** `POST /api/courses/:courseId/exams/:examId/submit`
**الحالة:** ✅ **مُختبر على الـ server فعلًا بحساب طالب حقيقي (23 أبريل 2026).**

---

## 1. هدف المستند

عرّف فريق Flutter على شكل **`questions_review`** الفعلي اللي بيرجع بعد ما الطالب يضغط "تسليم"، وازاي يرسم منه شاشة النتيجة (إجابة الطالب + الإجابة الصحيحة + الشرح) لكل نوع سؤال.

كل الأمثلة في المستند ده مأخوذة من تسليم حقيقي للامتحان `essential test 1`.

---

## 2. نموذج كامل لاستجابة `submit` (Verified)

تسليم فيه 3 أسئلة:

| #   | نوع السؤال                    | ما بعته الطالب                         | النتيجة           |
| --- | ----------------------------- | -------------------------------------- | ----------------- |
| 1   | `true_false` "الأرض كوكب"     | `selected_options: ["true"]`           | ✅ صح             |
| 2   | `multiple_choice` "2 + 3 = ؟" | `selected_options: ["opt_1"]` (أي "3") | ❌ غلط — الصح "5" |
| 3   | `multiple_choice` بدون إجابة  | `selected_options: []`                 | ❌ غلط — لم يُجب  |

الـ response الحقيقي:

```json
{
  "success": true,
  "data": {
    "attempt_id": "dbb300ac-40fe-46b4-a6b7-f088e99bde72",
    "score": 1,
    "percentage": 33.33,
    "passing_score": 60,
    "is_passed": false,
    "correct_answers": 1,
    "total_questions": 3,
    "time_taken_minutes": 0,
    "certificate_unlocked": false,
    "message": "لم تجتز الامتحان. النتيجة: 33% (المطلوب: 60%)",

    "questions_review": [
      {
        "question_id": "bc25b4ec-f391-45d4-84de-91ec512a558f",
        "order": 0,
        "question_text": "الأرض كوكب",
        "question_type": "true_false",
        "options": [],
        "explanation": "معلومة عامة",
        "points_total": 1,
        "points_earned": 1,
        "is_correct": true,
        "is_answered": true,
        "user_answer": [{ "index": null, "text": "true" }],
        "correct_answer": [{ "index": null, "text": "true" }]
      },
      {
        "question_id": "1dcc9f43-78e3-4525-9b24-ba5c7f8e9894",
        "order": 1,
        "question_text": "2 + 3 = ؟",
        "question_type": "multiple_choice",
        "options": [
          { "id": "opt_0", "text": "1" },
          { "id": "opt_1", "text": "3" },
          { "id": "opt_2", "text": "5" },
          { "id": "opt_3", "text": "7" }
        ],
        "explanation": "2+3=5",
        "points_total": 1,
        "points_earned": 0,
        "is_correct": false,
        "is_answered": true,
        "user_answer": [{ "index": 1, "text": "3" }],
        "correct_answer": [{ "index": 2, "text": "5" }]
      },
      {
        "question_id": "23df4a95-8cec-43c0-bbeb-be6efbabdfe1",
        "order": 2,
        "question_text": "465465465465465",
        "question_type": "multiple_choice",
        "options": [
          { "id": "opt_0", "text": "" },
          { "id": "opt_1", "text": "" },
          { "id": "opt_2", "text": "" },
          { "id": "opt_3", "text": "" }
        ],
        "explanation": "…",
        "points_total": 1,
        "points_earned": 0,
        "is_correct": false,
        "is_answered": false,
        "user_answer": [],
        "correct_answer": [{ "index": null, "text": "645454654" }]
      }
    ]
  }
}
```

---

## 3. كل حقل يعني إيه

| الحقل                            | النوع                 | الاستخدام                                                                  |
| -------------------------------- | --------------------- | -------------------------------------------------------------------------- |
| `question_id`                    | `String`              | مفتاح السؤال — استخدمه كـ Key في الـ List.                                 |
| `order`                          | `int`                 | ترتيب العرض.                                                               |
| `question_text`                  | `String`              | نص السؤال.                                                                 |
| `question_type`                  | `String`              | `multiple_choice` \| `true_false` \| `text`. يحدد طريقة الرسم.             |
| `options`                        | `List<{id,text}>`     | خيارات MCQ (دايمًا `[]` للـ true_false والنصي).                            |
| `user_answer`                    | `List<{index, text}>` | إجابة الطالب للـ MCQ و TF. `[]` لو ما ردش.                                 |
| `correct_answer`                 | `List<{index, text}>` | الإجابة الصحيحة (قد تحتوي على عنصر واحد أو أكتر لو multi-select مستقبلًا). |
| `user_answer_text`               | `String?`             | إجابة الطالب للأسئلة النصية فقط.                                           |
| `correct_answer_text`            | `String?`             | الإجابة الصحيحة للأسئلة النصية فقط.                                        |
| `is_correct`                     | `bool`                | الطالب جاوب صح ولا غلط.                                                    |
| `is_answered`                    | `bool`                | هل ردّ أصلًا على السؤال.                                                   |
| `points_earned` / `points_total` | `int` / `int`         | نقاط السؤال.                                                               |
| `explanation`                    | `String?`             | الشرح التفصيلي — ممكن يكون `null` لو الأستاذ ما كتبش شرح.                  |

### قواعد مهمة عن `user_answer` / `correct_answer`

- **`index`** = رقم الخيار داخل `options` (0-based). استخدمه مباشرة لتحديد أي خيار تضيف له إطار أخضر/أحمر.
- **`text`** = نص الخيار كما يجب أن يظهر للطالب. استخدمه لو `index = null` (مثل الـ true_false).
- **الـ Array غالبًا هيكون فيه عنصر واحد** للـ MCQ و TF الحالية، لكن Flutter يتعامل مع Array عشان مرونة مستقبلية.

---

## 4. مخطط الرسم لكل نوع سؤال

### 4.1 `multiple_choice`

لكل خيار في `options[i]`:

```
if (i == correct_answer[0].index)          → إطار/خلفية أخضر + ✓
else if (i == user_answer[0]?.index && !is_correct) → إطار/خلفية أحمر + ✗ "إجابتك"
else                                        → شكل عادي
```

### 4.2 `true_false`

- ارسم زرّين "صح" / "خطأ" محليًا (الـ API مبيرجعش options).
- صح = `text == "true"` / خطأ = `text == "false"`.
- لوّن حسب `user_answer[0].text` و `correct_answer[0].text`.

### 4.3 `text`

- اعرض صندوقين:
  - **إجابتك:** `user_answer_text` (أو "لم تُجب" لو `null/فاضي`).
  - **الإجابة الصحيحة:** `correct_answer_text`.
- لوّن الأول أخضر لو `is_correct`، أحمر لو لا.

### شريط الشرح (كل الأنواع)

```dart
if (q.explanation != null && q.explanation!.trim().isNotEmpty) {
  // Card بخلفية فاتحة، عنوان "شرح الإجابة" ونص الشرح
}
```

---

## 5. Widget مختصر جاهز (Dart)

```dart
Widget buildReviewCard(QuestionReview q) {
  Widget body;
  switch (q.questionType) {
    case 'multiple_choice':
      final correctIdx = q.correctAnswer.isNotEmpty ? q.correctAnswer.first.index : null;
      final userIdx    = q.userAnswer.isNotEmpty   ? q.userAnswer.first.index   : null;
      body = Column(
        children: List.generate(q.options.length, (i) {
          Color? bg;
          IconData? icon;
          if (i == correctIdx)                          { bg = Colors.green.shade50; icon = Icons.check_circle; }
          else if (i == userIdx && !q.isCorrect)        { bg = Colors.red.shade50;   icon = Icons.cancel; }
          return Container(
            color: bg,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              if (icon != null) Icon(icon, color: i == correctIdx ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(q.options[i].text)),
            ]),
          );
        }),
      );
      break;

    case 'true_false':
      final ua = q.userAnswer.isNotEmpty    ? q.userAnswer.first.text    : null;
      final ca = q.correctAnswer.isNotEmpty ? q.correctAnswer.first.text : null;
      body = Row(children: [
        _tfChip('صح',  selected: ua == 'true',  isCorrect: ca == 'true'),
        const SizedBox(width: 8),
        _tfChip('خطأ', selected: ua == 'false', isCorrect: ca == 'false'),
      ]);
      break;

    default: // text
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _labeled('إجابتك',        q.userAnswerText?.isNotEmpty == true ? q.userAnswerText! : 'لم تُجب',
                 bg: q.isCorrect ? Colors.green.shade50 : Colors.red.shade50),
        const SizedBox(height: 8),
        _labeled('الإجابة الصحيحة', q.correctAnswerText ?? '—',
                 bg: Colors.green.shade50),
      ]);
  }

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(q.isCorrect ? Icons.check_circle : Icons.cancel,
               color: q.isCorrect ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text('سؤال ${q.order + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold))),
          Text('${q.pointsEarned}/${q.pointsTotal}'),
        ]),
        const SizedBox(height: 8),
        Text(q.questionText, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        body,
        if ((q.explanation ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('شرح الإجابة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(q.explanation!),
            ]),
          ),
        ],
      ]),
    ),
  );
}

Widget _tfChip(String label, {required bool selected, required bool isCorrect}) {
  final bg = isCorrect ? Colors.green.shade50
             : (selected ? Colors.red.shade50 : null);
  final fg = isCorrect ? Colors.green
             : (selected ? Colors.red : Colors.grey);
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: fg),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isCorrect ? Icons.check : (selected ? Icons.close : Icons.circle_outlined),
             color: fg, size: 18),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

Widget _labeled(String label, String value, {Color? bg}) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
  ]),
);
```

---

## 6. Parsing سريع

```dart
class AnswerChoice {
  final int?    index;
  final String? text;
  AnswerChoice.fromJson(Map<String, dynamic> j)
      : index = j['index'] as int?,
        text  = j['text']  as String?;
}

class QuestionReview {
  final String questionId;
  final int    order;
  final String questionText;
  final String questionType;
  final List<QuestionOption> options;
  final List<AnswerChoice> userAnswer;
  final List<AnswerChoice> correctAnswer;
  final String? userAnswerText;
  final String? correctAnswerText;
  final bool    isCorrect;
  final bool    isAnswered;
  final int     pointsEarned;
  final int     pointsTotal;
  final String? explanation;

  QuestionReview.fromJson(Map<String, dynamic> j)
      : questionId        = j['question_id']   as String,
        order             = (j['order'] ?? 0)  as int,
        questionText      = (j['question_text'] ?? '') as String,
        questionType      = (j['question_type'] ?? 'text') as String,
        options           = ((j['options'] ?? []) as List)
            .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        userAnswer        = ((j['user_answer']    ?? []) as List)
            .map((e) => AnswerChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        correctAnswer     = ((j['correct_answer'] ?? []) as List)
            .map((e) => AnswerChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        userAnswerText    = j['user_answer_text']    as String?,
        correctAnswerText = j['correct_answer_text'] as String?,
        isCorrect         = j['is_correct']  == true,
        isAnswered        = j['is_answered'] == true,
        pointsEarned      = (j['points_earned'] ?? 0) as int,
        pointsTotal       = (j['points_total']  ?? 0) as int,
        explanation       = j['explanation'] as String?;
}

class QuestionOption {
  final String id;
  final String text;
  QuestionOption.fromJson(Map<String, dynamic> j)
      : id   = j['id']   as String,
        text = (j['text'] ?? '') as String;
}
```

---

## 7. قائمة التحقق للـ QA

بعد أي تسليم، تأكدوا من:

- ✅ `questions_review.length == total_questions`
- ✅ لكل سؤال MCQ المجاب: `user_answer.first.index` داخل نطاق `options.length`
- ✅ لكل سؤال MCQ الصح: `correct_answer.first.index` داخل نطاق `options.length`
- ✅ `is_correct == true` فقط لما `user_answer` == `correct_answer`
- ✅ سؤال ما اتردش عليه → `user_answer == []` و `is_answered == false`
- ✅ للـ true_false: `index == null` و `text == "true" \| "false"`

---

## 8. ملاحظة على بيانات قديمة

لو لقيتم سؤال `correct_answer: [{ "index": null, "text": "..." }]` في MCQ، ده يعني إن الـ correct answer القديم في قاعدة البيانات مش مطابق لأي خيار (بيانات سيئة في Data Bank). اعرضوه كـ "الإجابة الصحيحة: {text}" من غير تظليل أي خيار، وده النادر.

---

**نهاية المستند.** الأمثلة في Section 2 **فعليًا نتيجة تسليم حقيقي**، مش مُفترضة — فريق Flutter ممكن يعتمد عليها كـ contract ويبني الـ UI مباشرةً.
