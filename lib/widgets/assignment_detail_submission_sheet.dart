import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api/api_client.dart';
import '../core/assignment_payload_utils.dart';
import '../core/design/app_colors.dart';
import '../core/services/download_manager.dart';
import '../services/courses_service.dart';
import '../services/token_storage_service.dart';
import '../services/upload_service.dart';
import '../services/video_download_service.dart';

bool _answerFormatIsMcq(String? raw) {
  final f = raw?.toLowerCase().trim() ?? '';
  return f.contains('multiple') ||
      f.contains('mcq') ||
      f == 'choice' ||
      f.contains('single');
}

bool _answerFormatIsImage(String? raw) {
  final f = raw?.toLowerCase().trim() ?? '';
  return f.contains('image');
}

/// Text / essay / default when not clearly MCQ or image-only.
bool _answerFormatIsText(String? raw) {
  final f = raw?.toLowerCase().trim() ?? '';
  if (f.isEmpty) return true;
  if (_answerFormatIsMcq(raw) || _answerFormatIsImage(raw)) return false;
  return f.contains('text') ||
      f.contains('essay') ||
      f.contains('short') ||
      f.contains('written');
}

List<String> _optionsFromQuestion(Map<String, dynamic> q) {
  dynamic raw = q['options'];
  if (raw is! List) return [];
  final out = <String>[];
  for (final o in raw) {
    if (o is String) {
      out.add(o);
    } else if (o is Map) {
      out.add(
        firstNonEmptyString([
              o['text'],
              o['label'],
              o['title'],
              o['value'],
            ]) ??
            o.toString(),
      );
    } else {
      out.add(o.toString());
    }
  }
  return out;
}

/// Bottom sheet: assignment details, PDF → app Downloads, questions (MCQ/text per API doc), submit.
class AssignmentDetailSubmissionSheet extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String? courseTitle;
  final Map<String, dynamic> details;
  final Map<String, dynamic> listRow;
  final void Function(String pdfUrl, String title) onViewPdf;
  final VoidCallback? onSubmitted;

  const AssignmentDetailSubmissionSheet({
    super.key,
    required this.courseId,
    required this.assignmentId,
    this.courseTitle,
    required this.details,
    required this.listRow,
    required this.onViewPdf,
    this.onSubmitted,
  });

  @override
  State<AssignmentDetailSubmissionSheet> createState() =>
      _AssignmentDetailSubmissionSheetState();
}

class _AssignmentDetailSubmissionSheetState
    extends State<AssignmentDetailSubmissionSheet> {
  late final TextEditingController _answerController;
  List<TextEditingController> _questionTextControllers = [];
  List<int?> _mcqSelections = [];
  List<PlatformFile?> _questionImageAnswers = [];
  final List<PlatformFile> _pdfSolutions = [];
  final List<PlatformFile> _imageSolutions = [];
  bool _downloading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    final q = assignmentQuestionsFromDetails(widget.details);
    _questionTextControllers =
        List.generate(q.length, (_) => TextEditingController());
    _mcqSelections = List<int?>.filled(q.length, null);
    _questionImageAnswers = List<PlatformFile?>.filled(q.length, null);
  }

  @override
  void dispose() {
    for (final c in _questionTextControllers) {
      c.dispose();
    }
    _answerController.dispose();
    super.dispose();
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  String get _title {
    return firstNonEmptyString([
          widget.details['title'],
          widget.listRow['title'],
        ]) ??
        (_isAr ? 'تفاصيل الواجب' : 'Assignment Details');
  }

  String get _description {
    return firstNonEmptyString([
          widget.details['description'],
          widget.listRow['description'],
        ]) ??
        '';
  }

  String get _dueDate =>
      widget.details['due_date']?.toString().trim() ?? '';

  Map<String, dynamic>? get _submission {
    final s = widget.details['my_submission'] ?? widget.details['submission'];
    if (s is Map<String, dynamic>) return s;
    if (s is Map) return Map<String, dynamic>.from(s);
    return null;
  }

  List<Map<String, dynamic>> get _questions =>
      assignmentQuestionsFromDetails(widget.details);

  String? get _pdfUrl =>
      assignmentPdfUrlFromDetails(widget.details, widget.listRow);

  int get _questionsCountHint {
    final qcRaw =
        widget.details['questions_count'] ?? widget.listRow['questions_count'];
    if (qcRaw is int) return qcRaw;
    if (qcRaw is num) return qcRaw.toInt();
    if (qcRaw is String) return int.tryParse(qcRaw) ?? 0;
    return 0;
  }

  bool get _pastDue => assignmentDueDateIsPast(_dueDate);

  bool get _alreadySubmitted {
    final sub = _submission;
    if (sub == null || sub.isEmpty) return false;

    final status = sub['status']?.toString().toLowerCase().trim() ?? '';
    if (status == 'submitted' ||
        status == 'pending' ||
        status == 'graded' ||
        status == 'reviewed' ||
        status == 'done') {
      return true;
    }

    final answerText = sub['answer_text']?.toString().trim() ?? '';
    final files = sub['answer_files'];
    final images = sub['answer_images'];
    final hasFiles = files is List && files.isNotEmpty;
    final hasImages = images is List && images.isNotEmpty;
    return answerText.isNotEmpty || hasFiles || hasImages;
  }

  Future<void> _downloadAssignmentPdfToAppDownloads() async {
    final url = _pdfUrl;
    if (url == null || url.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final token = await TokenStorageService.instance.getAccessToken();
      final safeName =
          'assignment_${widget.assignmentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await DownloadManager.download(
        url,
        name: safeName,
        authToken: token,
        onDownload: (_) {},
      );
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAr ? 'تعذر تنزيل الملف' : 'Could not download the file',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final svc = VideoDownloadService();
      await svc.initialize();
      final id = await svc.registerAssignmentPdfDownload(
        assignmentId: widget.assignmentId,
        courseId: widget.courseId,
        title: _title,
        sourceUrl: url,
        localPath: path,
        courseTitle: widget.courseTitle,
      );

      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAr ? 'تعذر حفظ الملف في التحميلات' : 'Could not save to Downloads',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAr
                ? 'تم حفظ الملف في التحميلات داخل التطبيق'
                : 'Saved to in-app Downloads',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('AssignmentDetailSubmissionSheet download: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAr ? 'حدث خطأ أثناء التحميل' : 'Download error',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickQuestionImage(int index) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.path == null || f.path!.isEmpty) return;
    setState(() => _questionImageAnswers[index] = f);
  }

  void _clearQuestionImage(int index) {
    setState(() => _questionImageAnswers[index] = null);
  }

  String _composeAnswerText() {
    final questions = _questions;
    if (questions.isEmpty) {
      return _answerController.text.trim();
    }
    final buf = StringBuffer();
    buf.writeln(_isAr ? '--- إجابات الأسئلة ---' : '--- Question answers ---');
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final label = assignmentQuestionTitle(q).trim().isEmpty
          ? '${_isAr ? 'سؤال' : 'Q'} ${i + 1}'
          : '${_isAr ? 'سؤال' : 'Q'} ${i + 1}: ${assignmentQuestionTitle(q)}';
      final aFmt = firstNonEmptyString([
        q['answer_format'],
        q['answerFormat'],
      ]);

      if (_answerFormatIsMcq(aFmt)) {
        final opts = _optionsFromQuestion(q);
        final sel = i < _mcqSelections.length ? _mcqSelections[i] : null;
        final line = (sel != null && sel >= 0 && sel < opts.length)
            ? opts[sel]
            : (_isAr ? '(لم يُختر خيار)' : '(no option selected)');
        buf.writeln('$label: $line');
      } else if (_answerFormatIsImage(aFmt)) {
        final has = i < _questionImageAnswers.length &&
            _questionImageAnswers[i] != null;
        buf.writeln(
            '$label: ${has ? (_isAr ? '[صورة مرفقة]' : '[image attached]') : (_isAr ? '[بدون صورة]' : '[no image]')}');
      } else {
        final t = i < _questionTextControllers.length
            ? _questionTextControllers[i].text.trim()
            : '';
        buf.writeln('$label: ${t.isEmpty ? '-' : t}');
      }
    }
    final extra = _answerController.text.trim();
    if (extra.isNotEmpty) {
      buf.writeln();
      buf.writeln(_isAr ? '--- ملاحظات إضافية ---' : '--- Additional notes ---');
      buf.writeln(extra);
    }
    return buf.toString().trim();
  }

  bool _hasQuestionImageAttachment() {
    return _questionImageAnswers.any((e) => e != null);
  }

  Future<void> _pickPdfSolutions() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() {
      for (final f in r.files) {
        if (f.path != null && f.path!.isNotEmpty) _pdfSolutions.add(f);
      }
    });
  }

  Future<void> _pickImageSolutions() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() {
      for (final f in r.files) {
        if (f.path != null && f.path!.isNotEmpty) _imageSolutions.add(f);
      }
    });
  }

  Future<void> _submit() async {
    if (_alreadySubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAr
                ? 'تم تسليم هذا الواجب بالفعل ولا يمكن تسليمه مرة أخرى'
                : 'This assignment is already submitted and cannot be submitted again',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pastDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAr ? 'انتهى موعد التسليم' : 'The due date has passed',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final composed = _composeAnswerText();
    final hasAttachments =
        _pdfSolutions.isNotEmpty || _imageSolutions.isNotEmpty;
    final hasQuestionImages = _hasQuestionImageAttachment();

    if (composed.isEmpty && !hasAttachments && !hasQuestionImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAr
                ? 'أجب عن الأسئلة أو أضف ملاحظات/مرفقات ثم أرسل'
                : 'Answer the questions or add notes/attachments before submitting',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final answerFiles = <String>[];
      final answerImages = <String>[];

      for (final pf in _pdfSolutions) {
        final path = pf.path;
        if (path == null) continue;
        answerFiles.add(await UploadService.instance.uploadPdf(File(path)));
      }
      for (final pf in _imageSolutions) {
        final path = pf.path;
        if (path == null) continue;
        answerImages.add(await UploadService.instance.uploadImage(File(path)));
      }

      for (var i = 0; i < _questionImageAnswers.length; i++) {
        final pf = _questionImageAnswers[i];
        if (pf?.path == null) continue;
        answerImages
            .add(await UploadService.instance.uploadImage(File(pf!.path!)));
      }

      await CoursesService.instance.submitCourseAssignment(
        widget.courseId,
        widget.assignmentId,
        answerText: composed.isNotEmpty ? composed : null,
        answerFiles: answerFiles,
        answerImages: answerImages,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      widget.onSubmitted?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isAr ? 'تم تسليم الواجب بنجاح' : 'Assignment submitted successfully',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildQuestionAnswerBlock(
    Map<String, dynamic> q,
    int index,
    String qBody,
    String? qFormat,
    String? aFormat,
  ) {
    final meta = <String>[];
    if (qFormat != null && qFormat.isNotEmpty) {
      meta.add('${_isAr ? 'شكل السؤال' : 'Question'}: $qFormat');
    }
    if (aFormat != null && aFormat.isNotEmpty) {
      meta.add('${_isAr ? 'شكل الإجابة' : 'Answer'}: $aFormat');
    }

    final opts = _optionsFromQuestion(q);
    final useMcq = _answerFormatIsMcq(aFormat) && opts.isNotEmpty;
    final useImage = _answerFormatIsImage(aFormat);
    final useText = !useMcq && !useImage && _answerFormatIsText(aFormat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. $qBody',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                meta.join(' · '),
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (useMcq)
              ...List.generate(opts.length, (o) {
                final selected =
                    index < _mcqSelections.length ? _mcqSelections[index] : null;
                return RadioListTile<int>(
                  value: o,
                  groupValue: selected,
                  onChanged: _pastDue || _submitting || _alreadySubmitted
                      ? null
                      : (v) {
                          setState(() {
                            while (_mcqSelections.length <= index) {
                              _mcqSelections.add(null);
                            }
                            _mcqSelections[index] = v;
                          });
                        },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opts[o],
                    style: GoogleFonts.cairo(fontSize: 14),
                  ),
                );
              })
            else if (useImage) ...[
              if (index < _questionImageAnswers.length &&
                  _questionImageAnswers[index] != null)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.image, color: AppColors.purple, size: 22),
                  title: Text(
                    _questionImageAnswers[index]!.name,
                    style: GoogleFonts.cairo(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                      onPressed: _pastDue || _submitting || _alreadySubmitted
                        ? null
                        : () => _clearQuestionImage(index),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pastDue || _submitting || _alreadySubmitted
                      ? null
                      : () => _pickQuestionImage(index),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: Text(
                    _isAr ? 'إرفاق صورة للإجابة' : 'Attach answer image',
                    style: GoogleFonts.cairo(),
                  ),
                ),
            ]
            else if (aFormat != null &&
                aFormat.toLowerCase().contains('audio'))
              Text(
                _isAr
                    ? 'إجابة الصوت غير متاحة في التطبيق حالياً'
                    : 'Audio answers are not supported in the app yet',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              )
            else if (useText || !_answerFormatIsImage(aFormat))
              index < _questionTextControllers.length
                  ? TextField(
                      controller: _questionTextControllers[index],
                      minLines: 2,
                      maxLines: 5,
                      enabled: !_pastDue && !_submitting && !_alreadySubmitted,
                      decoration: InputDecoration(
                        hintText:
                            _isAr ? 'اكتب إجابتك' : 'Type your answer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      style: GoogleFonts.cairo(fontSize: 14),
                    )
                  : Text(
                      _isAr
                          ? 'تعذر عرض حقل الإجابة'
                          : 'Could not load answer field',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = _submission;
    final status = sub?['status']?.toString();
    final score = sub?['score']?.toString();
    final teacherNote = sub?['teacher_note']?.toString();
    final lockSubmission = _alreadySubmitted;
    final hasPdf = _pdfUrl != null && _pdfUrl!.isNotEmpty;
    final questions = _questions;
    final hasQuestions = questions.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              if (_dueDate.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_isAr ? 'موعد التسليم' : 'Due date'}: $_dueDate',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (_pastDue)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _isAr
                          ? 'انتهى موعد التسليم — لا يمكن الإرسال'
                          : 'Due date passed — submission is disabled',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                _description.isEmpty
                    ? (_isAr ? 'لا يوجد وصف' : 'No description')
                    : _description,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
              if (hasPdf) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final u = _pdfUrl!;
                          Navigator.of(context).pop();
                          widget.onViewPdf(u, _title);
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(
                          _isAr ? 'عرض PDF' : 'View PDF',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            _downloading || _submitting || _pastDue
                                ? null
                                : _downloadAssignmentPdfToAppDownloads,
                        icon: _downloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _isAr ? 'حفظ في التحميلات' : 'Save to Downloads',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (hasQuestions) ...[
                const SizedBox(height: 20),
                Text(
                  _isAr ? 'الأسئلة والإجابات' : 'Questions & answers',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(questions.length, (i) {
                  final q = questions[i];
                  final qTitle = assignmentQuestionTitle(q);
                  final qBody = qTitle.isEmpty
                      ? (_isAr ? 'سؤال ${i + 1}' : 'Question ${i + 1}')
                      : qTitle;
                  final qFormat = firstNonEmptyString([
                    q['question_format'],
                    q['questionFormat'],
                  ]);
                  final aFormat = firstNonEmptyString([
                    q['answer_format'],
                    q['answerFormat'],
                  ]);
                  return _buildQuestionAnswerBlock(
                    q,
                    i,
                    qBody,
                    qFormat,
                    aFormat,
                  );
                }),
              ] else if (_questionsCountHint > 0 && !hasPdf) ...[
                const SizedBox(height: 16),
                Text(
                  _isAr
                      ? 'يحتوي هذا الواجب على $_questionsCountHint سؤالًا (لم تُرجع واجهة البرمجة قائمة الأسئلة بعد).'
                      : 'This assignment has $_questionsCountHint question(s); the API did not return a questions list.',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ] else if (!hasPdf && !hasQuestions) ...[
                const SizedBox(height: 16),
                Text(
                  _isAr
                      ? 'لا يوجد ملف PDF أو أسئلة في بيانات هذا الواجب.'
                      : 'No PDF attachment or questions were found in this assignment payload.',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (status != null && status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '${_isAr ? 'الحالة' : 'Status'}: $status',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ],
              if (lockSubmission) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isAr
                              ? 'تم تسليم هذا الواجب بالفعل. لا يمكن تعديل الإجابات أو إعادة الرفع.'
                              : 'This assignment is already submitted. Answers and uploads are now locked.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (score != null && score.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_isAr ? 'الدرجة' : 'Score'}: $score',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
              ],
              if (teacherNote != null && teacherNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_isAr ? 'ملاحظة المعلم' : 'Teacher note'}: $teacherNote',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                _isAr ? 'ملاحظات إضافية (اختياري)' : 'Additional notes (optional)',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _answerController,
                minLines: 2,
                maxLines: 6,
                enabled: !_pastDue && !_submitting && !lockSubmission,
                decoration: InputDecoration(
                  hintText: _isAr
                      ? 'أي تفاصيل إضافية للمعلم…'
                      : 'Any extra details for the instructor…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: GoogleFonts.cairo(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                _isAr ? 'مرفقات إضافية (اختياري)' : 'Extra attachments (optional)',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pastDue || _submitting || lockSubmission
                        ? null
                        : _pickPdfSolutions,
                    icon: const Icon(Icons.upload_file_rounded, size: 20),
                    label: Text(
                      _isAr ? 'إرفاق PDF' : 'Attach PDF',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pastDue || _submitting || lockSubmission
                        ? null
                        : _pickImageSolutions,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                    label: Text(
                      _isAr ? 'إرفاق صور' : 'Attach images',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                ],
              ),
              if (_pdfSolutions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _isAr ? 'ملفات PDF:' : 'PDF files:',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...List.generate(_pdfSolutions.length, (i) {
                  final name = _pdfSolutions[i].name;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(
                      name,
                      style: GoogleFonts.cairo(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _submitting || lockSubmission
                          ? null
                          : () => setState(() => _pdfSolutions.removeAt(i)),
                    ),
                  );
                }),
              ],
              if (_imageSolutions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _isAr ? 'صور إضافية:' : 'Extra images:',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...List.generate(_imageSolutions.length, (i) {
                  final name = _imageSolutions[i].name;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image, color: AppColors.purple),
                    title: Text(
                      name,
                      style: GoogleFonts.cairo(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _submitting || lockSubmission
                          ? null
                          : () => setState(() => _imageSolutions.removeAt(i)),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      _pastDue || _submitting || lockSubmission ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isAr ? 'تسليم الواجب' : 'Submit assignment',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
