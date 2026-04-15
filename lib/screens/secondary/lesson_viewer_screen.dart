import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
// ignore: implementation_imports — PodPlayerController does not expose playback speed; same instance Get.put uses internally.
import 'package:pod_player/src/controllers/pod_getx_video_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../l10n/app_localizations.dart';
import '../../services/courses_service.dart';
import '../../services/lesson_resume_service.dart';
import '../../services/profile_service.dart';
import '../../services/token_storage_service.dart';
import '../../services/video_download_service.dart';
import '../../services/youtube_video_service.dart';

class _LessonResumeSnapshot {
  final String courseId;
  final String lessonId;
  final String? lessonTitle;
  final int positionMs;
  final int videoIndex;
  final int audioIndex;
  final int watchedSeconds;
  final bool lessonMarkedComplete;

  const _LessonResumeSnapshot({
    required this.courseId,
    required this.lessonId,
    this.lessonTitle,
    required this.positionMs,
    required this.videoIndex,
    required this.audioIndex,
    required this.watchedSeconds,
    required this.lessonMarkedComplete,
  });
}

/// Lesson Viewer Screen - Modern & Eye-Friendly Design
class LessonViewerScreen extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final String? courseId;

  const LessonViewerScreen({super.key, this.lesson, this.courseId});

  @override
  State<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends State<LessonViewerScreen>
    with WidgetsBindingObserver {
  PodPlayerController? _controller;
  WebViewController? _webViewController;
  WebViewController? _descriptionWebViewController;
  String? _lastDescriptionHtmlLoaded;
  bool _isVideoLoading = true;
  bool _isLoadingContent = true;
  bool _useWebViewFallback = false;
  bool _isVimeoVideo = false;
  String? _vimeoId;
  Map<String, dynamic>? _lessonContent;
  File? _tempVideoFile;
  final VideoDownloadService _downloadService = VideoDownloadService();
  bool _isDownloading = false;
  int _downloadProgress = 0;
  bool _isDownloaded = false;
  AudioPlayer? _audioPlayer;
  bool _isAudioLesson = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isAudioPlaying = false;
  bool _isAudioDurationKnown = false;
  Timer? _progressTimer;
  int _watchedSeconds = 0;
  bool _lessonMarkedComplete = false;
  List<String> _allAudioUrls = [];
  int _currentAudioIndex = 0;
  List<String> _allVideoUrls = [];
  int _currentVideoIndex = 0;
  late final String _watermarkSessionTag;
  String _watermarkUserName = 'User';
  bool _isForcingPortrait = false;
  Map<String, dynamic>? _pendingResume;
  bool _consumedVideoResumeSeek = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watermarkSessionTag =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _loadWatermarkUserName();
    _initializeDownloadService();
    _loadLessonContent().then((_) {
      // Initialize video after content is loaded (or failed)
      // This ensures we can use video data from the API response
      _initializeVideo();
      _startProgressTracking();
      _checkIfDownloaded();
    });
  }

  bool _looksLikeHtml(String? text) {
    if (text == null) return false;
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t.contains('<img') ||
        t.contains('<p') ||
        t.contains('<br') ||
        t.contains('<div') ||
        t.contains('<span') ||
        t.contains('<ul') ||
        t.contains('<ol') ||
        t.contains('<table') ||
        t.contains('<a ') ||
        t.contains('</');
  }

  Future<void> _loadWatermarkUserName() async {
    try {
      final profile = await ProfileService.instance.getProfile();
      final name = profile['name']?.toString().trim();
      if (!mounted) return;
      if (name != null && name.isNotEmpty) {
        setState(() => _watermarkUserName = name);
      }
    } catch (_) {
      // Keep fallback.
    }
  }

  Future<void> _loadPendingResume() async {
    _pendingResume = null;
    final lesson = widget.lesson;
    if (lesson == null) return;

    String? courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      courseId =
          lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    }
    final lessonId = lesson['id']?.toString();
    if (courseId == null ||
        courseId.isEmpty ||
        lessonId == null ||
        lessonId.isEmpty) {
      return;
    }

    final saved =
        await LessonResumeService.instance.getLastOpenedLesson(courseId);
    if (saved?['lessonId']?.toString() == lessonId) {
      _pendingResume = saved;
      final ws = int.tryParse(saved!['watchedSeconds']?.toString() ?? '');
      if (ws != null && ws > _watchedSeconds) {
        _watchedSeconds = ws;
      }
    }
  }

  Future<void> _onPodControllerInitialized(
      {bool clearWebViewFallback = false}) async {
    if (!mounted || _controller == null) return;
    final c = _controller!;
    c.addListener(() {
      if (_didVideoReachEnd(c)) {
        _markLessonComplete();
      }
    });
    if (mounted) {
      setState(() {
        _isVideoLoading = false;
        if (clearWebViewFallback) _useWebViewFallback = false;
      });
    }
    await _seekPodToSavedPositionIfNeededOnce();
  }

  Future<void> _seekPodToSavedPositionIfNeededOnce() async {
    if (_consumedVideoResumeSeek) return;
    final pr = _pendingResume;
    final c = _controller;
    if (pr == null || c == null) return;
    final ms = int.tryParse(pr['positionMs']?.toString() ?? '') ?? 0;
    if (ms <= 0) return;
    _consumedVideoResumeSeek = true;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _controller != c) return;
    try {
      await c.videoSeekTo(Duration(milliseconds: ms));
    } catch (_) {}
  }

  _LessonResumeSnapshot _captureResumeSnapshot() {
    final lesson = widget.lesson;
    var courseId = widget.courseId ?? '';
    if (lesson != null && courseId.isEmpty) {
      courseId = lesson['course_id']?.toString() ??
          lesson['courseId']?.toString() ??
          '';
    }
    final lessonId = lesson?['id']?.toString() ?? '';
    final title = lesson?['title']?.toString();

    var positionMs = 0;
    final vIdx = _currentVideoIndex;
    final aIdx = _currentAudioIndex;

    if (_controller != null) {
      try {
        final dynamic c = _controller!;
        final pos = c.currentVideoPosition as Duration?;
        positionMs = pos?.inMilliseconds ?? 0;
      } catch (_) {}
    } else if (_isAudioLesson && _audioPlayer != null) {
      positionMs = _audioPosition.inMilliseconds;
    }

    var watched = _watchedSeconds;
    final secFromPosition = (positionMs / 1000).round();
    if (secFromPosition > watched) watched = secFromPosition;

    return _LessonResumeSnapshot(
      courseId: courseId,
      lessonId: lessonId,
      lessonTitle: title,
      positionMs: positionMs,
      videoIndex: vIdx,
      audioIndex: aIdx,
      watchedSeconds: watched,
      lessonMarkedComplete: _lessonMarkedComplete,
    );
  }

  Future<void> _persistResumeSnapshot(_LessonResumeSnapshot s) async {
    if (s.courseId.isEmpty || s.lessonId.isEmpty) return;
    try {
      await LessonResumeService.instance.saveLastOpenedLesson(
        courseId: s.courseId,
        lessonId: s.lessonId,
        lessonTitle: s.lessonTitle,
        positionMs: s.positionMs,
        videoIndex: s.videoIndex,
        audioIndex: s.audioIndex,
        watchedSeconds: s.watchedSeconds,
        markLessonCompletedId:
            s.lessonMarkedComplete ? s.lessonId : null,
      );
    } catch (_) {}

    if (!s.lessonMarkedComplete) {
      try {
        await CoursesService.instance.updateLessonProgress(
          s.courseId,
          s.lessonId,
          watchedSeconds: s.watchedSeconds,
          isCompleted: false,
        );
      } catch (_) {}
    }
  }

  Future<void> _applySavedAudioResumeIfNeeded() async {
    if (!_isAudioLesson || _pendingResume == null || _audioPlayer == null) {
      return;
    }
    final pr = _pendingResume!;
    final aIdx = int.tryParse(pr['audioIndex']?.toString() ?? '') ?? 0;
    if (aIdx > 0 && aIdx < _allAudioUrls.length) {
      await _loadAudioTrack(aIdx);
    }
    final ms = int.tryParse(pr['positionMs']?.toString() ?? '') ?? 0;
    if (ms > 0) {
      try {
        await _audioPlayer!.seek(Duration(milliseconds: ms));
      } catch (_) {}
    }
  }

  Widget _buildVideoWatermarkOverlay() {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final watermark = '$_watermarkUserName • $_watermarkSessionTag';
    final style = GoogleFonts.cairo(
      fontSize: isLandscape ? 11 : 12,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.35),
      height: 1.2,
    );

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: isLandscape ? 12 : 14,
          bottom: isLandscape ? 10 : 12,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(watermark, style: style),
        ),
      ),
    );
  }

  void _ensureDescriptionWebViewLoaded(String description) {
    if (!_looksLikeHtml(description)) return;
    if (_lastDescriptionHtmlLoaded == description &&
        _descriptionWebViewController != null) {
      return;
    }

    final html = '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial; margin: 0; padding: 0; color: #1F2937; }
      img { max-width: 100% !important; height: auto !important; display: block; margin: 10px 0; }
      iframe, video { max-width: 100%; }
      a { color: #6D28D9; word-break: break-word; }
      * { box-sizing: border-box; }
      .container { padding: 0; }
    </style>
  </head>
  <body>
    <div class="container">
      $description
    </div>
  </body>
</html>
''';

    _descriptionWebViewController ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (kDebugMode) {
              print('❌ Description WebView error: ${error.description}');
            }
          },
        ),
      );

    _lastDescriptionHtmlLoaded = description;
    _descriptionWebViewController!.loadHtmlString(html);
  }

  List<String> _collectLessonImageUrls() {
    final urls = <String>{};

    void addIfValid(dynamic v) {
      final s = v?.toString();
      if (s == null) return;
      final t = s.trim();
      if (t.isEmpty) return;
      if (t.startsWith('http://') || t.startsWith('https://')) {
        urls.add(t);
      }
    }

    final lessonImages = widget.lesson?['images'];
    if (lessonImages is List) {
      for (final u in lessonImages) {
        addIfValid(u);
      }
    }

    final lessonImageUrls = widget.lesson?['image_urls'];
    if (lessonImageUrls is List) {
      for (final u in lessonImageUrls) {
        addIfValid(u);
      }
    }

    final media = widget.lesson?['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final type = m['type']?.toString().toLowerCase();
          if (type == 'image') addIfValid(m['file_path']);
        }
      }
    }

    final contentImages = _lessonContent?['image_urls'];
    if (contentImages is List) {
      for (final u in contentImages) {
        addIfValid(u);
      }
    }

    return urls.toList();
  }

  Widget _buildImagesSection(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded,
                    color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'صور الدرس',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final url = imageUrls[index];
                return GestureDetector(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Text(
                                          'تعذر تحميل الصورة',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 86,
                      height: 86,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.mutedForeground, size: 22),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: imageUrls.length,
            ),
          ),
        ],
      ),
    );
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      bool isPlaying = false;
      if (_controller != null) {
        try {
          final dynamic dynamicController = _controller!;
          isPlaying = dynamicController.isVideoPlaying == true;
        } catch (_) {
          isPlaying = false;
        }
      }
      if (isPlaying) {
        _watchedSeconds += 30;
        try {
          await CoursesService.instance.updateLessonProgress(
            widget.courseId ?? widget.lesson?['course_id']?.toString() ?? '',
            widget.lesson?['id']?.toString() ?? '',
            watchedSeconds: _watchedSeconds,
            isCompleted: false,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> _markLessonComplete() async {
    if (_lessonMarkedComplete) return;
    _lessonMarkedComplete = true;
    final courseId =
        widget.courseId ?? widget.lesson?['course_id']?.toString() ?? '';
    final lessonId = widget.lesson?['id']?.toString() ?? '';
    final snap = _captureResumeSnapshot();
    try {
      await CoursesService.instance.updateLessonProgress(
        courseId,
        lessonId,
        watchedSeconds: snap.watchedSeconds,
        isCompleted: true,
      );
    } catch (_) {}
    if (courseId.isNotEmpty && lessonId.isNotEmpty) {
      try {
        await LessonResumeService.instance.saveLastOpenedLesson(
          courseId: courseId,
          lessonId: lessonId,
          lessonTitle: widget.lesson?['title']?.toString(),
          positionMs: snap.positionMs,
          videoIndex: snap.videoIndex,
          audioIndex: snap.audioIndex,
          watchedSeconds: snap.watchedSeconds,
          markLessonCompletedId: lessonId,
        );
      } catch (_) {}
    }
  }

  bool _didVideoReachEnd(PodPlayerController controller) {
    final dynamic dynamicController = controller;

    // Compatible with older/newer pod_player APIs.
    try {
      if (dynamicController.isVideoEnded == true) {
        return true;
      }
    } catch (_) {}

    try {
      final Duration? currentPosition =
          dynamicController.currentVideoPosition as Duration?;
      final Duration? totalDuration =
          dynamicController.totalVideoLength as Duration?;

      if (currentPosition == null || totalDuration == null) return false;
      if (totalDuration.inMilliseconds <= 0) return false;

      final int remainingMs =
          (totalDuration - currentPosition).inMilliseconds.abs();
      return remainingMs <= 800;
    } catch (_) {
      return false;
    }
  }

  /// [PodPlayerController] has no public `setPlaybackSpeed`; pod_player sets speed on the inner [VideoPlayerController] registered in GetX under [PodPlayerController.getTag].
  Future<void> _setPodPlaybackSpeed(double speed) async {
    final c = _controller;
    if (c == null) return;
    try {
      final inner = Get.find<PodGetXVideoController>(tag: c.getTag);
      await inner.videoCtr?.setPlaybackSpeed(speed);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not change playback speed: $e');
      }
    }
  }

  Future<void> _initializeDownloadService() async {
    await _downloadService.initialize();
  }

  Future<void> _checkIfDownloaded() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    final lessonId = lesson['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return;

    final isDownloaded = await _downloadService.isVideoDownloaded(lessonId);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  Future<void> _loadLessonContent() async {
    final lesson = widget.lesson;
    if (lesson == null) {
      setState(() {
        _isLoadingContent = false;
      });
      return;
    }

    // Get courseId from widget or extract from lesson
    String? courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      courseId =
          lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    }

    final lessonId = lesson['id']?.toString();

    if (courseId == null ||
        courseId.isEmpty ||
        lessonId == null ||
        lessonId.isEmpty) {
      setState(() {
        _isLoadingContent = false;
      });
      return;
    }

    await _loadPendingResume();
    try {
      final content = await CoursesService.instance.getLessonContent(
        courseId,
        lessonId,
      );

      if (mounted) {
        setState(() {
          _lessonContent = content;
          _isLoadingContent = false;
        });
      }

      final desc = _lessonContent?['content'] as String?;
      if (desc != null && desc.isNotEmpty) {
        _ensureDescriptionWebViewLoaded(desc);
      }

      await _initializeAudioFromContent();
      await _applySavedAudioResumeIfNeeded();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading lesson content: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
      }

      final desc = _lessonContent?['content'] as String?;
      if (desc != null && desc.isNotEmpty) {
        _ensureDescriptionWebViewLoaded(desc);
      }

      await _initializeAudioFromContent();
      await _applySavedAudioResumeIfNeeded();
    }
  }

  List<String> _collectAllAudioUrls() {
    final urls = <String>{};
    void addIfValid(dynamic v) {
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) return;
      if (s.startsWith('http://') || s.startsWith('https://')) {
        urls.add(s);
      }
    }

    final contentAudioUrls = _lessonContent?['audio_urls'];
    if (contentAudioUrls is List) {
      for (final u in contentAudioUrls) {
        addIfValid(u);
      }
    }
    final lessonAudioUrls = widget.lesson?['audio_urls'];
    if (lessonAudioUrls is List) {
      for (final u in lessonAudioUrls) {
        addIfValid(u);
      }
    }
    final media = widget.lesson?['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map && m['type']?.toString().toLowerCase() == 'audio') {
          addIfValid(m['file_path']);
        }
      }
    }
    final singleAudio = widget.lesson?['audio_url']?.toString().trim();
    if (singleAudio != null &&
        singleAudio.isNotEmpty &&
        singleAudio.startsWith('http')) {
      urls.add(singleAudio);
    }
    return urls.toList();
  }

  List<String> _collectAllPdfUrls() {
    final urls = <String>{};
    void addIfValid(dynamic v) {
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) return;
      if (s.startsWith('http://') || s.startsWith('https://')) {
        urls.add(s);
      }
    }

    final contentPdfs = _lessonContent?['pdf_urls'];
    if (contentPdfs is List) {
      for (final u in contentPdfs) {
        addIfValid(u);
      }
    }
    final lessonPdfs = widget.lesson?['pdf_urls'];
    if (lessonPdfs is List) {
      for (final u in lessonPdfs) {
        addIfValid(u);
      }
    }
    final media = widget.lesson?['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map && m['type']?.toString().toLowerCase() == 'pdf') {
          addIfValid(m['file_path']);
        }
      }
    }
    return urls.toList();
  }

  /// Collect ALL video URLs: main video_url + additional attachment videos
  List<String> _collectAllVideoUrls() {
    final urls = <String>[];
    final seen = <String>{};

    void addIfValid(String? s) {
      if (s == null || s.isEmpty) return;
      final cleaned = _cleanVideoUrl(s);
      if (cleaned != null && cleaned.isNotEmpty && seen.add(cleaned)) {
        urls.add(cleaned);
      }
    }

    // Main video_url first
    addIfValid(_lessonContent?['video_url']?.toString());
    addIfValid(widget.lesson?['video_url']?.toString());
    addIfValid(_lessonContent?['videoUrl']?.toString());

    // Additional videos from attachments
    final contentVideos = _lessonContent?['videos'];
    if (contentVideos is List) {
      for (final u in contentVideos) {
        addIfValid(u?.toString());
      }
    }
    final lessonVideos = widget.lesson?['videos'];
    if (lessonVideos is List) {
      for (final u in lessonVideos) {
        addIfValid(u?.toString());
      }
    }
    return urls;
  }

  Future<void> _switchVideoTrack(int index) async {
    if (index < 0 || index >= _allVideoUrls.length) return;
    if (index == _currentVideoIndex) return;

    _consumedVideoResumeSeek = true;

    final previousController = _controller;

    // Unmount PodVideoPlayer first, then dispose controller in next frame.
    // This avoids GetX lookup races inside pod_player dispose lifecycle.
    setState(() {
      _isVideoLoading = true;
      _currentVideoIndex = index;
      _controller = null;
      _webViewController = null;
      _useWebViewFallback = false;
    });

    if (previousController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          previousController.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Safe dispose skipped (already disposed): $e');
          }
        }
      });
    }

    final videoUrl = _allVideoUrls[index];

    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.youtube(videoUrl),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
        ),
      )..initialise().then((_) async {
          await _onPodControllerInitialized();
        }).catchError((_) {
          if (mounted) setState(() => _isVideoLoading = false);
        });
    } else if (videoUrl.toLowerCase().contains('vimeo.com')) {
      final match = RegExp(r'vimeo\.com/(?:video/)?(\d+)')
          .firstMatch(videoUrl.toLowerCase());
      if (match != null) {
        setState(() {
          _isVimeoVideo = true;
          _vimeoId = match.group(1);
          _isVideoLoading = false;
        });
      } else {
        setState(() => _isVideoLoading = false);
      }
    } else {
      _isVimeoVideo = false;
      _vimeoId = null;
      _initializeDirectVideo(videoUrl);
    }
  }

  bool _hasAnyVideoSource() {
    final lesson = widget.lesson;
    if (lesson == null) return false;
    final videoUrl = lesson['video_url']?.toString().trim() ?? '';
    if (videoUrl.isNotEmpty && videoUrl.startsWith('http')) return true;
    final contentVideoUrl =
        _lessonContent?['video_url']?.toString().trim() ?? '';
    if (contentVideoUrl.isNotEmpty && contentVideoUrl.startsWith('http')) {
      return true;
    }
    final videos = _lessonContent?['videos'];
    if (videos is List && videos.isNotEmpty) return true;
    if ((lesson['youtube_id']?.toString().trim() ?? '').isNotEmpty) return true;
    if ((lesson['vimeo_id']?.toString().trim() ?? '').isNotEmpty) return true;
    return false;
  }

  /// Initialize audio player from lesson content (supports multiple audio_urls)
  Future<void> _initializeAudioFromContent() async {
    _allAudioUrls = _collectAllAudioUrls();
    if (_allAudioUrls.isEmpty) return;

    _isAudioLesson = !_hasAnyVideoSource();

    _audioPlayer = AudioPlayer();
    _setupAudioListeners();
    await _loadAudioTrack(0);
  }

  void _setupAudioListeners() {
    _audioPlayer!.durationStream.listen((d) {
      if (mounted && d != null) {
        setState(() {
          _audioDuration = d;
          _isAudioDurationKnown = d > Duration.zero;
        });
      }
    });
    _audioPlayer!.positionStream.listen((p) {
      if (mounted) {
        setState(() => _audioPosition = p);
      }
    });
    _audioPlayer!.playingStream.listen((playing) {
      if (mounted) {
        setState(() => _isAudioPlaying = playing);
      }
    });
  }

  Future<void> _loadAudioTrack(int index) async {
    if (index < 0 || index >= _allAudioUrls.length) return;
    _currentAudioIndex = index;
    final url = _allAudioUrls[index];
    try {
      final initialDuration = await _audioPlayer!.setUrl(url);
      if (mounted) {
        setState(() {
          _audioDuration = initialDuration ?? Duration.zero;
          _isAudioDurationKnown =
              initialDuration != null && initialDuration > Duration.zero;
          _audioPosition = Duration.zero;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading audio track $index: $e');
      }
    }
  }

  Future<void> _switchAudioTrack(int index) async {
    if (index < 0 || index >= _allAudioUrls.length) return;
    if (index == _currentAudioIndex) {
      if (_isAudioPlaying) {
        await _audioPlayer?.pause();
      } else {
        await _audioPlayer?.play();
      }
      return;
    }
    await _audioPlayer?.stop();
    await _loadAudioTrack(index);
    await _audioPlayer?.play();
  }

  /// Clean and normalize video URL
  String? _cleanVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Remove any blob: prefix if present at the start
    url = url.replaceFirst(RegExp(r'^blob:'), '').trim();

    // Fix URLs that have blob: in the middle (like "https://domain.com/blob:https://...")
    if (url.contains('blob:')) {
      final blobIndex = url.indexOf('blob:');
      if (blobIndex != -1) {
        final afterBlob =
            url.substring(blobIndex + 5).trim(); // 5 is length of "blob:"
        // If the part after blob: starts with http/https, use it directly
        if (afterBlob.startsWith('http://') ||
            afterBlob.startsWith('https://')) {
          url = afterBlob;
        } else {
          // Otherwise, remove the blob: part and keep everything before and after
          url = url.substring(0, blobIndex).trim() + afterBlob;
        }
      }
    }

    // Ensure URL is valid
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (kDebugMode) {
        print('⚠️ Invalid video URL format: $url');
      }
      return null;
    }

    return url.trim();
  }

  Future<void> _initializeVideo() async {
    final lesson = widget.lesson;
    if (lesson == null) {
      setState(() => _isVideoLoading = false);
      return;
    }

    // New response: videos (list), videoUrl (backward-compatible single URL)
    // Fallback: lesson-level video_url, video object (older payloads)
    String? videoId;
    String? videoUrl;
    String? vimeoId;

    // 1) Try videos list from content API
    final contentVideos = _lessonContent?['videos'];
    if (contentVideos is List && contentVideos.isNotEmpty) {
      videoUrl = _cleanVideoUrl(contentVideos.first?.toString());
    }

    // 2) Fallback: videoUrl (backward-compatible single URL)
    videoUrl ??= _cleanVideoUrl(_lessonContent?['videoUrl']?.toString());

    // 3) Fallback: lesson-level fields (older payloads)
    videoUrl ??= _cleanVideoUrl(_lessonContent?['video_url']?.toString());
    videoUrl ??= _cleanVideoUrl(lesson['video_url']?.toString());

    final lessonVideoData = lesson['video'];
    if (videoUrl == null && lessonVideoData is Map) {
      videoUrl = _cleanVideoUrl(lessonVideoData['url']?.toString());
      videoId = lessonVideoData['youtube_id']?.toString();
    }

    // Vimeo from lesson-content (preferred) then lesson
    vimeoId = _lessonContent?['vimeo_id']?.toString().trim();
    if (vimeoId == null || vimeoId.isEmpty) {
      vimeoId = lesson['vimeo_id']?.toString().trim();
    }
    if (vimeoId != null && vimeoId.isEmpty) {
      vimeoId = null;
    }

    videoId = videoId ??
        _lessonContent?['youtube_id']?.toString() ??
        lesson['youtube_id']?.toString() ??
        lesson['youtubeVideoId']?.toString();

    if (videoId == null || videoId.isEmpty) {
      videoId = lesson['id']?.toString();
    }

    videoId = videoId ?? '';

    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('🎥 INITIALIZING VIDEO IN LESSON VIEWER');
      print('═══════════════════════════════════════════════════════════');
      print('Video ID: $videoId');
      print('Video URL (cleaned): $videoUrl');
      print('Lesson ID: ${lesson['id']}');
      print('Lesson Title: ${lesson['title']}');
      print('Content videos list: $contentVideos');
      print('Raw videoUrl: ${_lessonContent?['videoUrl']}');
      print('Vimeo ID: $vimeoId');
      print('All Lesson Keys: ${lesson.keys.toList()}');
      print('═══════════════════════════════════════════════════════════');
    }

    _allVideoUrls = _collectAllVideoUrls();
    if (_allVideoUrls.isNotEmpty) {
      var startIdx = 0;
      if (_pendingResume != null) {
        final vi =
            int.tryParse(_pendingResume!['videoIndex']?.toString() ?? '') ?? 0;
        if (vi >= 0 && vi < _allVideoUrls.length) startIdx = vi;
      }
      _currentVideoIndex = startIdx;
      final picked = _cleanVideoUrl(_allVideoUrls[startIdx]);
      if (picked != null && picked.isNotEmpty) {
        videoUrl = picked;
      }
    }

    final bool isVimeoUrl =
        videoUrl != null && videoUrl.toLowerCase().contains('vimeo.com');
    if (vimeoId == null && isVimeoUrl) {
      final match = RegExp(r'vimeo\.com/(?:video/)?(\d+)')
          .firstMatch(videoUrl.toLowerCase());
      vimeoId = match?.group(1);
    }

    if (vimeoId != null || isVimeoUrl) {
      if (kDebugMode) {
        print('🎬 Using Vimeo video: ${vimeoId ?? videoUrl}');
      }
      if (mounted) {
        setState(() {
          _isVimeoVideo = true;
          _vimeoId = vimeoId;
          _isVideoLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isVimeoVideo = false;
          _vimeoId = null;
        });
      }
      // Use video URL if available, otherwise use YouTube ID
      if (videoUrl != null && videoUrl.isNotEmpty) {
        // Check if it's a YouTube URL
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          if (kDebugMode) {
            print('📺 Using YouTube URL: $videoUrl');
          }
          _controller = PodPlayerController(
            playVideoFrom: PlayVideoFrom.youtube(videoUrl),
            podPlayerConfig: const PodPlayerConfig(
              autoPlay: false,
              isLooping: false,
            ),
          )..initialise().then((_) async {
              await _onPodControllerInitialized();
            }).catchError((error) {
              if (kDebugMode) {
                print('❌ Error initializing YouTube video: $error');
              }
              if (mounted) {
                setState(() => _isVideoLoading = false);
              }
            });
        } else {
          // Direct video URL from server - use pod_player with network
          if (kDebugMode) {
            print('📹 Using pod_player for direct video URL: $videoUrl');
          }
          _initializeDirectVideo(videoUrl);
        }
      } else if (videoId.isNotEmpty) {
        // Fallback to YouTube ID
        if (kDebugMode) {
          print('📺 Using YouTube ID fallback: $videoId');
        }
        final youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';
        _controller = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(youtubeUrl),
          podPlayerConfig: const PodPlayerConfig(
            autoPlay: false,
            isLooping: false,
          ),
        )..initialise().then((_) async {
            await _onPodControllerInitialized();
          }).catchError((error) {
            if (kDebugMode) {
              print('❌ Error initializing YouTube video by ID: $error');
            }
            if (mounted) {
              setState(() => _isVideoLoading = false);
            }
          });
      } else {
        // No valid video source
        if (kDebugMode) {
          print('⚠️ No valid video source found');
        }
        if (mounted) {
          setState(() => _isVideoLoading = false);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing video: $e');
      }
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    }
  }

  /// Initialize direct video playback using pod_player
  Future<void> _initializeDirectVideo(String videoUrl) async {
    try {
      if (kDebugMode) {
        print('📹 Initializing direct video with pod_player: $videoUrl');
      }

      // Get authorization token for video access
      final token = await TokenStorageService.instance.getAccessToken();

      // Add token as query parameter if available
      String videoUrlWithToken = videoUrl;
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse(videoUrl);
        videoUrlWithToken = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'token': token,
        }).toString();

        if (kDebugMode) {
          print('🔑 Added token to video URL');
        }
      }

      // Use pod_player with PlayVideoFrom.network()
      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(videoUrlWithToken),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: false,
          isLooping: false,
        ),
      )..initialise().then((_) async {
          await _onPodControllerInitialized(clearWebViewFallback: true);
          if (kDebugMode) {
            print('✅ Direct video initialized successfully with pod_player');
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('❌ Error initializing direct video with pod_player: $error');
            print('   Falling back to WebView...');
          }
          // Fallback to WebView if pod_player fails
          if (mounted) {
            _initializeWebView(videoUrl);
          }
        });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _initializeDirectVideo: $e');
        print('   Falling back to WebView...');
      }
      // Fallback to WebView if there's an error
      if (mounted) {
        _initializeWebView(videoUrl);
      }
    }
  }

  /// Initialize WebView for direct video playback (fallback method)
  Future<void> _initializeWebView(String videoUrl) async {
    try {
      if (kDebugMode) {
        print('🌐 Initializing WebView for video playback: $videoUrl');
      }

      // Get authorization token for video access
      final token = await TokenStorageService.instance.getAccessToken();

      setState(() {
        _useWebViewFallback = true;
      });

      // Try to load video via Flutter HTTP request first (to bypass CORS)
      // Then pass it to WebView as blob URL
      try {
        if (kDebugMode) {
          print('📥 Loading video via Flutter HTTP request...');
        }

        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        // Load video and save to temporary file
        final response = await http
            .get(
              Uri.parse(videoUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          if (kDebugMode) {
            print(
                '✅ Video loaded successfully via HTTP (${response.bodyBytes.length} bytes)');
          }

          // Save to temporary file
          final tempDir = await getTemporaryDirectory();
          final fileName = videoUrl.split('/').last.split('?').first;
          final fileExtension = fileName.split('.').last;
          final tempFile = File(
              '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');

          await tempFile.writeAsBytes(response.bodyBytes);

          if (kDebugMode) {
            print('💾 Video saved to temporary file: ${tempFile.path}');
          }

          // Use file:// URL for WebView
          final fileUrl = tempFile.path;
          _createWebViewWithFileUrl(fileUrl);

          // Store reference to temp file for cleanup
          setState(() {
            _tempVideoFile = tempFile;
          });

          return;
        } else {
          if (kDebugMode) {
            print('❌ HTTP request failed with status: ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load video via HTTP: $e');
          print('   Falling back to direct WebView method...');
        }
      }

      // Fallback: Try direct WebView method

      _createWebViewWithDirectUrl(videoUrl, token);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing WebView: $e');
      }
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  /// Create WebView with file URL (from temporary file)
  void _createWebViewWithFileUrl(String filePath) {
    // Convert file path to file:// URL
    final fileUrl =
        Platform.isAndroid ? 'file://$filePath' : 'file://$filePath';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background-color: #000;
    }
  </style>
</head>
<body>
  <video id="videoPlayer" controls autoplay playsinline webkit-playsinline>
    <source src="$fileUrl" type="video/mp4">
    Your browser does not support the video tag.
  </video>
  <script>
    var video = document.getElementById('videoPlayer');
    video.addEventListener('loadeddata', function() {
      console.log('Video loaded successfully from file URL');
    });
    video.addEventListener('error', function(e) {
      console.error('Video error:', e);
      var error = video.error;
      if (error) {
        console.error('Error code:', error.code, 'Message:', error.message);
      }
    });
  </script>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (kDebugMode) {
              print('✅ WebView page finished: $url');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView resource error: ${error.description}');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  /// Create WebView with direct URL (fallback method)
  void _createWebViewWithDirectUrl(String videoUrl, String? token) {
    final l10n = AppLocalizations.of(context)!;
    // Build video URL with token as query parameter (fallback method)
    String videoUrlWithToken = videoUrl;
    if (token != null && token.isNotEmpty) {
      final uri = Uri.parse(videoUrl);
      videoUrlWithToken = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
      }).toString();
    }

    // Create HTML5 video player with multiple fallback methods
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background-color: #000;
    }
    .loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-family: Arial, sans-serif;
      text-align: center;
    }
    .error {
      color: #ff6b6b;
    }
  </style>
</head>
<body>
  <div class="loading" id="loading">${l10n.loadingVideo}</div>
  <video id="videoPlayer" controls autoplay playsinline webkit-playsinline style="display: none;">
    Your browser does not support the video tag.
  </video>
  <script>
    var video = document.getElementById('videoPlayer');
    var loading = document.getElementById('loading');
    var videoUrl = '$videoUrl';
    var videoUrlWithToken = '$videoUrlWithToken';
    ${token != null ? "var token = '$token';" : 'var token = null;'}
    var currentMethod = 0;
    var methods = ['direct', 'no-cors', 'token-param'];
    
    function showVideo() {
      video.style.display = 'block';
      loading.style.display = 'none';
    }
    
    function showError(message) {
      loading.textContent = message;
      loading.className = 'loading error';
    }
    
    // Method 1: Try direct video source first (simplest, may work if server allows)
    function tryDirectVideo() {
      console.log('Trying method 1: Direct video source');
      video.src = videoUrl;
      video.load();
      
      var timeout = setTimeout(function() {
        if (video.readyState === 0) {
          console.log('Direct method failed, trying next method');
          tryNoCorsFetch();
        }
      }, 3000);
      
      video.addEventListener('loadeddata', function() {
        clearTimeout(timeout);
        console.log('Direct method succeeded');
        showVideo();
      }, { once: true });
      
      video.addEventListener('error', function(e) {
        clearTimeout(timeout);
        console.log('Direct method failed:', e);
        tryNoCorsFetch();
      }, { once: true });
    }
    
    // Method 2: Try fetch with no-cors mode
    async function tryNoCorsFetch() {
      console.log('Trying method 2: Fetch with no-cors mode');
      try {
        var response = await fetch(videoUrl, {
          method: 'GET',
          mode: 'no-cors',
          cache: 'default'
        });
        
        // With no-cors, we can't read the response, but we can try to use it
        // Try to create a blob URL anyway
        if (response.type === 'opaque') {
          // Opaque response - try to use video tag with the URL directly
          console.log('Got opaque response, trying direct video');
          video.src = videoUrl;
          video.load();
          
          video.addEventListener('loadeddata', function() {
            console.log('Video loaded after no-cors fetch');
            showVideo();
          }, { once: true });
          
          video.addEventListener('error', function(e) {
            console.log('No-cors method failed:', e);
            tryTokenParam();
          }, { once: true });
        }
      } catch (error) {
        console.log('No-cors fetch failed:', error);
        tryTokenParam();
      }
    }
    
    // Method 3: Try with token as query parameter
    function tryTokenParam() {
      if (!token) {
        showError('${l10n.cannotLoadVideo}');
        return;
      }
      
      console.log('Trying method 3: Token as query parameter');
      video.src = videoUrlWithToken;
      video.load();
      
      video.addEventListener('loadeddata', function() {
        console.log('Token param method succeeded');
        showVideo();
      }, { once: true });
      
      video.addEventListener('error', function(e) {
        console.log('Token param method failed:', e);
        showError('${l10n.videoLoadFailedCheckInternet}');
      }, { once: true });
    }
    
    // Add error handlers
    video.addEventListener('error', function(e) {
      var error = video.error;
      if (error) {
        console.error('Video error code:', error.code, 'Message:', error.message);
        if (error.code === 4) {
          // MEDIA_ELEMENT_ERROR: Format error
          showError('${l10n.videoFormatNotSupported}');
        } else if (error.code === 3) {
          // MEDIA_ELEMENT_ERROR: Decode error
          showError('${l10n.videoDecodeError}');
        } else if (error.code === 2) {
          // MEDIA_ELEMENT_ERROR: Network error
          showError('${l10n.networkConnectionError}');
        } else {
          showError('${l10n.videoLoadError}');
        }
      }
    });
    
    // Start loading
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', tryDirectVideo);
    } else {
      tryDirectVideo();
    }
  </script>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (kDebugMode) {
              print('🌐 WebView page started: $url');
            }
          },
          onPageFinished: (String url) {
            if (kDebugMode) {
              print('✅ WebView page finished: $url');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView resource error: ${error.description}');
              print('   Error code: ${error.errorCode}');
              print('   Error type: ${error.errorType}');
              print('   Failed URL: ${error.url}');

              // Log specific error types
              if (error.errorCode == -1) {
                print(
                    '   ⚠️ CORS or ORB (Opaque Response Blocking) error detected');
                print(
                    '   💡 This is expected - JavaScript will handle fallback methods');
              }
            }
            // Don't set loading to false immediately - let JavaScript try fallback methods
            // Only set to false if it's a critical error
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout) {
              if (mounted) {
                setState(() {
                  _isVideoLoading = false;
                });
              }
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    final snap = _captureResumeSnapshot();
    unawaited(_persistResumeSnapshot(snap));
    // Safety reset: never leave app locked in landscape after exiting lesson.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _isVimeoVideo = false;
    _vimeoId = null;
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _controller?.dispose();
    _audioPlayer?.dispose();
    // Clean up temporary video file
    if (_tempVideoFile != null) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error deleting temp video file: $e');
        }
      }
    }
    super.dispose();
  }

  bool _isPlayerFullscreen() {
    try {
      final dynamic c = _controller;
      return c?.isFullScreen == true || c?.isFullscreen == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _forcePortraitMode() async {
    if (_isForcingPortrait) return;
    _isForcingPortrait = true;
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Some devices apply orientation one frame later.
      await Future.delayed(const Duration(milliseconds: 120));
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {
      // no-op
    } finally {
      _isForcingPortrait = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_persistResumeSnapshot(_captureResumeSnapshot()));
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final isLandscapeNow = view.physicalSize.width > view.physicalSize.height;
    if (isLandscapeNow && !_isPlayerFullscreen()) {
      _forcePortraitMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final lesson = widget.lesson;
    if (lesson == null) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                l10n.noLesson,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Video Player Section
            _buildVideoSection(lesson),

            // Lesson Info Section
            Expanded(
              child: _buildLessonInfo(lesson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection(Map<String, dynamic> lesson) {
    if (_isAudioLesson) return _buildAudioPlayer();

    if (_isVimeoVideo && _vimeoId != null) {
      final html = '''
   <!DOCTYPE html>
   <html>
   <body style="margin:0;background:#000;">
   <iframe src="https://player.vimeo.com/video/$_vimeoId?autoplay=1&title=0&byline=0&portrait=0"
     width="100%" height="100%" frameborder="0" allow="autoplay; fullscreen" allowfullscreen>
   </iframe>
   </body>
   </html>
   ''';

      _webViewController ??= WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black);
      _webViewController!.loadHtmlString(html);
    }

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson['title'] as String? ??
                            AppLocalizations.of(context)!.lesson,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AppLocalizations.of(context)!.duration(
                          (lesson['duration'] ??
                                  AppLocalizations.of(context)!.notSpecified)
                              .toString(),
                        ),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_controller != null)
                  PopupMenuButton<double>(
                    icon:
                        const Icon(Icons.speed, color: Colors.white, size: 22),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (speed) async {
                      await _setPodPlaybackSpeed(speed);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      PopupMenuItem(
                        value: 1.0,
                        child: Text(
                            '1x (${AppLocalizations.of(context)!.normalSpeed})'),
                      ),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      const PopupMenuItem(value: 2.0, child: Text('2x')),
                    ],
                  ),
                if (!_isVideoLoading &&
                    (_controller != null ||
                        (_isVimeoVideo && _vimeoId != null) ||
                        (_useWebViewFallback && _webViewController != null)))
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 24),
                    onPressed: _openVideoFullscreen,
                  ),
              ],
            ),
          ),

          // Video Player
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _isVideoLoading
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.purple,
                          ),
                        ),
                      )
                    : _isVimeoVideo &&
                            _vimeoId != null &&
                            _webViewController != null
                        ? WebViewWidget(controller: _webViewController!)
                        : _controller != null
                            ? PodVideoPlayer(
                                controller: _controller!,
                                videoAspectRatio: 16 / 9,
                                overlayBuilder: _buildCustomPodOverlay,
                                podProgressBarConfig:
                                    const PodProgressBarConfig(
                                  playingBarColor: AppColors.purple,
                                  circleHandlerColor: AppColors.purple,
                                  bufferedBarColor: Colors.white30,
                                ),
                              )
                            : _useWebViewFallback && _webViewController != null
                                ? WebViewWidget(controller: _webViewController!)
                                : Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.white54, size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            AppLocalizations.of(context)!
                                                .cannotLoadVideo,
                                            style: GoogleFonts.cairo(
                                              color: Colors.white54,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                if (_controller == null)
                  IgnorePointer(child: _buildVideoWatermarkOverlay()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPodOverlay(OverLayOptions options) {
    final showOverlay = options.isOverlayVisible;
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final isFullscreen = options.isFullScreen == true;
    final watermark = '$_watermarkUserName • $_watermarkSessionTag';
    return Stack(
      fit: StackFit.expand,
      children: [
        // Single tap: play/pause (no onDoubleTap here — it delays the first tap).
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final c = _controller;
            if (c == null) return;
            try {
              if (c.isVideoPlaying) {
                c.pause();
              } else {
                c.play();
              }
              c.showOverlay();
              if (mounted) setState(() {});
            } catch (_) {}
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: showOverlay
                ? Colors.black.withValues(alpha: 0.20)
                : Colors.transparent,
          ),
        ),
        // Keep watermark inside player overlay so it remains visible in fullscreen.
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: isLandscape ? 12 : 14,
              bottom: isLandscape ? 10 : 12,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                watermark,
                style: GoogleFonts.cairo(
                  fontSize: isLandscape ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
        // Pause glyph while paused only; fades out when playing (taps use layer below).
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: options.podVideoState == PodVideoState.paused ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Center(
                child: Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 88,
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: const [
                    Shadow(
                      blurRadius: 14,
                      offset: Offset(0, 2),
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showOverlay) ...[
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              child: IconButton(
                icon: Icon(
                  (isLandscape || isFullscreen)
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
                onPressed: (isLandscape || isFullscreen)
                    ? _exitVideoFullscreen
                    : _openVideoFullscreen,
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isLandscape || isFullscreen)
                  Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    child: IconButton(
                      tooltip: 'Exit fullscreen',
                      icon: const Icon(Icons.fullscreen_exit_rounded,
                          color: Colors.white, size: 22),
                      onPressed: _exitVideoFullscreen,
                    ),
                  ),
                if (isLandscape || isFullscreen) const SizedBox(width: 6),
                Expanded(child: options.podProgresssBar),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openVideoFullscreen() async {
    final c = _controller;
    if (c == null || !mounted) return;
    try {
      c.enableFullScreen();
    } catch (e) {
      if (kDebugMode) {
        print('enable fullscreen: $e');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _exitVideoFullscreen() async {
    final c = _controller;
    if (c == null || !mounted) return;

    try {
      if (c.isFullScreen) {
        final inner = Get.find<PodGetXVideoController>(tag: c.getTag);
        await inner.disableFullScreen(context, c.getTag);
      }
    } catch (e) {
      if (kDebugMode) {
        print('disable fullscreen: $e');
      }
      try {
        final inner = Get.find<PodGetXVideoController>(tag: c.getTag);
        if (inner.isFullScreen &&
            Navigator.of(inner.fullScreenContext).canPop()) {
          Navigator.of(inner.fullScreenContext).pop();
        }
      } catch (_) {}
    }

    await _forcePortraitMode();
    if (mounted) setState(() {});
  }

  Widget _buildAudioPlayer() {
    final lesson = widget.lesson;
    final title =
        lesson?['title'] as String? ?? AppLocalizations.of(context)!.lesson;
    final maxSeconds = math.max(1, _audioDuration.inSeconds);
    final canSeek =
        _audioPlayer != null && _isAudioDurationKnown && maxSeconds > 0;
    final sliderValue = canSeek
        ? (_audioPosition.inSeconds / maxSeconds).clamp(0.0, 1.0).toDouble()
        : 0.0;

    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.headphones_rounded,
                    size: 80,
                    color: AppColors.purple,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: sliderValue,
                    activeColor: AppColors.purple,
                    inactiveColor: AppColors.purple.withOpacity(0.2),
                    onChanged: canSeek
                        ? (value) async {
                            final seekSeconds = (value * maxSeconds).round();
                            await _audioPlayer!.seek(
                              Duration(seconds: seekSeconds),
                            );
                          }
                        : null,
                  ),
                  if (!canSeek)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'جاري تحميل مدة الصوت…',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        formatDuration(_audioPosition),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _isAudioDurationKnown
                            ? formatDuration(_audioDuration)
                            : '--:--',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_allAudioUrls.length > 1)
                        IconButton(
                          onPressed: _currentAudioIndex > 0
                              ? () async {
                                  await _audioPlayer?.stop();
                                  await _loadAudioTrack(_currentAudioIndex - 1);
                                  await _audioPlayer?.play();
                                }
                              : null,
                          icon: Icon(Icons.skip_previous_rounded,
                              size: 36,
                              color: _currentAudioIndex > 0
                                  ? AppColors.purple
                                  : Colors.grey[400]),
                        ),
                      IconButton(
                        onPressed: () async {
                          if (_audioPlayer == null) return;
                          if (_isAudioPlaying) {
                            await _audioPlayer!.pause();
                          } else {
                            await _audioPlayer!.play();
                          }
                        },
                        icon: Icon(
                          _isAudioPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 64,
                          color: AppColors.purple,
                        ),
                      ),
                      if (_allAudioUrls.length > 1)
                        IconButton(
                          onPressed: _currentAudioIndex <
                                  _allAudioUrls.length - 1
                              ? () async {
                                  await _audioPlayer?.stop();
                                  await _loadAudioTrack(_currentAudioIndex + 1);
                                  await _audioPlayer?.play();
                                }
                              : null,
                          icon: Icon(Icons.skip_next_rounded,
                              size: 36,
                              color:
                                  _currentAudioIndex < _allAudioUrls.length - 1
                                      ? AppColors.purple
                                      : Colors.grey[400]),
                        ),
                    ],
                  ),
                  if (_allAudioUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_currentAudioIndex + 1} / ${_allAudioUrls.length}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioFilesSection() {
    if (_allAudioUrls.isEmpty) return const SizedBox.shrink();
    if (_isAudioLesson && _allAudioUrls.length <= 1) {
      return const SizedBox.shrink();
    }

    final showControls = !_isAudioLesson;

    String formatDur(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.headphones_rounded,
                    color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'ملفات صوتية',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allAudioUrls.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (showControls && _audioPlayer != null) ...[
            _buildInlineAudioControls(formatDur),
            const SizedBox(height: 12),
          ],
          ...List.generate(_allAudioUrls.length, (index) {
            final url = _allAudioUrls[index];
            final isPlaying = index == _currentAudioIndex && _isAudioPlaying;
            final isCurrent = index == _currentAudioIndex;
            return _buildAudioTrackItem(
                index, url, isCurrent, isPlaying, formatDur);
          }),
        ],
      ),
    );
  }

  Widget _buildInlineAudioControls(String Function(Duration) formatDur) {
    final maxSeconds = math.max(1, _audioDuration.inSeconds);
    final canSeek =
        _audioPlayer != null && _isAudioDurationKnown && maxSeconds > 0;
    final sliderValue = canSeek
        ? (_audioPosition.inSeconds / maxSeconds).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.purple,
            inactiveTrackColor: AppColors.purple.withOpacity(0.2),
            thumbColor: AppColors.purple,
          ),
          child: Slider(
            value: sliderValue,
            onChanged: canSeek
                ? (value) async {
                    final seekSeconds = (value * maxSeconds).round();
                    await _audioPlayer!.seek(Duration(seconds: seekSeconds));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(formatDur(_audioPosition),
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.mutedForeground)),
              const Spacer(),
              Text(_isAudioDurationKnown ? formatDur(_audioDuration) : '--:--',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioTrackItem(int index, String url, bool isCurrent,
      bool isPlaying, String Function(Duration) formatDur) {
    final name = _fileNameFromUrl(url);
    return GestureDetector(
      onTap: () => _switchAudioTrack(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.purple.withOpacity(0.08)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: isCurrent
              ? Border.all(color: AppColors.purple.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.purple : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
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
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color:
                          isCurrent ? AppColors.purple : AppColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'مقطع صوتي ${index + 1}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            if (isCurrent && _isAudioDurationKnown)
              Text(
                formatDur(_audioPosition),
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.purple),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFilesSection() {
    if (_allVideoUrls.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.video_library_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'ملفات الفيديو',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allVideoUrls.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_allVideoUrls.length, (index) {
            final url = _allVideoUrls[index];
            final isCurrent = index == _currentVideoIndex;
            return _buildVideoTrackItem(index, url, isCurrent);
          }),
        ],
      ),
    );
  }

  Widget _buildVideoTrackItem(int index, String url, bool isCurrent) {
    final name = _fileNameFromUrl(url);
    return GestureDetector(
      onTap: () => _switchVideoTrack(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.red.withOpacity(0.08)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border:
              isCurrent ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent ? Colors.red : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isCurrent
                    ? Icons.play_circle_filled_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
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
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? Colors.red : AppColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'فيديو ${index + 1}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'يعمل الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfFilesSection() {
    final pdfUrls = _collectAllPdfUrls();
    if (pdfUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'ملفات PDF',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pdfUrls.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(pdfUrls.length, (index) {
            return _buildPdfItem(index, pdfUrls[index]);
          }),
        ],
      ),
    );
  }

  Widget _buildPdfItem(int index, String url) {
    final name = _fileNameFromUrl(url);
    return GestureDetector(
      onTap: () {
        context.push(
          RouteNames.pdfViewer,
          extra: {
            'pdfUrl': url,
            'title': name,
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 20,
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
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ملف PDF ${index + 1}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.preview_rounded,
                color: AppColors.purple,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonInfo(Map<String, dynamic> lesson) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Lesson Title & Stats
            Text(
              lesson['title'] as String? ??
                  AppLocalizations.of(context)!.lesson,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                _buildStatBadge(
                    Icons.access_time_rounded, lesson['duration'] ?? '0'),
                // const SizedBox(width: 12),
                // _buildStatBadge(Icons.visibility_rounded, '0 مشاهدة'),
                // const SizedBox(width: 12),
                // _buildStatBadge(Icons.thumb_up_rounded, '0%'),
              ],
            ),
            const SizedBox(height: 24),

            // Description Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_rounded,
                            color: AppColors.purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.lessonDescriptionTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isLoadingContent
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: AppColors.purple,
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final description =
                                _lessonContent?['content'] as String? ?? '';

                            if (description.trim().isEmpty) {
                              return Text(
                                AppLocalizations.of(context)!
                                    .noLessonDescription,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: AppColors.mutedForeground,
                                  height: 1.7,
                                ),
                              );
                            }

                            if (_looksLikeHtml(description) &&
                                _descriptionWebViewController != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 260,
                                  child: WebViewWidget(
                                    controller: _descriptionWebViewController!,
                                  ),
                                ),
                              );
                            }

                            return Text(
                              description,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.mutedForeground,
                                height: 1.7,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Images Section (from course response lesson.images / lesson.media)
            _buildImagesSection(_collectLessonImageUrls()),
            if (_collectLessonImageUrls().isNotEmpty)
              const SizedBox(height: 20),

            // Audio Files Section
            _buildAudioFilesSection(),
            if (_allAudioUrls.isNotEmpty &&
                !(_isAudioLesson && _allAudioUrls.length <= 1))
              const SizedBox(height: 20),

            // Video Files Section
            _buildVideoFilesSection(),
            if (_allVideoUrls.length > 1) const SizedBox(height: 20),

            // PDF Files Section
            _buildPdfFilesSection(),
            if (_collectAllPdfUrls().isNotEmpty) const SizedBox(height: 20),

            // Download Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.download_rounded,
                            color: AppColors.purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.downloadForOffline,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isDownloading)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _downloadProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.purple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.downloadingProgress(
                            _downloadProgress.round(),
                          ),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    )
                  else if (_isDownloaded)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.videoDownloaded,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: Text(
                        AppLocalizations.of(context)!.downloadForOffline,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Resources Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.folder_rounded,
                            color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.lessonFiles,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isLoadingContent
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: AppColors.purple,
                            ),
                          ),
                        )
                      : _buildResourcesList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: _buildNavButton(
                    AppLocalizations.of(context)!.previousLesson,
                    Icons.arrow_forward_rounded,
                    false,
                    () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildNavButton(
                    AppLocalizations.of(context)!.nextLesson,
                    Icons.arrow_back_rounded,
                    true,
                    () => context.pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.purple),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }

  String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) return Uri.decodeComponent(segments.last);
    } catch (_) {}
    return url.split('/').last.split('?').first;
  }

  Widget _buildResourcesList() {
    final List<Map<String, dynamic>> resourceList = [];

    // General files from both sources
    final fileUrlsSet = <String>{};
    final contentFileUrls = _lessonContent?['file_urls'];
    if (contentFileUrls is List) {
      for (final u in contentFileUrls) {
        final s = u?.toString().trim() ?? '';
        if (s.isNotEmpty) fileUrlsSet.add(s);
      }
    }
    final lessonFileUrls = widget.lesson?['file_urls'];
    if (lessonFileUrls is List) {
      for (final u in lessonFileUrls) {
        final s = u?.toString().trim() ?? '';
        if (s.isNotEmpty) fileUrlsSet.add(s);
      }
    }
    for (final u in fileUrlsSet) {
      resourceList.add({
        'title': _fileNameFromUrl(u),
        'url': u,
        'type': 'file',
        'icon': Icons.insert_drive_file,
      });
    }

    // Google Drive links from both sources
    final driveLinksSet = <String>{};
    final contentDriveLinks = _lessonContent?['google_drive_links'];
    if (contentDriveLinks is List) {
      for (final u in contentDriveLinks) {
        final s = u?.toString().trim() ?? '';
        if (s.isNotEmpty) driveLinksSet.add(s);
      }
    }
    final lessonDriveLinks = widget.lesson?['google_drive_links'];
    if (lessonDriveLinks is List) {
      for (final u in lessonDriveLinks) {
        final s = u?.toString().trim() ?? '';
        if (s.isNotEmpty) driveLinksSet.add(s);
      }
    }
    for (final u in driveLinksSet) {
      resourceList.add({
        'title': 'Google Drive',
        'url': u,
        'type': 'link',
        'icon': Icons.link_rounded,
      });
    }

    if (resourceList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noFilesAvailable,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Column(
      children: resourceList.asMap().entries.map((entry) {
        final index = entry.key;
        final resource = entry.value;
        return Column(
          children: [
            _buildResourceItem(
              resource['title'] as String,
              resource['size'] as String? ?? '',
              resource['icon'] as IconData,
              resource['url'] as String? ?? '',
            ),
            if (index < resourceList.length - 1) const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _handleDownload() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    final lessonId = lesson['id']?.toString();
    final courseId = widget.courseId ?? lesson['course_id']?.toString();
    final title =
        lesson['title']?.toString() ?? AppLocalizations.of(context)!.video;
    final description = lesson['description']?.toString() ?? '';

    if (lessonId == null || courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.cannotLoadThisVideo,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Permission check
    final hasPermission = await _downloadService.hasStoragePermission();
    if (!hasPermission) {
      final granted = await _downloadService.requestPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .storagePermissionRequiredToDownloadVideos,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    String? rawVideoUrl;
    final contentVideos = _lessonContent?['videos'];
    if (contentVideos is List && contentVideos.isNotEmpty) {
      rawVideoUrl = contentVideos.first?.toString();
    }
    rawVideoUrl ??= _lessonContent?['videoUrl']?.toString();
    rawVideoUrl ??= _lessonContent?['video_url']?.toString();
    rawVideoUrl ??= lesson['video_url']?.toString();

    final videoUrl = _cleanVideoUrl(rawVideoUrl);

    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.noVideoUrlToDownload,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      // الحصول على عنوان الكورس
      String? courseTitle;
      try {
        final courseDetails =
            await CoursesService.instance.getCourseDetails(courseId);
        courseTitle = courseDetails['title']?.toString();
      } catch (e) {
        print('Error getting course title: $e');
      }
      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        // Build fileName with course title for better organization
        final safeCourseTitle = (courseTitle ?? 'course_$courseId')
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        final safeLessonTitle =
            title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final fileName =
            '${safeCourseTitle}_${safeLessonTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final localPath =
            await YoutubeVideoService.instance.downloadYoutubeVideo(
          videoUrl,
          fileName: fileName,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _downloadProgress = progress);
            }
          },
        );

        if (localPath != null) {
          // Save to database so it appears in Downloads screen (like server downloads)
          // title = course title (main display), courseTitle = course for grouping
          final videoId = await _downloadService.saveDownloadedVideoRecord(
            lessonId: lessonId,
            courseId: courseId,
            title: courseTitle ?? title,
            videoUrl: videoUrl,
            localPath: localPath,
            courseTitle: courseTitle ??
                AppLocalizations.of(context)!.courseWithId(courseId),
            description: description.isNotEmpty ? description : title,
            durationText: lesson['duration']?.toString(),
            videoSource: 'youtube',
          );

          if (kDebugMode && videoId != null) {
            log('YouTube video saved to database: $videoId');
          }

          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isDownloaded = true;
              _downloadProgress = 0;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.videoDownloadedSuccessfully,
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.videoDownloadFailed,
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      final videoId = await _downloadService.downloadVideoWithManager(
        videoUrl: videoUrl,
        lessonId: lessonId,
        courseId: courseId,
        title: title,
        courseTitle: courseTitle,
        description: description,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (videoId != null) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
            _downloadProgress = 0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.videoDownloadedSuccessfully,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(AppLocalizations.of(context)!.videoDownloadFailed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.videoDownloadError(
                e.toString().replaceFirst('Exception: ', ''),
              ),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildResourceItem(
      String title, String size, IconData icon, String url) {
    // Check if the resource is a PDF
    final isPdf = url.toLowerCase().contains('.pdf') ||
        title.toLowerCase().contains('pdf') ||
        icon == Icons.picture_as_pdf;
    final lowerUrl = url.toLowerCase();
    final isImage = lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp') ||
        icon == Icons.image;

    return GestureDetector(
      onTap: url.isNotEmpty
          ? () {
              if (kDebugMode) {
                print('Opening resource: $url');
              }

              if (isPdf) {
                // Open PDF in viewer screen
                context.push(
                  RouteNames.pdfViewer,
                  extra: {
                    'pdfUrl': url,
                    'title': title,
                  },
                );
              } else if (isImage) {
                showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: Container(
                      color: Colors.black,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Text(
                                      'تعذر تحميل الصورة',
                                      style: GoogleFonts.cairo(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                // For non-PDF files, you can implement download or other actions
                if (kDebugMode) {
                  print('Non-PDF file: $url');
                }
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.red, size: 18),
            ),
            if (isImage && url.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppColors.mutedForeground, size: 20),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground),
                  ),
                  if (size.isNotEmpty)
                    Text(
                      size,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.mutedForeground),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf
                    ? AppColors.purple.withOpacity(0.1)
                    : AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.preview_rounded : Icons.download_rounded,
                color: AppColors.purple,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
      String text, IconData icon, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF0C52B3), Color(0xFF093F8A)])
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: Colors.grey[200]!),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isPrimary) Icon(icon, size: 18, color: AppColors.foreground),
            if (!isPrimary) const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : AppColors.foreground,
              ),
            ),
            if (isPrimary) const SizedBox(width: 8),
            if (isPrimary) Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
