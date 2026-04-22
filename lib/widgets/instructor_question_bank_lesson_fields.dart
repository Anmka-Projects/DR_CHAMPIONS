import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/design/app_colors.dart';
import '../services/question_bank_service.dart';
import '../services/upload_service.dart';

/// Pick or upload a question bank for a curriculum lesson (`type: question_bank`).
class InstructorQuestionBankLessonFields extends StatefulWidget {
  final String courseId;
  final bool isAr;
  final String? initialBankId;
  final String? initialFileUrl;
  final void Function(String? bankId, String? fileUrl) onChanged;

  const InstructorQuestionBankLessonFields({
    super.key,
    required this.courseId,
    required this.isAr,
    this.initialBankId,
    this.initialFileUrl,
    required this.onChanged,
  });

  @override
  State<InstructorQuestionBankLessonFields> createState() =>
      _InstructorQuestionBankLessonFieldsState();
}

class _InstructorQuestionBankLessonFieldsState
    extends State<InstructorQuestionBankLessonFields> {
  List<Map<String, dynamic>> _banks = [];
  bool _loading = true;
  bool _uploading = false;
  String? _selectedId;
  String? _fileUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialBankId;
    _fileUrl = widget.initialFileUrl;
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    if (widget.courseId.isEmpty) {
      setState(() {
        _loading = false;
        _banks = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await QuestionBankService.instance.listQuestionBanks(widget.courseId);
      if (!mounted) return;
      setState(() {
        _banks = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _uploadNew() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv', 'xlsx', 'xls'],
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? resp;
      try {
        resp = await QuestionBankService.instance.uploadQuestionBankMultipart(
          file,
          courseId: widget.courseId,
          title: pick.files.single.name,
        );
      } catch (_) {
        resp = null;
      }
      final id = resp != null ? QuestionBankService.extractBankId(resp) : null;
      final url = resp != null
          ? QuestionBankService.extractFileUrl(resp)
          : null;
      final finalUrl = (url != null && url.isNotEmpty)
          ? url
          : await UploadService.instance.uploadQuestionBankFile(file);

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _selectedId = id;
        _fileUrl = finalUrl;
      });
      widget.onChanged(_selectedId, _fileUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _bankTitle(Map<String, dynamic> b) {
    return b['title']?.toString() ??
        b['name']?.toString() ??
        b['id']?.toString() ??
        '';
  }

  String _bankId(Map<String, dynamic> b) {
    return b['id']?.toString() ?? b['question_bank_id']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isAr
              ? 'ارفع ملف بنك أسئلة (JSON / Excel / CSV) أو اختر بنكاً مسجلاً للدورة.'
              : 'Upload a question bank file (JSON / Excel / CSV) or pick one registered for this course.',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: AppColors.mutedForeground,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadNew,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_rounded, size: 20),
          label: Text(
            _uploading
                ? (widget.isAr ? 'جاري الرفع...' : 'Uploading...')
                : (widget.isAr ? 'رفع ملف بنك أسئلة' : 'Upload question bank'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
        ),
        if (_fileUrl != null && _fileUrl!.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            '${widget.isAr ? 'رابط الملف' : 'File URL'}: $_fileUrl',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.purple),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              widget.isAr ? 'بنوك مسجلة للدورة' : 'Course question banks',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _loading ? null : _loadBanks,
              child: Text(
                widget.isAr ? 'تحديث' : 'Refresh',
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_banks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              widget.isAr
                  ? 'لا توجد بنوك مسجلة بعد. استخدم الرفع أعلاه.'
                  : 'No banks listed yet. Use upload above.',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: _banks.map((b) {
                final id = _bankId(b);
                if (id.isEmpty) return const SizedBox.shrink();
                return RadioListTile<String>(
                  dense: true,
                  value: id,
                  groupValue: _selectedId,
                  title: Text(
                    _bankTitle(b),
                    style: GoogleFonts.cairo(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _selectedId = v;
                      _fileUrl = null;
                    });
                    widget.onChanged(_selectedId, _fileUrl);
                  },
                );
              }).toList(),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.destructive),
            ),
          ),
      ],
    );
  }
}
