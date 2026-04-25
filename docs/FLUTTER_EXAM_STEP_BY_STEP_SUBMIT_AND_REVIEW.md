# Flutter + Backend Contract — Exam Step-by-Step Submit & Review

## Requested UX Flow

After student starts exam:

1. Student answers current question.
2. Student taps **Submit Answer** (per question, not full exam).
3. UI immediately shows:
   - answer status: **Correct / Wrong**
   - explanation (if present)
4. Then UI shows **Next** button to move to next question.
5. On last question, button becomes **Finish Exam**.
6. After finishing, show full exam result summary + detailed review.

---

## Backend APIs Needed

## 1) Per-question submit/check endpoint (new)

- `POST /api/courses/:courseId/exams/:examId/attempts/:attemptId/questions/:questionId/submit`

Request body (example):

```json
{
  "answer": "opt_2",
  "selected_options": ["opt_2"],
  "answer_text": null
}
```

Response body (example):

```json
{
  "success": true,
  "data": {
    "question_id": "1dcc9f43-78e3-4525-9b24-ba5c7f8e9894",
    "is_answered": true,
    "is_correct": false,
    "user_answer": [{ "index": 1, "text": "3" }],
    "correct_answer": [{ "index": 2, "text": "5" }],
    "explanation": "2+3=5",
    "answer_explanation": null,
    "feedback": null,
    "points_earned": 0,
    "points_total": 1,
    "can_go_next": true,
    "is_last_question": false
  }
}
```

Notes:

- Must support `multiple_choice`, `true_false`, `text`.
- `user_answer` / `correct_answer` should always be array shape for consistency.
- Explanation key policy:
  - Preferred key: `explanation`
  - Optional aliases (legacy-compatible): `answer_explanation`, `feedback`, `solution`
  - Flutter uses first non-empty value from these keys.
- `can_go_next` controls enabling Next/Finish on client.
- `is_last_question` helps client switch button label to Finish.

---

## 2) Final exam submit endpoint (existing)

- `POST /api/courses/:courseId/exams/:examId/submit`

Must still return:

- `score` / `percentage`
- `is_passed`
- `correct_answers`
- `total_questions`
- `message`
- `questions_review` (full detailed review list)

For each `questions_review` item:

- include `explanation` when available (same fallback aliases are acceptable for legacy).

---

## UI Mapping (Flutter)

- During exam:
  - disable editing question after per-question submit.
  - show inline status card (correct/wrong + explanation if found).
  - show Next.
- Last question:
  - show Finish Exam.
- Final result page:
  - show summary + detailed question review.

---

## QA Checklist

1. Submit first question => status appears immediately.
2. Explanation appears when available.
3. Next button appears only after submit current question.
4. Last question button is Finish Exam.
5. Final result includes full `questions_review`.
6. Unanswered questions are handled correctly (`is_answered=false`).
