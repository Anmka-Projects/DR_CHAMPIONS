import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/startup/splash_screen.dart';
import '../../screens/startup/onboarding_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/student/home_screen.dart';
import '../../screens/student/courses_screen.dart';
import '../../screens/student/progress_screen.dart';
import '../../screens/student/student_dashboard_screen.dart';
import '../../screens/instructor/instructor_home_screen.dart';
import '../../screens/instructor/instructor_courses_screen.dart';
import '../../screens/instructor/instructor_earnings_screen.dart';
import '../../screens/instructor/instructor_profile_screen.dart';
import '../../screens/instructor/instructor_create_course_screen.dart';
import '../../screens/instructor/instructor_course_details_screen.dart';
import '../../screens/instructor/instructor_session_details_screen.dart';
import '../../screens/instructor/instructor_scan_qr_screen.dart';
import '../../screens/debug/vimeo_test_screen.dart';
import '../../screens/secondary/categories_screen.dart';
import '../../screens/secondary/course_details_screen.dart';
import '../../screens/secondary/lesson_viewer_screen.dart';
import '../../screens/secondary/exams_screen.dart';
import '../../screens/secondary/my_exams_screen.dart';
import '../../screens/secondary/notifications_screen.dart';
import '../../screens/secondary/checkout_screen.dart';
import '../../screens/secondary/live_courses_screen.dart';
import '../../screens/secondary/downloads_screen.dart';
import '../../screens/secondary/certificates_screen.dart';
import '../../screens/secondary/enrolled_screen.dart';
import '../../screens/secondary/settings_screen.dart';
import '../../screens/secondary/all_courses_screen.dart';
import '../../screens/secondary/edit_profile_screen.dart';
import '../../screens/secondary/change_password_screen.dart';
import '../../screens/secondary/pdf_viewer_screen.dart';
import '../../screens/secondary/embed_web_viewer_screen.dart';
import '../../screens/secondary/center_attendance_screen.dart';
import '../../screens/secondary/teachers_screen.dart';
import '../../screens/secondary/teacher_details_screen.dart';
import '../../screens/secondary/chat_conversations_screen.dart';
import '../../screens/secondary/chat_messages_screen.dart';
import 'route_names.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) {
      // Check if user has launched before
      return null; // Will be handled in splash screen
    },
    routes: [
      // Startup flow
      GoRoute(
        path: RouteNames.splash,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.onboarding1,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const OnboardingScreen(step: 1),
        ),
      ),
      GoRoute(
        path: RouteNames.onboarding2,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const OnboardingScreen(step: 2),
        ),
      ),
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),

      // Instructor flow
      GoRoute(
        path: RouteNames.instructorHome,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorHomeScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorCourses,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorCoursesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorCreateCourse,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorCreateCourseScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorEarnings,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorEarningsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorProfile,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorProfileScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorScanQr,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const InstructorScanQrScreen(),
        ),
      ),

      // Student flow - main app screens (with bottom nav)
      GoRoute(
        path: RouteNames.home,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.courses,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const CoursesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.progress,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const ProgressScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.dashboard,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const StudentDashboardScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.allCourses,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const AllCoursesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.teachers,
        pageBuilder: (context, state) {
          final extra = state.extra;
          List<Map<String, dynamic>>? teachers;
          if (extra is List) {
            teachers = extra.cast<Map<String, dynamic>>();
          }
          return _buildPageWithTransition(
            key: state.pageKey,
            child: TeachersScreen(teachers: teachers),
          );
        },
      ),

      // Secondary screens
      GoRoute(
        path: RouteNames.categories,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const CategoriesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.vimeoTest,
        redirect: (context, state) =>
            kDebugMode ? null : RouteNames.home,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const VimeoTestScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.courseDetails,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: CourseDetailsScreen(
            course: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorCourseDetails,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: InstructorCourseDetailsScreen(
            course: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.instructorSessionDetails,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _buildPageWithTransition(
            key: state.pageKey,
            child: InstructorSessionDetailsScreen(
              courseId: extra['courseId']?.toString() ?? '',
              course: extra['course'] as Map<String, dynamic>?,
              section: extra['section'] as Map<String, dynamic>? ?? {},
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.teacherDetails,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: TeacherDetailsScreen(
            teacher: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.lessonViewer,
        pageBuilder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic>? lesson;
          String? courseId;

          List<Map<String, dynamic>> allLessons = const [];
          int lessonIndex = -1;

          if (extra is Map<String, dynamic>) {
            // Check if it's a wrapper map with lesson and courseId
            if (extra.containsKey('lesson')) {
              lesson = extra['lesson'] as Map<String, dynamic>?;
              courseId = extra['courseId']?.toString();
              final rawAll = extra['allLessons'];
              if (rawAll is List) {
                allLessons = rawAll
                    .whereType<Map<String, dynamic>>()
                    .toList();
              }
              lessonIndex = (extra['lessonIndex'] as int?) ?? -1;
            } else {
              // It's the lesson object itself
              lesson = extra;
            }
          }

          return _buildPageWithTransition(
            key: state.pageKey,
            child: LessonViewerScreen(
              lesson: lesson,
              courseId: courseId,
              allLessons: allLessons,
              lessonIndex: lessonIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.exams,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const ExamsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.myExams,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const MyExamsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.notifications,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.checkout,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: CheckoutScreen(
            course: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.liveCourses,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const LiveCoursesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.downloads,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const DownloadsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.certificates,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const CertificatesScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.enrolled,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const EnrolledScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.settings,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: EditProfileScreen(
            initialProfile: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.pdfViewer,
        pageBuilder: (context, state) {
          final extra = state.extra;
          String pdfUrl = '';
          String? title;

          if (extra is Map<String, dynamic>) {
            pdfUrl = extra['pdfUrl']?.toString() ?? '';
            title = extra['title']?.toString();
          } else if (extra is String) {
            pdfUrl = extra;
          }

          return _buildPageWithTransition(
            key: state.pageKey,
            child: PdfViewerScreen(
              pdfUrl: pdfUrl,
              title: title,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.embedWebViewer,
        pageBuilder: (context, state) {
          final extra = state.extra;
          var url = '';
          String? title;
          if (extra is Map<String, dynamic>) {
            url = extra['url']?.toString() ?? '';
            title = extra['title']?.toString();
          } else if (extra is String) {
            url = extra;
          }
          return _buildPageWithTransition(
            key: state.pageKey,
            child: EmbedWebViewerScreen(
              initialUrl: url,
              title: title,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.centerAttendance,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const CenterAttendanceScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.chatConversations,
        pageBuilder: (context, state) => _buildPageWithTransition(
          key: state.pageKey,
          child: const ChatConversationsScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _buildPageWithTransition(
            key: state.pageKey,
            child: ChatMessagesScreen(
              conversationId: conversationId,
              otherUser: extra['otherUser'] as Map<String, dynamic>?,
              conversation: extra['conversation'] as Map<String, dynamic>?,
            ),
          );
        },
      ),
    ],
  );

  /// Build page with smooth fade and slide transition
  static Page<void> _buildPageWithTransition({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        // Fade and slide transition
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.02),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
