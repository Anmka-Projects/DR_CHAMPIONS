import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/app_colors.dart';
import '../../services/token_storage_service.dart';

/// PDF Viewer Screen - Display PDF files using flutter_pdfview
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String? title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _errorMessage;
  PDFViewController? _pdfViewController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  File? _tempPdfFile;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Get authorization token for PDF access
      final token = await TokenStorageService.instance.getAccessToken();

      String pdfUrl = widget.pdfUrl;

      if (kDebugMode) {
        print('📄 Loading PDF: $pdfUrl');
        print('🔑 Token exists: ${token != null && token.isNotEmpty}');
      }

      // Build PDF URL with token as query parameter (for fallback)
      String pdfUrlWithToken = pdfUrl;
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse(pdfUrl);
        pdfUrlWithToken = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'token': token,
        }).toString();
      }

      // Try to download PDF with Authorization header first
      File? pdfFile;
      if (token != null && token.isNotEmpty) {
        // Method 1: Try with Authorization header
        try {
          if (kDebugMode) {
            print(
                '📥 Downloading PDF via Flutter HTTP request with Authorization header...');
          }

          final headers = <String, String>{
            'Authorization': 'Bearer $token',
          };

          final response = await http
              .get(
                Uri.parse(pdfUrl),
                headers: headers,
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            if (kDebugMode) {
              print(
                  '✅ PDF downloaded successfully via HTTP (${response.bodyBytes.length} bytes)');
            }

            // Check if response is actually a PDF
            final contentType = response.headers['content-type'] ?? '';
            if (contentType.contains('pdf') ||
                response.bodyBytes.length > 100 &&
                    String.fromCharCodes(response.bodyBytes.take(4)) ==
                        '%PDF') {
              pdfFile = await _savePdfToFile(response.bodyBytes);
            } else {
              if (kDebugMode) {
                print('⚠️ Response is not a PDF file');
              }
            }
          } else {
            if (kDebugMode) {
              print(
                  '❌ HTTP request failed with status: ${response.statusCode}');
              if (response.statusCode == 404) {
                print('⚠️ PDF file not found with Authorization header');
                print('   Will try with token as query parameter...');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                '⚠️ Failed to download PDF via HTTP with Authorization header: $e');
            print('   Will try with token as query parameter...');
          }
        }

        // Method 2: If Authorization header failed, try with token as query parameter
        if (pdfFile == null) {
          try {
            if (kDebugMode) {
              print(
                  '📥 Trying PDF download via Flutter HTTP request with token as query parameter...');
            }

            final response = await http
                .get(
                  Uri.parse(pdfUrlWithToken),
                )
                .timeout(const Duration(seconds: 30));

            if (response.statusCode == 200) {
              if (kDebugMode) {
                print(
                    '✅ PDF downloaded successfully via HTTP with token param (${response.bodyBytes.length} bytes)');
              }

              // Check if response is actually a PDF
              final contentType = response.headers['content-type'] ?? '';
              if (contentType.contains('pdf') ||
                  response.bodyBytes.length > 100 &&
                      String.fromCharCodes(response.bodyBytes.take(4)) ==
                          '%PDF') {
                pdfFile = await _savePdfToFile(response.bodyBytes);
              }
            } else {
              if (kDebugMode) {
                print(
                    '❌ HTTP request with token param failed with status: ${response.statusCode}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to download PDF via HTTP with token param: $e');
            }
          }
        }
      } else {
        // Try without authentication
        try {
          if (kDebugMode) {
            print('📥 Trying PDF download without authentication...');
          }

          final response = await http
              .get(
                Uri.parse(pdfUrl),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final contentType = response.headers['content-type'] ?? '';
            if (contentType.contains('pdf') ||
                response.bodyBytes.length > 100 &&
                    String.fromCharCodes(response.bodyBytes.take(4)) ==
                        '%PDF') {
              pdfFile = await _savePdfToFile(response.bodyBytes);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to download PDF without authentication: $e');
          }
        }
      }

      if (pdfFile != null && pdfFile.existsSync()) {
        if (mounted) {
          setState(() {
            _localPath = pdfFile!.path;
            _isLoading = false;
            _tempPdfFile = pdfFile;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'فشل تحميل الملف. يرجى التحقق من الاتصال بالإنترنت أو أن الملف موجود.';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading PDF: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطأ في تحميل الملف: ${e.toString()}';
        });
      }
    }
  }

  Future<File> _savePdfToFile(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = widget.pdfUrl.split('/').last.split('?').first;
    final fileExtension =
        fileName.contains('.') ? fileName.split('.').last : 'pdf';
    final file = File(
        '${tempDir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');

    await file.writeAsBytes(bytes);

    if (kDebugMode) {
      print('💾 PDF saved to temporary file: ${file.path}');
    }

    return file;
  }

  @override
  void dispose() {
    _pdfViewController?.dispose();
    // Clean up temporary PDF file
    if (_tempPdfFile != null) {
      try {
        _tempPdfFile!.deleteSync();
        if (kDebugMode) {
          print('🗑️ Deleted temporary PDF file: ${_tempPdfFile!.path}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error deleting temp PDF file: $e');
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.purple,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? 'معاينة الملف',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isReady && _totalPages > 0)
                          Text(
                            'صفحة $_currentPage من $_totalPages',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          )
                        else
                          Text(
                            'PDF',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Page navigation buttons
                  if (_isReady && _totalPages > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentPage > 0
                          ? () {
                              _pdfViewController?.setPage(_currentPage - 1);
                            }
                          : null,
                      color: AppColors.purple,
                      iconSize: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage < _totalPages - 1
                          ? () {
                              _pdfViewController?.setPage(_currentPage + 1);
                            }
                          : null,
                      color: AppColors.purple,
                      iconSize: 24,
                    ),
                  ],
                ],
              ),
            ),

            // PDF Viewer
            Expanded(
              child: _isLoading
                  ? Container(
                      color: const Color(0xFFF5F5F5),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.purple,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'جاري تحميل الملف...',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _errorMessage != null
                      ? Container(
                          color: const Color(0xFFF5F5F5),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      color: AppColors.foreground,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isLoading = true;
                                          _errorMessage = null;
                                        });
                                        _loadPdf();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.purple,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'إعادة المحاولة',
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : _localPath != null
                          ? PDFView(
                              filePath: _localPath!,
                              enableSwipe: true,
                              swipeHorizontal: false,
                              autoSpacing: true,
                              pageFling: true,
                              pageSnap: true,
                              defaultPage: _currentPage,
                              fitPolicy: FitPolicy.BOTH,
                              preventLinkNavigation: false,
                              onRender: (pages) {
                                if (mounted) {
                                  setState(() {
                                    _totalPages = pages ?? 0;
                                    _isReady = true;
                                  });
                                }
                              },
                              onError: (error) {
                                if (kDebugMode) {
                                  print('❌ PDF View error: $error');
                                }
                                if (mounted) {
                                  setState(() {
                                    _errorMessage =
                                        'خطأ في عرض الملف: ${error.toString()}';
                                  });
                                }
                              },
                              onPageError: (page, error) {
                                if (kDebugMode) {
                                  print(
                                      '❌ PDF Page error (page $page): $error');
                                }
                              },
                              onViewCreated: (PDFViewController controller) {
                                _pdfViewController = controller;
                              },
                              onLinkHandler: (String? uri) {
                                if (kDebugMode) {
                                  print('🔗 PDF Link clicked: $uri');
                                }
                              },
                              onPageChanged: (int? page, int? total) {
                                if (mounted) {
                                  setState(() {
                                    _currentPage = page ?? 0;
                                    _totalPages = total ?? 0;
                                  });
                                }
                              },
                            )
                          : Container(
                              color: const Color(0xFFF5F5F5),
                              child: Center(
                                child: Text(
                                  'لا يمكن عرض الملف',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
