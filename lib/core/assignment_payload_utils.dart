import 'api/api_endpoints.dart';

/// Questions array from assignment details (`data` is merged by [CoursesService]).
List<Map<String, dynamic>> assignmentQuestionsFromDetails(
    Map<String, dynamic> details) {
  dynamic raw = details['questions'];
  if (raw == null && details['data'] is Map) {
    raw = (details['data'] as Map)['questions'];
  }
  if (raw is! List) return [];
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      out.add(Map<String, dynamic>.from(item));
    } else if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
}

String? firstNonEmptyString(Iterable<dynamic> values) {
  for (final v in values) {
    final s = v?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

bool looksLikePdfUrl(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.pdf')) return true;
  if (lower.contains('/documents/')) return true;
  if (lower.contains('pdf')) return true;
  return false;
}

/// Resolves a PDF URL for document-style assignments (relative paths via [ApiEndpoints.getImageUrl]).
String? assignmentPdfUrlFromDetails(
  Map<String, dynamic> details,
  Map<String, dynamic> listRow,
) {
  const keys = [
    'source_file_url',
    'sourceFileUrl',
    'pdf_url',
    'pdfUrl',
    'file_url',
    'fileUrl',
    'document_url',
    'attachment_url',
    'resource_url',
  ];
  String? resolved;
  for (final k in keys) {
    final cand = firstNonEmptyString([details[k], listRow[k]]);
    if (cand != null && looksLikePdfUrl(cand)) {
      resolved = cand;
      break;
    }
  }
  if (resolved == null) {
    for (final src in [details, listRow]) {
      final att = src['attachments'];
      if (att is Map) {
        for (final listKey in ['pdfs', 'files', 'documents']) {
          final list = att[listKey];
          if (list is! List) continue;
          for (final p in list) {
            final s = p?.toString().trim();
            if (s != null && s.isNotEmpty && looksLikePdfUrl(s)) {
              resolved = s;
              break;
            }
          }
          if (resolved != null) break;
        }
      }
      if (resolved != null) break;
    }
  }
  if (resolved == null) return null;
  return ApiEndpoints.getImageUrl(resolved);
}

String assignmentQuestionTitle(Map<String, dynamic> q) {
  return firstNonEmptyString([
        q['title'],
        q['question'],
        q['question_text'],
        q['text'],
        q['body'],
      ]) ??
      '';
}

bool assignmentDueDateIsPast(String? dueRaw) {
  if (dueRaw == null || dueRaw.isEmpty) return false;
  final dt = DateTime.tryParse(dueRaw);
  if (dt == null) return false;
  return DateTime.now().isAfter(dt);
}
