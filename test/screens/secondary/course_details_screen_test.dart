import 'package:educational_app/screens/secondary/course_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectFirstLessonForPlayback', () {
    test('skips module container and returns nested lesson', () {
      final course = <String, dynamic>{
        'curriculum': [
          {
            'id': 'module_1',
            'type': 'module',
            'lessons': [
              {
                'id': 'lesson_1',
                'type': 'lesson',
                'title': 'Intro',
                'youtube_id': 'abc123',
              },
            ],
          },
        ],
      };

      final result = selectFirstLessonForPlayback(course);

      expect(result, isNotNull);
      expect(result!['id'], 'lesson_1');
      expect(result['type'], 'lesson');
    });

    test('walks sub_modules and finds first playable lesson', () {
      final course = <String, dynamic>{
        'curriculum': [
          {
            'id': 'module_1',
            'type': 'module',
            'sub_modules': [
              {
                'id': 'sub_1',
                'type': 'sub_module',
                'lessons': [
                  {
                    'id': 'lesson_2',
                    'title': 'Deep dive',
                    'video_url': 'https://example.com/video.mp4',
                  },
                ],
              },
            ],
          },
        ],
      };

      final result = selectFirstLessonForPlayback(course);

      expect(result, isNotNull);
      expect(result!['id'], 'lesson_2');
      expect(result['video_url'], contains('video.mp4'));
    });

    test('falls back to top-level lessons when curriculum has no lessons', () {
      final course = <String, dynamic>{
        'curriculum': [
          {
            'id': 'module_1',
            'type': 'module',
            'lessons': [],
          },
        ],
        'lessons': [
          {
            'id': 'lesson_3',
            'youtubeVideoId': 'xyz987',
          },
        ],
      };

      final result = selectFirstLessonForPlayback(course);

      expect(result, isNotNull);
      expect(result!['id'], 'lesson_3');
      expect(result['youtubeVideoId'], 'xyz987');
    });
  });
}
