# Flutter Handoff: Student Certificates API

This document explains how Flutter should load and display student certificates after course completion.

## Endpoint

- Method: `GET`
- URL: `/api/certificates`
- Auth: Required (`Bearer` student token)

## Request Headers

```http
Authorization: Bearer <student_token>
Content-Type: application/json
```

## cURL Example

```bash
curl --request GET \
  --url "https://drchampions-academy.anmka.com/api/certificates" \
  --header "Authorization: Bearer <student_token>"
```

## Success Response (Example)

```json
{
  "success": true,
  "data": [
    {
      "id": "c9d67495-9e2f-46db-894d-e8b2a2f2e589",
      "course": {
        "id": "53b97d5b-811d-4861-9bcc-b7b829bece29",
        "title": "Biology - Grade 2",
        "thumbnail": "https://drchampions-academy.anmka.com/uploads/images/course-thumb.png",
        "instructor": {
          "name": "Tarik Bender"
        }
      },
      "certificate_number": "CERT-9K3D-2P7Q",
      "student_name": "Student Name",
      "issue_date": "2026-04-28T22:15:30.000Z",
      "preview_url": "/certificates/c9d67495-9e2f-46db-894d-e8b2a2f2e589/preview",
      "download_url": "/certificates/c9d67495-9e2f-46db-894d-e8b2a2f2e589/download",
      "share_url": "https://anmka-lms.com/verify/CERT-9K3D-2P7Q",
      "is_verified": true
    }
  ]
}
```

## When Does Certificate Appear?

Certificate is auto-issued when the student completes the course (progress reaches 100%).

If a certificate was not created earlier for any reason, backend sync logic auto-issues missing certificates when:

- student loads enrollments
- or student opens certificates list endpoint

So Flutter only needs to call `/api/certificates` and render returned items.

## Flutter UI Notes

- If `data` is empty, show: "No certificates yet."
- For each certificate card, display:
  - course title
  - issue date
  - certificate number
  - actions:
    - Preview (open `preview_url`)
    - Download (open `download_url`)
- `preview_url` and `download_url` may be relative paths; prepend API host/base URL when needed.

## Error Shape (Typical)

```json
{
  "success": false,
  "message": "Unauthorized"
}
```

## Quick Checklist for Flutter Developer

- Store and send valid student token.
- Call `GET /api/certificates` after login and on certificates screen open.
- Handle empty state, loading, and error states.
- Render certificate list from `response.data`.
