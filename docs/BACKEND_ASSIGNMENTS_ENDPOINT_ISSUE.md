# Backend Handoff: Course Assignments Endpoint Issue

## Issue Summary

In the Flutter app, assignments inside course **"Test Course"** are not loading.

The app calls:

- `GET /api/courses/{courseId}/assignments`

Example:

- `GET /api/courses/9452f0a9-c0c2-4be1-b3f0-36ddf743200a/assignments`

Current behavior from production:

- Returns **HTTP 404**
- Response body is **HTML (Next.js 404 page)**, not JSON

This indicates the request is not being handled by an API route for assignments (or proxy/routing is forwarding to frontend fallback).

---

## Expected Contract (Student Assignments)

As agreed in `docs/FLUTTER_ASSIGNMENT_STUDENT_LOGIC.md`, backend should provide:

1. `GET /api/courses/{courseId}/assignments`
2. `GET /api/courses/{courseId}/assignments/{assignmentId}`
3. `POST /api/courses/{courseId}/assignments/{assignmentId}/submit`
4. `GET /api/my-assignment-submissions?page=1&per_page=20&course_id={optional}`

All endpoints require:

- `Authorization: Bearer <token>`
- Student enrolled in course with active plan

---

## Required Response Shape

### 1) List endpoint

`GET /api/courses/{courseId}/assignments`

Success example:

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Assignment title",
      "description": "text",
      "source_image_url": "https://.../image.jpg",
      "source_file_url": "https://.../file.pdf",
      "due_date": "2026-04-20T23:59:59.000Z",
      "total_points": 100,
      "questions_count": 3,
      "submission": null
    }
  ]
}
```

### 2) Details endpoint

`GET /api/courses/{courseId}/assignments/{assignmentId}`

Should include:

- assignment base fields
- `questions[]`
- `my_submission` (null if no submission yet)

### 3) Submit endpoint

`POST /api/courses/{courseId}/assignments/{assignmentId}/submit`

Body:

```json
{
  "answer_text": "optional text",
  "answer_images": ["/uploads/images/file.jpg"],
  "answer_files": ["/uploads/documents/file.pdf"]
}
```

Validation rules:

- At least one of text/images/files must be provided
- Reject after `due_date`
- Supports first submit and resubmit (upsert behavior)

---

## Error Handling Requirements

Return JSON errors (not HTML):

- `400`: enrollment/plan invalid, empty submission, deadline passed
- `401`: invalid/expired token
- `404`: assignment not found

Recommended JSON error format:

```json
{
  "success": false,
  "message": "Human readable error message"
}
```

---

## Infrastructure / Routing Check

Please verify deployment/proxy rules so `/api/...` assignment routes are handled by backend API service and not frontend Next.js fallback.

Specifically confirm route registration for:

- `/api/courses/:courseId/assignments`
- `/api/courses/:courseId/assignments/:assignmentId`
- `/api/courses/:courseId/assignments/:assignmentId/submit`
- `/api/my-assignment-submissions`

---

## Why This Blocks Flutter

Flutter currently uses the correct documented route:

- `/api/courses/{courseId}/assignments`

Because backend returns a frontend HTML 404 page, the app cannot parse assignment data and cannot show assignment items for the course.

