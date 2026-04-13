# Teacher Dashboard – Screen Structure & API Mapping

This document explains how the **Teacher Dashboard** works and maps each screen/section to its API endpoints (per `TEACHER_DASHBOARD_API.md`).

---

## How the Teacher Dashboard Works

1. **Authentication**: Teacher logs in and receives a Bearer token.
2. **Role-based data**: The same admin endpoints are used, but the backend filters data by the current user. Instructors only see their own courses, students, earnings, and attendance.
3. **Service layer**: `TeacherDashboardService` (`lib/services/teacher_dashboard_service.dart`) calls the API and returns data to screens.

---

## Screen → Endpoint Structure

### 1. Instructor Home Screen  
**File:** `lib/screens/instructor/instructor_home_screen.dart`  
**Route:** `/instructor`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| Profile (name, avatar) | `GET /api/auth/profile` | GET | `ProfileService.getProfile()` | `name`, `avatar` |
| Stats grid (طلابي، دوراتي، اشتراكات، المبيعات) | `GET /api/admin/dashboard/overview` | GET | `getDashboardOverview()` | `totalUsers`, `totalCourses`, `totalSubscriptions`, `totalRevenue`, `*Growth` |
| Recent activity (مدفوعات، تسجيلات) | `GET /api/admin/dashboard/activity` | GET | `getDashboardActivity()` | `recentPayments`, `recentEnrollments` |
| My courses list | `GET /api/admin/courses?instructorId=xxx` | GET | `getMyCourses()` | `data[]` (title, studentsCount, price, etc.) |
| Total sales calculation | `GET /api/admin/payments?status=completed` | GET | `getPayments()` | `data[]` (filter by courseId) |

---

### 2. Instructor Courses Screen  
**File:** `lib/screens/instructor/instructor_courses_screen.dart`  
**Route:** `/instructor/courses`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| Courses list | `GET /api/admin/courses?instructorId=xxx` | GET | `getMyCourses()` | `data[]`, `meta` |
| Course attendance (enrollments) | `GET /api/admin/attendance?action=course-enrollments&courseId=xxx` | GET | `getAttendance(courseId, action)` | Enrolled students per course |

---

### 3. Instructor Course Details Screen  
**File:** `lib/screens/instructor/instructor_course_details_screen.dart`  
**Route:** `/instructor/course-details`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| Course details (title, sections, lessons) | `GET /api/admin/courses/:id` | GET | `getCourseDetails(courseId)` | Full course + `sections[]`, `lessons[]`, `students[]` |
| Enrolled students list | Same response | — | — | `students[]` (name, email, progress, enrolledAt) |

---

### 4. Instructor Create Course Screen  
**File:** `lib/screens/instructor/instructor_create_course_screen.dart`  
**Route:** `/instructor/create-course`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| Create course form | `POST /api/admin/courses` | POST | `createCourse()` | Body: title, categoryId, instructorId, etc. |

---

### 5. Instructor Earnings Screen  
**File:** `lib/screens/instructor/instructor_earnings_screen.dart`  
**Route:** `/instructor/earnings`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| Overview stats | `GET /api/admin/dashboard/overview` | GET | `getDashboardOverview()` | `totalCourses`, `totalRevenue`, `totalSubscriptions` |
| Dashboard charts | `GET /api/admin/dashboard/charts` | GET | `getDashboardCharts()` | `usersGrowth[]`, `revenue[]`, `courseCompletion[]` |
| Monthly earnings chart | `GET /api/admin/payments` or charts.revenue | GET | `getPayments()` / charts | Monthly amounts |
| User earnings | `GET /api/admin/users/me/earnings` | GET | `getUsersMeEarnings()` | `totalEarnings`, `periodEarnings`, `byCourse` |
| My courses (for sales calc) | `GET /api/admin/courses?instructorId=xxx` | GET | `getMyCourses()` | Course IDs for filtering |
| Payments (for sales) | `GET /api/admin/payments?status=completed` | GET | `getPayments()` | Payments for teacher's courses |
| Salary settings | `GET /api/admin/teachers/me/salary-settings` | GET | `getMySalarySettings()` | `baseSalary`, `commissionType`, `commissionValue` |
| Calculate salary | `POST /api/admin/teachers/me/calculate-salary` | POST | `calculateMySalary()` | Body: startDate, endDate |
| Reports | `GET /api/admin/teachers/reports` | GET | `getReports()` | Teacher reports |

---

### 6. Instructor Profile Screen  
**File:** `lib/screens/instructor/instructor_profile_screen.dart`  
**Route:** `/instructor/profile`

| UI Section | Endpoint | Method | Service Method | Data Used |
|------------|----------|--------|----------------|-----------|
| My attendance (حضور المدرس) | `GET /api/attendance/my-attendance` | GET | `getMyAttendance()` | List of teacher's center attendance records |
| Profile (avatar) | `ProfileService` | GET | — | Avatar URL |

---

## Additional API Endpoints (Teacher Access)

| Endpoint | Method | Purpose | Implemented In |
|----------|--------|---------|----------------|
| `GET /api/attendance/my-qr-code` | GET | QR code for marking attendance | `QrCodeService` (used in center_attendance, settings) |
| `PATCH /api/admin/students/:id/parent-phone` | PATCH | Update student parent phone | **Not yet in app** |

---

## Visual Structure Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    INSTRUCTOR BOTTOM NAV                          │
│  [الرئيسية]  [دوراتي]  [+ إضافة]  [الأرباح]  [حسابي]           │
└─────────────────────────────────────────────────────────────────┘

┌─ HOME (/instructor) ─────────────────────────────────────────────┐
│  ProfileService.getProfile()          → Header (name, avatar)     │
│  getDashboardOverview()               → Stats grid (4 cards)      │
│  getDashboardActivity()               → Recent activity section   │
│  getMyCourses()                       → My courses list           │
│  getPayments()                        → Total sales calculation   │
└──────────────────────────────────────────────────────────────────┘

┌─ COURSES (/instructor/courses) ──────────────────────────────────┐
│  getMyCourses()                       → Courses grid/list         │
│  getAttendance(courseId, action)      → Course enrollments        │
└──────────────────────────────────────────────────────────────────┘

┌─ COURSE DETAILS (/instructor/course-details) ────────────────────┐
│  getCourseDetails(courseId)           → Full course + students    │
└──────────────────────────────────────────────────────────────────┘

┌─ CREATE COURSE (/instructor/create-course) ──────────────────────┐
│  createCourse()                      → POST new course            │
└──────────────────────────────────────────────────────────────────┘

┌─ EARNINGS (/instructor/earnings) ────────────────────────────────┐
│  getDashboardOverview()               → Summary stats             │
│  getDashboardCharts()                 → usersGrowth, revenue,     │
│                                         courseCompletion charts   │
│  getPayments() / charts.revenue       → Monthly earnings chart    │
│  getUsersMeEarnings()                 → Total & period earnings   │
│  getMySalarySettings()                → Salary settings card      │
│  calculateMySalary()                  → Calculate result          │
│  getReports()                         → Reports section           │
└──────────────────────────────────────────────────────────────────┘

┌─ PROFILE (/instructor/profile) ──────────────────────────────────┐
│  getMyAttendance()                    → My attendance records     │
│  ProfileService                       → Avatar, name              │
└──────────────────────────────────────────────────────────────────┘
```

---

## ApiEndpoints Reference

| ApiEndpoints Constant | Full URL |
|----------------------|----------|
| `adminDashboardOverview` | `GET /api/admin/dashboard/overview` |
| `adminDashboardCharts` | `GET /api/admin/dashboard/charts` |
| `adminDashboardActivity` | `GET /api/admin/dashboard/activity` |
| `adminCourses` | `GET/POST /api/admin/courses` |
| `adminCourse(id)` | `GET /api/admin/courses/:id` |
| `adminPayments` | `GET /api/admin/payments` |
| `adminUsersMeEarnings` | `GET /api/admin/users/me/earnings` |
| `adminTeachersMeSalarySettings` | `GET /api/admin/teachers/me/salary-settings` |
| `adminTeachersMeCalculateSalary` | `POST /api/admin/teachers/me/calculate-salary` |
| `adminTeachersReports` | `GET /api/admin/teachers/reports` |
| `adminAttendance` | `GET /api/admin/attendance` |
| `attendanceMyAttendance` | `GET /api/attendance/my-attendance` |
| `attendanceMyQrCode` | `GET /api/attendance/my-qr-code` |

---

## Notes

- **Data scope**: All responses are filtered by the logged-in teacher; no need to pass `instructorId` in most cases (backend uses token).
- **Demo data**: When activity/charts return empty, demo data may be shown in debug for UI preview (see `instructor_home_screen.dart`).
- **Logging**: Teacher API calls use `logTag: 'TEACHER'` with `dart:developer.log()` for debugging.
