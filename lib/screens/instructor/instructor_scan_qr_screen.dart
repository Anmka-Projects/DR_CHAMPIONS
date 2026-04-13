import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';

/// Instructor – Scan QR code to mark student attendance.
/// Per reference: POST /api/attendance/scan with qr_code, course_id, session_title.
class InstructorScanQrScreen extends StatefulWidget {
  const InstructorScanQrScreen({super.key});

  @override
  State<InstructorScanQrScreen> createState() => _InstructorScanQrScreenState();
}

class _InstructorScanQrScreenState extends State<InstructorScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _sessionTitleController =
      TextEditingController(text: '');
  bool _isProcessing = false;
  String? _lastScanned;
  String? _error;
  bool _coursesLoading = true;
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sessionTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _coursesLoading = true);
    try {
      final profile = await ProfileService.instance.getProfile();
      final userId = profile['id']?.toString() ?? '';
      if (userId.isEmpty) {
        setState(() {
          _coursesLoading = false;
          _courses = [];
        });
        return;
      }
      final data = await TeacherDashboardService.instance.getMyCourses(
        instructorId: userId,
        limit: 100,
      );
      final list = data['data'] ?? data;
      final listMap = list is List
          ? list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _courses = listMap;
          _coursesLoading = false;
          if (_courses.isNotEmpty && _selectedCourseId == null) {
            _selectedCourseId = _courses.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('❌ InstructorScanQrScreen loadCourses: $e');
      if (mounted) {
        setState(() {
          _coursesLoading = false;
          _courses = [];
        });
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    if (code == _lastScanned) return;

    final courseId = _selectedCourseId?.trim();
    final sessionTitle = _sessionTitleController.text.trim();
    if (courseId == null || courseId.isEmpty || sessionTitle.isEmpty) {
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'اختر الدورة وأدخل عنوان الجلسة أولاً'
                : 'Select a course and enter session title first',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanned = code;
      _error = null;
    });

    try {
      await TeacherDashboardService.instance.scanAttendance(
        code,
        courseId: courseId,
        sessionTitle: sessionTitle,
      );
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم تسجيل الحضور بنجاح' : 'Attendance marked successfully',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _error ?? (isAr ? 'فشل تسجيل الحضور' : 'Failed to mark attendance'),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _lastScanned = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        title: Text(
          isAr ? 'مسح QR للحضور' : 'Scan QR for Attendance',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(RouteNames.instructorProfile),
        ),
      ),
      body: Column(
        children: [
          // Course & session selection (per reference: course_id, session_title required)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.black87,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'اختر الدورة والجلسة' : 'Course & session',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                if (_coursesLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCourseId,
                    dropdownColor: const Color(0xFF2D1B69),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    hint: Text(
                      isAr ? 'الدورة' : 'Course',
                      style: GoogleFonts.cairo(color: Colors.white70),
                    ),
                    items: _courses.map((c) {
                      final id = c['id']?.toString() ?? '';
                      final title = c['title']?.toString() ?? id;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedCourseId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sessionTitleController,
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isAr
                          ? 'عنوان الجلسة (مثل: المحاضرة الأولى)'
                          : 'Session title (e.g. Lecture 1)',
                      hintStyle: GoogleFonts.cairo(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.purple,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 48,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            size: 40, color: AppColors.purple),
                        const SizedBox(height: 12),
                        Text(
                          isAr
                              ? 'وجّه الكاميرا نحو كود QR الخاص بالطالب لتسجيل حضوره'
                              : 'Point the camera at the student\'s QR code to mark attendance',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.white,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isProcessing) ...[
                          const SizedBox(height: 16),
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
