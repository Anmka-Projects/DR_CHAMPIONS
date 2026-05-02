# Flutter Integration: Show Live Sessions Inside Course

## Goal

Show only the live sessions related to a specific course inside the course details screen in Flutter.

---

## Current Backend Reality

- Live sessions are fetched from mobile API (`getLiveSessions` / `getMyLiveSessions`).
- `live_sessions` table does not yet have a real `courseId` column.
- Course linkage is currently embedded in session `description` using metadata prefix:

```text
[[COURSE_META]]<courseId>|<courseTitle>
<normal session description>
```

Example:

```text
[[COURSE_META]]bd37a997-9e14-45dd-a9d5-c6656eca2b8a|MRCS Course
Weekly revision with Q&A
```

---

## What Flutter Should Do (Now)

### 1) Fetch live sessions

Use your existing endpoint that returns sessions list (upcoming/live/past or my sessions).

### 2) Parse metadata from `description`

If `description` starts with `[[COURSE_META]]`, extract:

- `courseId`
- `courseTitle`
- `plainDescription` (text after first line)

If no prefix exists, treat session as unlinked.

### 3) Filter by course screen `courseId`

Inside course page, only show sessions where parsed `courseId == currentCourseId`.

---

## Dart Helper (Drop-in)

```dart
class CourseLiveMeta {
  final String? courseId;
  final String? courseTitle;
  final String plainDescription;

  CourseLiveMeta({
    required this.courseId,
    required this.courseTitle,
    required this.plainDescription,
  });
}

CourseLiveMeta parseCourseLiveMeta(String? description) {
  const prefix = '[[COURSE_META]]';
  final raw = (description ?? '').trim();

  if (!raw.startsWith(prefix)) {
    return CourseLiveMeta(
      courseId: null,
      courseTitle: null,
      plainDescription: raw,
    );
  }

  final firstNewline = raw.indexOf('\n');
  final metaLine = firstNewline >= 0 ? raw.substring(0, firstNewline) : raw;
  final plain = firstNewline >= 0 ? raw.substring(firstNewline + 1).trim() : '';

  final encoded = metaLine.substring(prefix.length);
  final parts = encoded.split('|');

  final courseId = parts.isNotEmpty ? parts[0].trim() : null;
  final courseTitle = parts.length > 1 ? parts[1].trim() : null;

  return CourseLiveMeta(
    courseId: (courseId == null || courseId.isEmpty) ? null : courseId,
    courseTitle: (courseTitle == null || courseTitle.isEmpty) ? null : courseTitle,
    plainDescription: plain,
  );
}
```

---

## Filtering Example

```dart
final courseSessions = allSessions.where((s) {
  final meta = parseCourseLiveMeta(s.description);
  return meta.courseId == currentCourseId;
}).toList();
```

---

## UI Notes

- Show:
  - `session.title`
  - parsed `plainDescription`
  - date/time
  - instructor
  - platform link
- Optional: show `courseTitle` under title for debugging/verification.

---

## Recommended Next Step (Backend Proper Fix)

For long-term clean integration, backend should add real `courseId` in `LiveSession` model and return it directly in API.
Then Flutter can stop parsing description metadata.
