# LMS Feature Coverage Checklist (App Audit)

## Legend

- `DONE`: Implemented in app.
- `PARTIAL`: Exists but incomplete.
- `MISSING`: Not implemented in app yet.

---

## Platforms

- Website: `MISSING` (no `web/` target in current Flutter project)
- Android app: `DONE`
- iOS app: `DONE`
- Windows `.exe`: `MISSING` (no `windows/` target)

---

## Structure / Navigation

- Home/About/Blog/Contact structure: `PARTIAL`
- Category -> Course -> Module -> Sub-module -> Lesson hierarchy: `PARTIAL` (rendering exists, strict authoring model needs stronger contracts)

---

## Course & Lesson Content

- Course title/description/cover: `DONE`
- Multi-instructor course representation: `PARTIAL`
- Pricing/plans/checkout: `PARTIAL`
- Lesson supports video/audio/images/files/pdf: `DONE`
- Question bank support: `PARTIAL`
- AI embed blocks: `MISSING`
- Free sample preview lessons: `DONE`

---

## Scheduling & Integrations

- Content scheduling/release: `PARTIAL`
- Re-schedule finished course cycle: `MISSING`
- Google Calendar integration: `MISSING`
- Email/SMS reminders on lesson release: `MISSING`
- Zoom integration (true join flow): `PARTIAL`

---

## Security

- No screenshot/no recording: `PARTIAL` (basic screen protector enabled, not full-proof)
- Non-downloadable content policy: `MISSING` (downloads currently supported for some content)
- Dynamic watermark by user identity: `MISSING`

---

## Student Features

- Progress tracking: `DONE`
- Resume last lesson: `PARTIAL`
- Bookmark lessons: `PARTIAL`
- Notes: `MISSING`
- Certificates: `DONE`
- Notifications: `DONE`

---

## Admin / Instructor Features

- Manage instructors under platform owner: `PARTIAL`
- Content management and curriculum editing: `PARTIAL`
- Drag & drop ordering UX: `PARTIAL`
- Student management/access control: `PARTIAL`
- Analytics dashboards: `PARTIAL`

---

## Subscription & Payments

- Multi-plan per course with durations/prices: `PARTIAL`
- Expiry by fixed date OR rolling duration: `MISSING` (fully explicit lifecycle rules)
- Renew flow: `PARTIAL`
- Payment methods (Egypt + international): `PARTIAL`
- Manual student addition with plan duration: `PARTIAL`

---

## User Control / Device Policy

- One account per email: `DONE`
- Limit number/type of allowed devices: `PARTIAL`
- Prevent simultaneous logins across devices: `PARTIAL`
- Device/session management panel: `MISSING`

---

## Video Hosting

- Vimeo/YouTube URL support: `DONE`
- Strong secure private embedding policy: `PARTIAL`

---

## Notes

- Immediate backend handoff created at:
  - `docs/LMS_BACKEND_API_REQUIREMENTS.md`
- Recent app-side fixes already applied during this session:
  - assignment resubmission lock after first submission
  - exam endpoint flow corrections + fallback handling when exams list endpoint fails
