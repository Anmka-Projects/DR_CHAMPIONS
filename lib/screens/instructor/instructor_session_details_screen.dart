import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../services/teacher_dashboard_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/instructor_question_bank_lesson_fields.dart';

/// Instructor – Session (section) details. Display and edit a course section
/// with its lessons. Uses curriculum API.
class InstructorSessionDetailsScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic>? course;
  final Map<String, dynamic> section;

  const InstructorSessionDetailsScreen({
    super.key,
    required this.courseId,
    this.course,
    required this.section,
  });

  @override
  State<InstructorSessionDetailsScreen> createState() =>
      _InstructorSessionDetailsScreenState();
}

class _InstructorSessionDetailsScreenState
    extends State<InstructorSessionDetailsScreen> {
  late TextEditingController _titleController;
  late List<Map<String, dynamic>> _lessons;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.section['title']?.toString() ?? '',
    );
    final lessonsRaw = widget.section['lessons'];
    _lessons = lessonsRaw is List
        ? lessonsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveSection() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'أدخل عنوان الجلسة' : 'Enter session title'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final curriculum = await TeacherDashboardService.instance
          .getCourseCurriculum(widget.courseId);
      final sectionsRaw = curriculum['sections'];
      final sections = sectionsRaw is List
          ? sectionsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final sectionId = widget.section['id']?.toString();
      int idx = -1;
      if (sectionId != null && sectionId.isNotEmpty) {
        idx = sections.indexWhere((s) => s['id']?.toString() == sectionId);
      }
      if (idx < 0) {
        idx = sections.indexWhere(
          (s) => s['title']?.toString() == widget.section['title']?.toString(),
        );
      }
      if (idx < 0) idx = 0;
      sections[idx] = {
        ...sections[idx],
        'title': title,
        'order': widget.section['order'] ?? idx + 1,
        'lessons': _lessons,
      };
      await TeacherDashboardService.instance.updateCourseCurriculum(
        widget.courseId,
        body: {
          'courseId': widget.courseId,
          'sections': sections,
        },
      );
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم حفظ الجلسة بنجاح' : 'Session saved successfully',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Extra keys for curriculum API (question banks, etc.).
  Map<String, dynamic>? _extraLessonFields(Map<String, dynamic> result) {
    final out = <String, dynamic>{};
    void put(String k, dynamic v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty) return;
      out[k] = v;
    }

    put('question_bank_id', result['question_bank_id']);
    put('questionBankId', result['questionBankId']);
    put('question_bank_file_url', result['question_bank_file_url']);
    put('questionBankUrl', result['questionBankUrl']);
    return out.isEmpty ? null : out;
  }

  Future<void> _showAddLessonDialog() async {
    final result = await _showLessonFormDialog(null);
    if (result == null || !mounted) return;
    final sectionId = widget.section['id']?.toString();
    if (sectionId != null && sectionId.isNotEmpty) {
      try {
        final created =
            await TeacherDashboardService.instance.addCurriculumLesson(
          widget.courseId,
          sectionId,
          title: result['title']?.toString() ?? '',
          type: result['type']?.toString() ?? 'video',
          duration: (result['duration'] as num?)?.toInt() ?? 0,
          content: result['content']?.toString(),
          videoUrl: result['videoUrl']?.toString(),
          fileUrl: result['fileUrl']?.toString(),
          isFree: result['isFree'] == true || result['is_free'] == true,
          order: (result['order'] as num?)?.toInt() ?? (_lessons.length + 1),
          extraFields: _extraLessonFields(result),
        );
        if (mounted) {
          final lessonMap = Map<String, dynamic>.from(created);
          setState(() => _lessons.add(lessonMap));
        }
        return;
      } catch (_) {
        // Fallback: add locally; user can save full curriculum later
      }
    }
    setState(() => _lessons.add(result));
  }

  Future<void> _showEditLessonDialog(int index) async {
    final result = await _showLessonFormDialog(_lessons[index]);
    if (result != null && mounted) {
      setState(() {
        _lessons[index] = result;
      });
    }
  }

  Future<void> _confirmDeleteLesson(int index) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'حذف الدرس' : 'Delete lesson',
            style: GoogleFonts.cairo()),
        content: Text(
          isAr
              ? 'هل أنت متأكد من حذف هذا الدرس؟'
              : 'Are you sure you want to delete this lesson?',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: Text(isAr ? 'حذف' : 'Delete', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final sectionId = widget.section['id']?.toString();
    final lesson = index < _lessons.length ? _lessons[index] : null;
    final lessonId = lesson?['id']?.toString();
    if (sectionId != null &&
        sectionId.isNotEmpty &&
        lessonId != null &&
        lessonId.isNotEmpty) {
      try {
        await TeacherDashboardService.instance.deleteCurriculumLesson(
          widget.courseId,
          sectionId,
          lessonId,
        );
      } catch (_) {
        // Fallback: just remove locally; user can save full curriculum later
      }
    }
    if (mounted) setState(() => _lessons.removeAt(index));
  }

  Future<Map<String, dynamic>?> _showLessonFormDialog(
    Map<String, dynamic>? existing,
  ) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final contentCtrl =
        TextEditingController(text: existing?['content']?.toString() ?? '');
    final videoUrlCtrl =
        TextEditingController(text: existing?['videoUrl']?.toString() ?? '');
    final fileUrlCtrl =
        TextEditingController(text: existing?['fileUrl']?.toString() ?? '');
    final durationCtrl = TextEditingController(
      text: (existing?['duration'] is num)
          ? (existing!['duration'] as num).toInt().toString()
          : '0',
    );
    String type = existing?['type']?.toString() ?? 'video';
    bool isFree = existing?['isFree'] == true || existing?['is_free'] == true;
    final existingFileUrl = existing?['fileUrl']?.toString();
    String? qbBankId = existing?['question_bank_id']?.toString() ??
        existing?['questionBankId']?.toString();
    String? qbFileUrl = existing?['question_bank_file_url']?.toString() ??
        existing?['questionBankUrl']?.toString() ??
        (type == 'question_bank' ? existingFileUrl : null);

    final types = [
      ('video', isAr ? 'فيديو' : 'Video'),
      ('text', isAr ? 'نص' : 'Text'),
      ('file', isAr ? 'ملف' : 'File'),
      ('exam', isAr ? 'امتحان' : 'Exam'),
      ('question_bank', isAr ? 'بنك أسئلة' : 'Question bank'),
    ];

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing != null
                ? (isAr ? 'تعديل الدرس' : 'Edit lesson')
                : (isAr ? 'إضافة درس جديد' : 'Add new lesson'),
            style: GoogleFonts.cairo(),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isAr ? 'عنوان الدرس' : 'Lesson title'} *',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText:
                          isAr ? 'أدخل عنوان الدرس' : 'Enter lesson title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${isAr ? 'نوع الدرس' : 'Lesson type'} *',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(t.$2, style: GoogleFonts.cairo()),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => type = v ?? 'video'),
                  ),
                  const SizedBox(height: 14),
                  // Fields below depend on lesson type
                  if (type == 'video') ...[
                    Text(
                      isAr ? 'رابط يوتيوب' : 'YouTube link',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: videoUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://www.youtube.com/watch?v=...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.cairo(),
                      keyboardType: TextInputType.url,
                    ),
                  ] else if (type == 'text') ...[
                    Text(
                      isAr ? 'محتوى الدرس' : 'Lesson content',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: isAr ? 'أدخل المحتوى' : 'Enter content',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.cairo(),
                    ),
                  ] else if (type == 'file') ...[
                    Text(
                      isAr ? 'رفع ملف PDF' : 'Upload PDF file',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FileUploadField(
                      isAr: isAr,
                      initialUrl: fileUrlCtrl.text,
                      onUrlChanged: (url) => fileUrlCtrl.text = url,
                    ),
                  ] else if (type == 'exam') ...[
                    Text(
                      isAr
                          ? 'وصف الامتحان أو الرابط'
                          : 'Exam description or link',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isAr
                            ? 'وصف أو رابط الامتحان'
                            : 'Description or exam link',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.cairo(),
                      keyboardType: TextInputType.url,
                    ),
                  ] else if (type == 'question_bank') ...[
                    InstructorQuestionBankLessonFields(
                      courseId: widget.courseId,
                      isAr: isAr,
                      initialBankId: qbBankId,
                      initialFileUrl: qbFileUrl,
                      onChanged: (id, url) => setModalState(() {
                        qbBankId = id;
                        qbFileUrl = url;
                      }),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    isAr ? 'المدة (دقيقة)' : 'Duration (minutes)',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: durationCtrl,
                    decoration: InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: GoogleFonts.cairo(),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Checkbox(
                        value: isFree,
                        onChanged: (v) =>
                            setModalState(() => isFree = v ?? false),
                        activeColor: AppColors.purple,
                      ),
                      Text(
                        isAr ? 'درس مجاني' : 'Free lesson',
                        style: GoogleFonts.cairo(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(isAr ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr ? 'أدخل عنوان الدرس' : 'Enter lesson title',
                      ),
                      backgroundColor: AppColors.destructive,
                    ),
                  );
                  return;
                }
                final duration = int.tryParse(durationCtrl.text) ?? 0;
                final lesson = <String, dynamic>{
                  ...?existing,
                  'title': title,
                  'type': type,
                  'duration': duration,
                  'content': contentCtrl.text.trim().isEmpty
                      ? null
                      : contentCtrl.text.trim(),
                  'videoUrl': videoUrlCtrl.text.trim().isEmpty
                      ? null
                      : videoUrlCtrl.text.trim(),
                  'fileUrl': type == 'question_bank'
                      ? (qbFileUrl?.trim().isNotEmpty == true
                          ? qbFileUrl!.trim()
                          : (fileUrlCtrl.text.trim().isEmpty
                              ? null
                              : fileUrlCtrl.text.trim()))
                      : (fileUrlCtrl.text.trim().isEmpty
                          ? null
                          : fileUrlCtrl.text.trim()),
                  'isFree': isFree,
                  'order': existing?['order'] ?? (_lessons.length + 1),
                };
                if (type == 'question_bank') {
                  if (qbBankId != null && qbBankId!.trim().isNotEmpty) {
                    lesson['question_bank_id'] = qbBankId!.trim();
                    lesson['questionBankId'] = qbBankId!.trim();
                  } else {
                    lesson.remove('question_bank_id');
                    lesson.remove('questionBankId');
                  }
                  if (qbFileUrl != null && qbFileUrl!.trim().isNotEmpty) {
                    final u = qbFileUrl!.trim();
                    lesson['question_bank_file_url'] = u;
                    lesson['questionBankUrl'] = u;
                  } else {
                    lesson.remove('question_bank_file_url');
                    lesson.remove('questionBankUrl');
                  }
                }
                Navigator.pop(ctx, lesson);
              },
              child: Text(
                existing != null
                    ? (isAr ? 'حفظ' : 'Save')
                    : (isAr ? 'إضافة الدرس' : 'Add lesson'),
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final courseTitle =
        widget.course?['title']?.toString() ?? (isAr ? 'الدورة' : 'Course');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'تفاصيل الجلسة' : 'Session details',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseTitle,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.destructive, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'عنوان الجلسة' : 'Session title',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: isAr ? 'أدخل العنوان' : 'Enter title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.mutedForeground.withOpacity(0.04),
                    ),
                    style: GoogleFonts.cairo(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SessionAttendanceCard(
              courseId: widget.courseId,
              isAr: isAr,
              sessionTitle: widget.section['title']?.toString() ??
                  (isAr ? 'الجلسة' : 'Session'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.purple, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${isAr ? 'الدروس' : 'Lessons'} (${_lessons.length})',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAddLessonDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    isAr ? 'إضافة درس' : 'Add lesson',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lessons.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.mutedForeground.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isAr
                        ? 'لا توجد دروس في هذه الجلسة'
                        : 'No lessons in this session',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              ..._lessons.asMap().entries.map((e) {
                final i = e.key;
                final l = e.value;
                final title = l['title']?.toString() ??
                    '${isAr ? "درس" : "Lesson"} ${i + 1}';
                final type = l['type']?.toString() ?? '';
                final duration = l['duration'];
                final durationStr = duration is num && duration > 0
                    ? '${duration.toInt()} min'
                    : '';
                final isFree = l['isFree'] == true || l['is_free'] == true;
                return InkWell(
                  onTap: () => _showEditLessonDialog(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.purple.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          type == 'video'
                              ? Icons.play_circle_rounded
                              : type == 'question_bank'
                                  ? Icons.quiz_rounded
                                  : Icons.article_rounded,
                          size: 24,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (durationStr.isNotEmpty)
                                Text(
                                  durationStr,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isFree)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAr ? 'مجاني' : 'Free',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: AppColors.purple,
                          ),
                          onPressed: () => _showEditLessonDialog(i),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.destructive,
                          ),
                          onPressed: () => _confirmDeleteLesson(i),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSection,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  isAr ? 'حفظ التغييرات' : 'Save changes',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for uploading PDF file in lesson form
class _FileUploadField extends StatefulWidget {
  final bool isAr;
  final String initialUrl;
  final void Function(String url) onUrlChanged;

  const _FileUploadField({
    required this.isAr,
    required this.initialUrl,
    required this.onUrlChanged,
  });

  @override
  State<_FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends State<_FileUploadField> {
  String? _uploadedUrl;
  String? _fileName;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl.isNotEmpty) {
      _uploadedUrl = widget.initialUrl;
      _fileName = Uri.tryParse(widget.initialUrl)?.pathSegments.last ??
          widget.initialUrl;
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null) return;
      final f = File(path);
      if (!await f.exists()) return;

      if (mounted)
        setState(() {
          _uploading = true;
          _error = null;
        });

      final url = await UploadService.instance.uploadPdf(f);
      widget.onUrlChanged(url);
      if (mounted)
        setState(() {
          _uploadedUrl = url;
          _fileName = file.name;
          _uploading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _uploading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isAr ? 'فشل رفع الملف' : 'Upload failed',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded, size: 20),
          label: Text(
            _uploading
                ? (widget.isAr ? 'جاري الرفع...' : 'Uploading...')
                : (widget.isAr ? 'اختر ملف PDF' : 'Choose PDF file'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
        ),
        if (_fileName != null || _uploadedUrl != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.destructive, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_fileName != null)
                        Text(
                          _fileName!,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.destructive,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_uploadedUrl != null)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.destructive,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card to fetch and display session attendance (GET /api/attendance/session).
class SessionAttendanceCard extends StatefulWidget {
  final String courseId;
  final bool isAr;
  final String sessionTitle;

  const SessionAttendanceCard({
    super.key,
    required this.courseId,
    required this.isAr,
    required this.sessionTitle,
  });

  @override
  State<SessionAttendanceCard> createState() => _SessionAttendanceCardState();
}

class _SessionAttendanceCardState extends State<SessionAttendanceCard> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _fetchSession() async {
    final title = widget.sessionTitle.trim();
    if (title.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await TeacherDashboardService.instance.getAttendanceSession(
        courseId: widget.courseId,
        sessionTitle: title,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _fetchSession,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.event_available_rounded, size: 20),
              label: Text(
                (widget.isAr ? 'عرض الحضور' : 'View attendance'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.destructive, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            ..._buildAttendanceDataDisplay(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAttendanceDataDisplay() {
    final data = _result!['data'];
    List<dynamic> records = [];
    Map<String, dynamic> dataMap = {};
    if (data is List) {
      records = data;
    } else if (data is Map) {
      dataMap = Map<String, dynamic>.from(data);
      final raw = dataMap['records'] ??
          dataMap['attendees'] ??
          dataMap['students'] ??
          dataMap['attendance'] ??
          dataMap['data'];
      records = raw is List ? raw : [];
    }
    final widgets = <Widget>[];
    if (dataMap.isNotEmpty) {
      final course = dataMap['course'] is Map
          ? Map<String, dynamic>.from(dataMap['course'] as Map)
          : <String, dynamic>{};
      final sessionTitle =
          dataMap['sessionTitle'] ?? dataMap['session_title'] ?? '';
      final date = dataMap['date'] ?? '';
      final total = dataMap['total_students'] ?? records.length;
      final attendedCount = dataMap['attended_count'] ?? 0;
      final absentCount = dataMap['absent_count'] ?? 0;
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.purple.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course['title'] != null)
                Text(
                  course['title']?.toString() ?? '',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              if (sessionTitle.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sessionTitle.toString(),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (date.toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _formatAttendanceDate(date.toString(), widget.isAr),
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCountChip(
                    label: widget.isAr ? 'الحضور' : 'Attended',
                    value: attendedCount,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildCountChip(
                    label: widget.isAr ? 'الغياب' : 'Absent',
                    value: absentCount,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: 8),
                  _buildCountChip(
                    label: widget.isAr ? 'الإجمالي' : 'Total',
                    value: total is num ? total.toInt() : records.length,
                    color: AppColors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (records.isEmpty) {
      return widgets;
    }
    widgets.add(const SizedBox(height: 12));
    widgets.add(
      Text(
        widget.isAr
            ? 'السجلات (${records.length})'
            : 'Records (${records.length})',
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.foreground,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 8));
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      Map<String, dynamic> m = {};
      if (r is Map) {
        m = Map<String, dynamic>.from(r);
      }
      final user = m['user'];
      Map<String, dynamic> userMap = {};
      if (user is Map) {
        userMap = Map<String, dynamic>.from(user);
      }
      final name = userMap['name'] ??
          userMap['studentName'] ??
          userMap['userName'] ??
          m['studentName'] ??
          m['name'] ??
          m['userName'] ??
          userMap['email'] ??
          m['email'] ??
          '${widget.isAr ? "طالب" : "Student"} ${i + 1}';
      final email = userMap['email'] ?? m['email'];
      final timeRaw =
          m['time'] ?? m['attendedAt'] ?? m['createdAt'] ?? m['date'] ?? '';
      final timeStr = timeRaw.toString();
      final timeDisplay =
          timeStr.isEmpty ? '' : _formatAttendanceDate(timeStr, widget.isAr);
      final status = (m['status'] ?? 'unknown').toString().toLowerCase();
      widgets.add(_buildAttendanceRecordCard(
        name.toString(),
        email?.toString(),
        timeDisplay,
        status,
        i + 1,
      ));
    }
    return widgets;
  }

  String _formatAttendanceDate(String raw, bool isAr) {
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final locale = isAr ? 'ar' : 'en';
      return DateFormat('d MMM yyyy, h:mm a', locale).format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildCountChip(
      {required String label, required dynamic value, required Color color}) {
    final v = value is num ? value.toInt() : (value is int ? value : 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $v',
        style: GoogleFonts.cairo(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildAttendanceRecordCard(
    String name,
    String? email,
    String time,
    String status,
    int index,
  ) {
    final isAttended = status == 'attended' || status == 'present';
    final color = isAttended ? AppColors.success : AppColors.destructive;
    final icon = isAttended ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final statusLabel = isAttended
        ? (widget.isAr ? 'حضر' : 'Attended')
        : (widget.isAr ? 'غائب' : 'Absent');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.2),
            child: Text(
              '$index',
              style: GoogleFonts.cairo(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: GoogleFonts.cairo(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
