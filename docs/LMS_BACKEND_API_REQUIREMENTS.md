# LMS Backend API Requirements (Multi-Instructor Platform)

## Purpose

This document summarizes:

1. What is already available in the Flutter app.
2. What is missing and requires backend support.
3. API contracts needed to complete the requested LMS scope.

Base URL assumption: `/api`
Response envelope assumption:

```json
{
  "success": true,
  "message": "OK",
  "data": {}
}
```

---

## A) Current Status vs Requirement

## Already available (app side, partially integrated)

- Course/category browsing, course details, pricing/checkout flow.
- Course hierarchy rendering (module/submodule/lesson style content).
- Lesson blocks: video/audio/images/files/pdf links.
- Assignments and exams UI flows.
- Student progress/certificates/notifications.
- Instructor/admin screens and some dashboard endpoints.
- Basic screenshot/recording prevention in app runtime.

## Missing or incomplete (requires backend contract clarity)

- Stable exams list endpoint for course returns `Invalid data provided` in some courses.
- Full subscription lifecycle and entitlement logic (duration modes, renew, expiry actions).
- Device/session management APIs (allowed device count/type + active sessions).
- Live session join + provider metadata (Zoom details normalization).
- Scheduling/re-scheduling for course content with notifications/email/calendar hooks.
- Watermark policy per lesson/video and per user.
- Analytics KPIs complete schema for admin/instructor.
- Multi-instructor management at course level (ownership, permissions, role per instructor).
- Payment provider finalization webhooks and reconciliation.

---

## B) Critical Fix Needed Now

## 1) Course Exams List (Blocking)

- **Endpoint**: `GET /api/courses/{courseId}/exams`
- **Current issue**: returns:
  - `success: false`
  - `message: "Invalid data provided"`
    for valid course IDs.

### Expected behavior

- Return `200` with `success: true` and list of exams for enrolled/eligible student.
- If no exams: return empty list, not invalid-data error.

### Expected response (example)

```json
{
  "success": true,
  "message": "Exams fetched",
  "data": [
    {
      "id": "exam_uuid",
      "course_id": "course_uuid",
      "title": "Midterm Exam",
      "description": "Exam description",
      "type": "exam",
      "questions_count": 20,
      "duration_minutes": 30,
      "passing_score": 60,
      "max_attempts": 3,
      "attempts_used": 1,
      "can_start": true,
      "is_passed": false,
      "best_score": 45
    }
  ]
}
```

### Error semantics required

- `401`: unauthorized token
- `403`: not enrolled/not allowed
- `404`: course not found
- `200 + []`: course exists but no exams

---

## C) Required API Contracts by Feature

## 1) Multi-Instructor Course Management

- `GET /admin/courses/{courseId}/instructors`
- `POST /admin/courses/{courseId}/instructors`
- `PATCH /admin/courses/{courseId}/instructors/{instructorId}`
- `DELETE /admin/courses/{courseId}/instructors/{instructorId}`

Required fields:

- `role_in_course` (`owner`, `co_instructor`, `assistant`)
- permissions matrix (`can_edit_curriculum`, `can_manage_students`, `can_view_revenue`, ...)

---

## 2) Subscription Plans + Entitlement Logic

- `GET /courses/{courseId}/plans`
- `POST /admin/courses/{courseId}/plans`
- `PATCH /admin/courses/{courseId}/plans/{planId}`
- `DELETE /admin/courses/{courseId}/plans/{planId}`

Plan fields:

- `title`
- `price`
- `currency`
- `duration_type` (`fixed_date` | `rolling_duration` | `until_course_end`)
- `duration_value` (days/months) when rolling
- `expires_at` when fixed date
- `is_active`

Student subscription endpoints:

- `GET /me/subscriptions`
- `GET /me/subscriptions/{subscriptionId}`
- `POST /subscriptions/{subscriptionId}/renew`

Entitlement check endpoint:

- `GET /courses/{courseId}/entitlement`

Expected entitlement payload:

```json
{
  "has_access": true,
  "plan_id": "plan_uuid",
  "started_at": "2026-04-14T10:00:00Z",
  "expires_at": "2026-07-14T10:00:00Z",
  "days_left": 91,
  "status": "active"
}
```

---

## 3) Payments (Egypt + International)

Create payment intent/order:

- `POST /payments/checkout`

Provider callback/webhook:

- `POST /payments/webhooks/{provider}`

Verify payment:

- `POST /payments/{paymentId}/verify`

Manual enrollment by admin/instructor:

- `POST /admin/enrollments/manual`

Providers metadata endpoint:

- `GET /payments/providers`

Support unified metadata for:

- `stripe`, `paymob`, `fawry`, `instapay`, `wallet`, `bank_transfer`, `visa_mastercard`

---

## 4) Device and Session Control

- `GET /auth/sessions`
- `DELETE /auth/sessions/{sessionId}` (logout specific device)
- `POST /auth/sessions/revoke-all`
- `GET /users/{userId}/device-policy`
- `PATCH /users/{userId}/device-policy`

Policy fields:

- `max_devices`
- `allowed_device_types` (`mobile`, `tablet`, `desktop`)
- `allow_concurrent_sessions` (bool)

---

## 5) Scheduling and Re-Scheduling Content

- `POST /admin/courses/{courseId}/schedule`
- `PATCH /admin/courses/{courseId}/schedule`
- `POST /admin/courses/{courseId}/schedule/rebuild` (re-release old course by new timeline)
- `GET /courses/{courseId}/schedule`

Lesson visibility model required:

- `visible_from`
- `visible_until` (optional)
- `is_locked`
- `unlock_rule`

---

## 6) Notifications + Calendar + Email Hooks

- `POST /notifications/schedule`
- `POST /calendar/google/connect`
- `POST /calendar/google/disconnect`
- `POST /calendar/google/sync`
- `POST /emails/dispatch`

Trigger events needed:

- lesson published
- live session reminder (T-24h, T-1h, T-15m)
- subscription expiring
- subscription expired

---

## 7) Live Sessions (Zoom-normalized contract)

- `GET /live-courses`
- `POST /live-courses/{sessionId}/register`
- `GET /live-courses/{sessionId}/join`

Join payload should include normalized fields:

- `provider` (`zoom`, `custom`)
- `join_url`
- `meeting_id` (optional)
- `passcode` (optional)
- `starts_at`
- `ends_at`
- `is_live_now`

---

## 8) Lesson Security Policy (Watermark/Download/Screen rules)

- `GET /courses/{courseId}/lessons/{lessonId}/access-policy`

Policy payload:

```json
{
  "allow_download": false,
  "allow_screen_capture": false,
  "allow_recording": false,
  "watermark": {
    "enabled": true,
    "mode": "dynamic",
    "fields": ["user_name", "email", "timestamp"]
  }
}
```

---

## 9) Notes and Bookmarks

- `GET /courses/{courseId}/lessons/{lessonId}/notes`
- `POST /courses/{courseId}/lessons/{lessonId}/notes`
- `PATCH /notes/{noteId}`
- `DELETE /notes/{noteId}`

- `GET /courses/{courseId}/bookmarks`
- `POST /courses/{courseId}/bookmarks`
- `DELETE /courses/{courseId}/bookmarks/{bookmarkId}`

---

## 10) Analytics

- `GET /admin/analytics/overview`
- `GET /admin/analytics/courses/{courseId}`
- `GET /admin/analytics/assessments/{courseId}`

Required KPIs:

- enrollments, active learners
- completion rate
- lesson watch time
- assignment/exam performance
- retention and churn

---

## D) Data Contract Clarifications Needed

To reduce Flutter-side fallback logic, backend should standardize:

- List responses always as arrays in `data`.
- Consistent keys:
  - `questions_count`, `duration_minutes`, `can_start`, `attempts_used`.
- Consistent error handling:
  - use `errors` object with field-level issues for `422`.
- No `Invalid data provided` for valid empty states.

---

## E) Acceptance Checklist for Backend Team

- [ ] `GET /courses/{courseId}/exams` fixed for valid course IDs.
- [ ] Subscription plans support all duration modes.
- [ ] Entitlement endpoint implemented and used for course locking.
- [ ] Payment provider lifecycle and webhooks finalized.
- [ ] Device/session management endpoints delivered.
- [ ] Scheduling + rescheduling content APIs delivered.
- [ ] Live sessions join payload normalized.
- [ ] Access policy endpoint for lesson security delivered.
- [ ] Notes/bookmarks endpoints delivered.
- [ ] Analytics KPI endpoints delivered.

---

## F) Notes for Integration

- Flutter app already calls these exam endpoints:
  - `GET /api/courses/{courseId}/exams`
  - `GET /api/courses/{courseId}/exams/{examId}`
  - `POST /api/courses/{courseId}/exams/{examId}/start`
  - `POST /api/courses/{courseId}/exams/{examId}/submit`
- Priority blocker at the moment is the list endpoint behavior for some courses.
