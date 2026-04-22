import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_radius.dart';
import '../services/question_bank_service.dart';
import '../services/upload_service.dart';

/// Course-level panel: upload question banks and list those returned by the API.
class InstructorQuestionBanksPanel extends StatefulWidget {
  final String courseId;
  final bool isAr;

  const InstructorQuestionBanksPanel({
    super.key,
    required this.courseId,
    required this.isAr,
  });

  @override
  State<InstructorQuestionBanksPanel> createState() =>
      _InstructorQuestionBanksPanelState();
}

class _InstructorQuestionBanksPanelState
    extends State<InstructorQuestionBanksPanel> {
  List<Map<String, dynamic>> _banks = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.courseId.isEmpty) return;
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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _upload() async {
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
      try {
        await QuestionBankService.instance.uploadQuestionBankMultipart(
          file,
          courseId: widget.courseId,
          title: pick.files.single.name,
        );
      } catch (_) {
        await UploadService.instance.uploadQuestionBankFile(file);
      }
      if (!mounted) return;
      setState(() => _uploading = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr ? 'تم رفع بنك الأسئلة' : 'Question bank uploaded',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr ? 'فشل الرفع' : 'Upload failed',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  String _titleOf(Map<String, dynamic> b) {
    return b['title']?.toString() ??
        b['name']?.toString() ??
        b['id']?.toString() ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded, color: AppColors.purple, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isAr ? 'بنوك الأسئلة' : 'Question banks',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(
                  widget.isAr ? 'رفع' : 'Upload',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAr
                ? 'JSON أو Excel أو CSV. يمكن ربط البنك بدرس من نوع «بنك أسئلة» داخل الجلسة.'
                : 'JSON, Excel, or CSV. Link a bank to a lesson using lesson type «Question bank».',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.35,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.destructive),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_banks.isEmpty)
            Text(
              widget.isAr
                  ? 'لا توجد بنوك في القائمة (قد يعتمد السيرفر على الرفع فقط).'
                  : 'No banks in list (server may rely on upload only).',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          else
            ..._banks.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_rounded,
                        size: 18, color: AppColors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _titleOf(b),
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
