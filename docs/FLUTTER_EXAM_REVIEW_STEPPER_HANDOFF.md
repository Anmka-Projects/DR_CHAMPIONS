# Flutter/Backend Handoff — Step-by-Step Exam Review After Submit

## Goal

After student submits an exam:

1. Student sees result summary.
2. Student sees **one reviewed question at a time**.
3. Student clicks **Next** to move to the next reviewed question.
4. On last reviewed question, button becomes **Finish**.

This creates guided review instead of showing all questions at once.

---

## Required Backend Response (Submit Endpoint)

Endpoint:

- `POST /api/courses/:courseId/exams/:examId/submit`

Required fields in response `data`:

- `score` or `percentage`
- `is_passed`
- `correct_answers`
- `total_questions`
- `message`
- `questions_review` (ordered question review list)

`questions_review` item fields (required/strongly recommended):

- `question_id` (string)
- `order` (int) - stable display order
- `question_text` (string)
- `question_type` (`multiple_choice` | `true_false` | `text`)
- `options` (array for MCQ, `[]` otherwise)
- `is_correct` (bool)
- `is_answered` (bool)
- `user_answer` (array of `{ index, text }`)
- `correct_answer` (array of `{ index, text }`)
- `user_answer_text` (string, for text questions)
- `correct_answer_text` (string, for text questions)
- `points_earned`, `points_total`
- `explanation` (nullable string)

---

## Contract Rules

1. `questions_review.length` should match `total_questions`.
2. `order` should be stable and unique per attempt.
3. For unanswered questions:
   - `is_answered = false`
   - `user_answer = []` (and/or empty `user_answer_text`)
4. For true/false:
   - Prefer `text: "true"` or `text: "false"` in `user_answer`/`correct_answer`.
5. For MCQ:
   - If possible provide valid `index` matching `options`.
   - If old/bad data exists, still provide `text` fallback.

---

## UI Behavior Implemented in Flutter

- Review cards render from `questions_review`.
- UI shows only one review card (`currentReviewIndex`) at a time.
- Button behavior:
  - if not last question: **Next Question**
  - if last question: **Finish**
- If `questions_review` is empty, screen falls back to summary + Finish.

---

## QA Checklist

1. Submit exam with at least 3 questions.
2. Verify summary appears.
3. Verify first reviewed question appears only.
4. Click Next:
   - should move to second question.
5. On last question:
   - button label is Finish.
   - finish closes result screen and returns submit payload.
6. Verify explanation appears only when non-empty.

