// Helpers for lesson resources (Google Drive, PDF detection).

/// Extracts a Google Drive **file** id from common share / open URL shapes.
String? googleDriveFileIdFromUrl(String raw) {
  final u = raw.trim();
  if (u.isEmpty) return null;
  final fileMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(u);
  if (fileMatch != null) return fileMatch.group(1);

  final uri = Uri.tryParse(u.startsWith('http') ? u : 'https://$u');
  if (uri == null) return null;
  final idParam = uri.queryParameters['id']?.trim();
  if (idParam != null && idParam.isNotEmpty) return idParam;

  return null;
}

/// Extracts a Google Drive **folder** id when present.
String? googleDriveFolderIdFromUrl(String raw) {
  final u = raw.trim();
  final m = RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(u);
  return m?.group(1);
}

/// In-app preview URL for Drive files (works for many PDFs / docs in WebView).
String? googleDriveFilePreviewUrl(String raw) {
  final id = googleDriveFileIdFromUrl(raw);
  if (id == null) return null;
  return 'https://drive.google.com/file/d/$id/preview';
}

/// Embedded folder view (read-only tree in WebView).
String? googleDriveFolderEmbedUrl(String raw) {
  final id = googleDriveFolderIdFromUrl(raw);
  if (id == null) return null;
  return 'https://drive.google.com/embeddedfolderview?id=$id';
}

/// Direct download attempt (binary); useful for [PdfViewerScreen] when UC works.
String? googleDriveDirectDownloadUrl(String raw) {
  final id = googleDriveFileIdFromUrl(raw);
  if (id == null) return null;
  return 'https://drive.google.com/uc?export=download&id=$id';
}

bool isGoogleDriveUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('drive.google.com') ||
      lower.contains('docs.google.com');
}

/// Whether a URL/title should be treated as PDF for in-app viewing.
bool resourceLooksLikePdf(String url, String title) {
  final u = url.toLowerCase();
  final t = title.toLowerCase();
  if (u.contains('.pdf') ||
      (u.contains('export=download') && u.contains('id=')) ||
      u.contains('/export?format=pdf') ||
      u.contains('application/pdf')) {
    return true;
  }
  if (t.contains('pdf') || t.contains('.pdf')) return true;
  if (isGoogleDriveUrl(url) &&
      (t.contains('pdf') || u.contains('filetype=pdf'))) {
    return true;
  }
  return false;
}
