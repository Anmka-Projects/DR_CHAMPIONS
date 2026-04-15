# Flutter Exams API Guide

Base URL:

- `https://drchampions-academy.anmka.com/api`

Auth:

- For protected endpoints, send:
  - `Authorization: Bearer <access_token>`
  - `Accept: application/json`
  - `Content-Type: application/json` (for POST)

---

## 1) Get Course Exams

- **Method:** `GET`
- **URL:** `/courses/{courseId}/exams`
- **Auth:** optional (recommended to send token for `attempts_used`, `best_score`, `is_passed`, `can_start`)

### Example

`GET /api/courses/9452f0a9-c0c2-4be1-b3f0-36ddf743200a/exams`

### Success Response (200)

```json
{
  "data": [
    {
      "id": "b6c4fea9-794e-4bfd-8ed1-a844263f773f",
      "title": "teeeeeeeeeeesssssssssssst",
      "description": "",
      "course_id": "9452f0a9-c0c2-4be1-b3f0-36ddf743200a",
      "course_name": "Test Course",
      "questions_count": 0,
      "duration_minutes": 60,
      "passing_score": 70,
      "max_attempts": 3,
      "attempts_used": 0,
      "best_score": null,
      "is_passed": false,
      "can_start": true,
      "created_at": "2026-04-14T09:42:51.698Z"
    }
  ],
  "success": true
}
```

### Not Found (404)

```json
{
  "success": false,
  "message": "الدورة غير موجودة"
}
```

---

## 2) Get Exam Details

- **Method:** `GET`
- **URL:** `/courses/{courseId}/exams/{examId}`
- **Auth:** optional

### Example

`GET /api/courses/{courseId}/exams/{examId}`

### Success Response (200)

- Returns exam metadata + questions (without exposing correct answers for students).

### Not Found (404)

```json
{
  "success": false,
  "message": "الامتحان غير موجود"
}
```

---

## 3) Start Exam

- **Method:** `POST`
- **URL:** `/courses/{courseId}/exams/{examId}/start`
- **Auth:** required

### Example

`POST /api/courses/{courseId}/exams/{examId}/start`

Body:

```json
{}
```

### Success Response (200)

- Returns new attempt data (attempt id and exam payload used by submit).

### Error Response (400)

```json
{
  "success": false,
  "message": "فشل في بدء الامتحان"
}
```

---

## 4) Submit Exam

- **Method:** `POST`
- **URL:** `/courses/{courseId}/exams/{examId}/submit`
- **Auth:** required

### Required Body

```json
{
  "attempt_id": "attempt-uuid",
  "answers": [
    {
      "question_id": "question-uuid",
      "answer": "A"
    }
  ]
}
```

### Success Response (200)

- Returns final result: score, percentage, pass/fail, and attempt summary.

### Validation Error (400)

```json
{
  "success": false,
  "message": "attempt_id و answers مطلوبان"
}
```

---

## 5) Get My Exam Results

- **Method:** `GET`
- **URL:** `/my-exam-results`
- **Auth:** required

### Optional Query Params

- `page` (default `1`)
- `per_page` (default `20`)
- `course_id`
- `is_passed` (`true` or `false`)

### Example

`GET /api/my-exam-results?page=1&per_page=20&course_id={courseId}&is_passed=true`

---

## Standard Error Shape

Most API errors return:

```json
{
  "data": null,
  "success": false,
  "message": "Error message",
  "errors": {}
}
```

---

## Flutter Notes (Important)

- Always log:
  - URL
  - method
  - headers
  - response status code
  - full response body
- If token exists, send `Authorization: Bearer <token>` exactly once.
- Use same `courseId` and `examId` from list endpoint response.
- If you get `Invalid data provided`, retry once after refreshing token, then log full body and status.
