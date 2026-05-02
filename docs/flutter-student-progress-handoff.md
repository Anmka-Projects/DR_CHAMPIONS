# Flutter Handoff: Student Progress Tracking

Use this document to integrate course progress tracking between backend and Flutter app.

## 1) Get Student Course Progress List

- Method: `GET`
- URL: `/api/enrollments`
- Auth: `Bearer <student_token>`

### Optional Query Params

- `status`: `all` | `in_progress` | `completed`
- `page`: number (default `1`)
- `per_page`: number (default `20`)

### Example

`GET /api/enrollments?status=all&page=1&per_page=20`

### Response fields you need in Flutter

For each enrollment item:

- `course.id`
- `course.title`
- `progress` (0-100)
- `completed_lessons`
- `total_lessons`
- `status` (`in_progress` or `completed`)

---

## 2) Update Progress When Student Finishes/Watches Lesson

- Method: `POST`
- URL: `/api/courses/:courseId/lessons/:lessonId/progress`
- Auth: `Bearer <student_token>`

### Body

```json
{
  "watched_seconds": 480,
  "is_completed": true
}
```

### Response (important)

- `lesson_progress` (lesson-level tracking)
- `course_progress.percentage` (course-level progress after update)
- `course_progress.completed_lessons`
- `course_progress.total_lessons`

Use this response to update UI immediately without waiting for another fetch.

---

## 3) Get Overall Student Progress Summary (Optional Dashboard Widget)

- Method: `GET`
- URL: `/api/progress`
- Auth: `Bearer <student_token>`

### Optional Query Params

- `period`: `weekly` or `monthly`

### Example

`GET /api/progress?period=weekly`

This endpoint is useful for progress cards/charts, streak, watched time summaries.

---

## 4) Admin/Instructor: Track Students Progress in a Specific Course

If you want to see "each student reached where in this course" in admin/instructor tools:

- Method: `GET`
- URL: `/api/admin/courses/:courseId/statistics`
- Auth: admin/instructor token

### Optional Query Params

- `sortBy`: `alphabetical` | `login_time` | `exam_score` | `video_progress`
- `filterBy`: `enrolled_only` | `completed_exam` | `watched_video`
- `search`
- `page`
- `limit`

### Key response field

- `enrolledStudents[]` with:
  - `userId`
  - `userName`
  - `enrolledAt`
  - `lastActiveAt`
  - `videosWatched`
  - `examsCompleted`

---

## Flutter Integration Rules

1. After every lesson completion, call progress update endpoint.
2. Refresh `/api/enrollments` after update or use returned `course_progress` directly.
3. Show completion state when `progress === 100`.
4. Handle empty, loading, and error states gracefully.

---

## Minimal Flow

1. Student opens "My Courses" -> call `GET /api/enrollments`.
2. Student watches lesson -> call `POST /api/courses/:courseId/lessons/:lessonId/progress`.
3. Update progress bar using response.
4. On next open, fetch enrollments again for server-confirmed progress.
