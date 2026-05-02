import 'package:educational_app/core/course_live_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCourseLiveMeta', () {
    test('returns unlinked meta when no prefix exists', () {
      const description = 'Weekly revision with Q&A';
      final meta = parseCourseLiveMeta(description);

      expect(meta.courseId, isNull);
      expect(meta.courseTitle, isNull);
      expect(meta.plainDescription, description);
    });

    test('parses course id/title and plain description', () {
      const description = '[[COURSE_META]]course_123|MRCS Course\nLive session body';
      final meta = parseCourseLiveMeta(description);

      expect(meta.courseId, 'course_123');
      expect(meta.courseTitle, 'MRCS Course');
      expect(meta.plainDescription, 'Live session body');
    });
  });
}
