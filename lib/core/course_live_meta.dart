class CourseLiveMeta {
  final String? courseId;
  final String? courseTitle;
  final String plainDescription;

  const CourseLiveMeta({
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

  final parsedCourseId = parts.isNotEmpty ? parts[0].trim() : '';
  final parsedCourseTitle = parts.length > 1 ? parts[1].trim() : '';

  return CourseLiveMeta(
    courseId: parsedCourseId.isEmpty ? null : parsedCourseId,
    courseTitle: parsedCourseTitle.isEmpty ? null : parsedCourseTitle,
    plainDescription: plain,
  );
}
