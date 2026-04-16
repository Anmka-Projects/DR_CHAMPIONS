import 'package:flutter/material.dart';

import '../secondary/lesson_viewer_screen.dart';

/// Opens [LessonViewerScreen] with a fixed public Vimeo ID for manual QA.
///
/// Navigate with [RouteNames.vimeoTest] (debug builds only).
class VimeoTestScreen extends StatelessWidget {
  const VimeoTestScreen({super.key});

  /// Public Vimeo sample used in Vimeo embed docs (`vimeo.com/76979871`).
  static Map<String, dynamic> get testLesson => {
        'id': 'debug-vimeo-lesson',
        'title': 'Vimeo player test',
        'duration': '—',
        'vimeo_id': '76979871',
      };

  @override
  Widget build(BuildContext context) {
    return LessonViewerScreen(
      lesson: testLesson,
      courseId: null,
    );
  }
}
