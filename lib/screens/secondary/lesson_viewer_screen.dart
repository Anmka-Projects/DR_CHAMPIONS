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
import '../../core/api/api_endpoints.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../core/resource_url_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../services/lesson_bookmark_service.dart';
import '../../services/lesson_resume_service.dart';
import 'course_details_screen.dart';
import '../../services/profile_service.dart';
import '../../services/token_storage_service.dart';
import '../../services/video_download_service.dart';
import '../../services/youtube_video_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

bool _allowEmbeddedVimeoTopLevelNavigation(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return true;
  final lower = url.toLowerCase();
  if (lower.startsWith('about:blank') ||
      lower.startsWith('data:') ||
      lower.startsWith('javascript:') ||
      lower.startsWith('blob:')) {
    return true;
  }
  // Block top-level external navigation attempts from embedded Vimeo controls.
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return false;
  }
  return true;
}

/// Lesson Viewer Screen - Modern & Eye-Friendly Design
class LessonViewerScreen extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final String? courseId;
  final List<Map<String, dynamic>> allLessons;
  final int lessonIndex;

  const LessonViewerScreen({
    super.key,
    this.lesson,
    this.courseId,
    this.allLessons = const [],
    this.lessonIndex = -1,
  });

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
  bool _isYouTubeVideo = false;
  bool _showVideoOverlayButtons = true;
  String? _vimeoId;
  String? _vimeoHash;
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
  bool _isVimeoFullscreenActive = false;
  int _vimeoLastPositionSeconds = 0;
  int _prevVimeoTimerCheckSeconds = 0;
  String? _lastLoadedVimeoEmbedUrl;
  bool _isBookmarkedLesson = false;

  /// Avoid feedback when pausing the other player from exclusivity hooks.
  bool _silencingOtherPlayback = false;
  bool? _podWasPlaying;

  static const String _lessonPanelDescription = 'description';
  static const String _lessonPanelImages = 'images';
  static const String _lessonPanelAudio = 'audio';
  static const String _lessonPanelVideos = 'videos';
  static const String _lessonPanelPdfs = 'pdfs';
  static const String _lessonPanelExams = 'exams';
  static const String _lessonPanelDownload = 'download';
  static const String _lessonPanelFiles = 'files';

  String? _openLessonPanel;
  bool _lessonAccordionUserInteracted = false;
  String? _activePdfUrl;
  bool _isLoadingLessonExams = false;
  List<Map<String, dynamic>> _lessonExams = [];
  String? _startingLessonExamId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watermarkSessionTag =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _loadWatermarkUserName();
    _initializeDownloadService();
    unawaited(_syncBookmarkState());
    _loadLessonContent().then((_) {
      // Initialize video after content is loaded (or failed)
      // This ensures we can use video data from the API response
      _initializeVideo();
      _startProgressTracking();
      _checkIfDownloaded();
    });
  }

  @override
  void didUpdateWidget(covariant LessonViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.lesson?['id']?.toString();
    final newId = widget.lesson?['id']?.toString();
    if (oldId != newId) {
      setState(() {
        _openLessonPanel = null;
        _lessonAccordionUserInteracted = false;
        _lessonExams = [];
        _isLoadingLessonExams = false;
      });
      unawaited(_pausePlaybackOnLessonChange());
      unawaited(_syncBookmarkState());
      unawaited(_reloadForNewLesson());
    }
  }

  String _bookmarkCourseId() {
    final lesson = widget.lesson;
    return widget.courseId ??
        lesson?['course_id']?.toString() ??
        lesson?['courseId']?.toString() ??
        '';
  }

  Map<String, dynamic>? _buildBookmarkPayload() {
    final lesson = widget.lesson;
    if (lesson == null) return null;
    final lessonId = lesson['id']?.toString() ?? '';
    if (lessonId.isEmpty) return null;
    final courseId = _bookmarkCourseId();
    if (courseId.isEmpty) return null;
    return {
      'lessonId': lessonId,
      'courseId': courseId,
      'lessonTitle': lesson['title']?.toString() ?? '',
      'lesson': {
        ...lesson,
        'course_id': courseId,
      },
    };
  }

  Future<void> _syncBookmarkState() async {
    final lessonId = widget.lesson?['id']?.toString() ?? '';
    if (lessonId.isEmpty) {
      if (mounted) setState(() => _isBookmarkedLesson = false);
      return;
    }
    final bookmarked = await LessonBookmarkService.instance.isBookmarked(lessonId);
    if (!mounted) return;
    setState(() => _isBookmarkedLesson = bookmarked);
  }

  Future<void> _toggleLessonBookmark() async {
    final payload = _buildBookmarkPayload();
    if (payload == null) return;
    final isNowBookmarked =
        await LessonBookmarkService.instance.toggleBookmark(payload);
    if (!mounted) return;
    setState(() => _isBookmarkedLesson = isNowBookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowBookmarked
              ? 'Lesson added to bookmarks'
              : 'Lesson removed from bookmarks',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reloadForNewLesson() async {
    await _loadLessonContent();
    if (!mounted) return;
    _initializeVideo();
    _startProgressTracking();
    _checkIfDownloaded();
  }

  String _defaultLessonAccordionPanelId() => _lessonPanelDescription;

  String? _effectiveOpenLessonPanelId() {
    if (!_lessonAccordionUserInteracted) {
      return _defaultLessonAccordionPanelId();
    }
    return _openLessonPanel;
  }

  /// Which accordion section owns the top "player" slot. `null` => primary video (or audio lesson).
  String? _activeHeroPanel() {
    if (!_lessonAccordionUserInteracted) return null;
    return _openLessonPanel;
  }

  void _pauseMainVideoPlayback() {
    final c = _controller;
    if (c == null) return;
    try {
      if (c.isVideoPlaying == true) {
        c.pause();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _pauseLessonAudioPlayback() async {
    try {
      await _audioPlayer?.pause();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _pausePlaybackOnLessonChange() async {
    final c = _controller;
    if (c != null) {
      try {
        if (c.isFullScreen == true) {
          await _exitVideoFullscreen();
        }
      } catch (_) {}
    }
    _pauseMainVideoPlayback();
    await _pauseLessonAudioPlayback();
  }

  void _pauseVideoBecauseAudioStarted() {
    if (_silencingOtherPlayback) return;
    final c = _controller;
    if (c == null) return;
    _silencingOtherPlayback = true;
    try {
      if (c.isVideoPlaying == true) {
        c.pause();
      }
    } catch (_) {}
    _silencingOtherPlayback = false;
    if (mounted) setState(() {});
  }

  Future<void> _pauseAudioBecauseVideoStarted() async {
    if (_silencingOtherPlayback) return;
    if (_audioPlayer == null) return;
    _silencingOtherPlayback = true;
    try {
      await _audioPlayer!.pause();
    } catch (_) {}
    _silencingOtherPlayback = false;
    if (mounted) setState(() {});
  }

  void _toggleLessonPanel(String id) {
    final before = _effectiveOpenLessonPanelId();
    setState(() {
      _lessonAccordionUserInteracted = true;
      if (before == id) {
        _openLessonPanel = null;
      } else {
        _openLessonPanel = id;
      }
      if (_openLessonPanel != _lessonPanelPdfs) {
        _activePdfUrl = null;
      }
    });
    final after = _effectiveOpenLessonPanelId();
    final afterOpen = _openLessonPanel;
    if (before == after) return;
    if (before == _lessonPanelAudio && after != _lessonPanelAudio) {
      unawaited(_pauseLessonAudioPlayback());
    }
    if (afterOpen == _lessonPanelAudio) {
      _pauseMainVideoPlayback();
    } else if (afterOpen != null &&
        afterOpen != _lessonPanelVideos &&
        afterOpen != _lessonPanelExams) {
      _pauseMainVideoPlayback();
    }
    if (afterOpen != _lessonPanelAudio) {
      unawaited(_pauseLessonAudioPlayback());
    }
  }

  bool _isLessonPanelOpen(String id) {
    if (!_lessonAccordionUserInteracted) {
      return id == _defaultLessonAccordionPanelId();
    }
    return _openLessonPanel == id;
  }

  Widget _lessonAccordionCard({
    required String panelId,
    required String title,
    required IconData icon,
    required Color accent,
    int? badge,
    required Widget child,
    VoidCallback? onHeaderTap,
  }) {
    final open = _isLessonPanelOpen(panelId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onHeaderTap ?? () => _toggleLessonPanel(panelId),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(20),
                  bottom: Radius.circular(open ? 0 : 20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      if (badge != null && badge > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$badge',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                      Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowLessonAudioPanel() {
    if (_allAudioUrls.isEmpty) return false;
    if (_isAudioLesson && _allAudioUrls.length <= 1) return false;
    return true;
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
      final savedMs = int.tryParse(saved['positionMs']?.toString() ?? '') ?? 0;
      if (savedMs > 0) {
        _vimeoLastPositionSeconds = (savedMs / 1000).floor();
      }
    }
  }

  Future<void> _onPodControllerInitialized(
      {bool clearWebViewFallback = false}) async {
    if (!mounted || _controller == null) return;
    final c = _controller!;
    _podWasPlaying = c.isVideoPlaying == true;
    c.addListener(() {
      if (_didVideoReachEnd(c)) {
        _markLessonComplete();
      }
      final playing = c.isVideoPlaying == true;
      if (playing && _podWasPlaying != true) {
        unawaited(_pauseAudioBecauseVideoStarted());
      }
      _podWasPlaying = playing;
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
    } else if (_isVimeoVideo && _vimeoLastPositionSeconds > 0) {
      positionMs = _vimeoLastPositionSeconds * 1000;
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
    var snapshot = s;
    if (_isVimeoVideo && _vimeoId != null) {
      try {
        final currentSeconds = await _readVimeoCurrentSeconds();
        if (currentSeconds > 0) {
          _vimeoLastPositionSeconds = currentSeconds;
          final watched = snapshot.watchedSeconds > currentSeconds
              ? snapshot.watchedSeconds
              : currentSeconds;
          snapshot = _LessonResumeSnapshot(
            courseId: snapshot.courseId,
            lessonId: snapshot.lessonId,
            lessonTitle: snapshot.lessonTitle,
            positionMs: currentSeconds * 1000,
            videoIndex: snapshot.videoIndex,
            audioIndex: snapshot.audioIndex,
            watchedSeconds: watched,
            lessonMarkedComplete: snapshot.lessonMarkedComplete,
          );
        }
      } catch (_) {}
    }
    try {
      await LessonResumeService.instance.saveLastOpenedLesson(
        courseId: snapshot.courseId,
        lessonId: snapshot.lessonId,
        lessonTitle: snapshot.lessonTitle,
        positionMs: snapshot.positionMs,
        videoIndex: snapshot.videoIndex,
        audioIndex: snapshot.audioIndex,
        watchedSeconds: snapshot.watchedSeconds,
        markLessonCompletedId:
            snapshot.lessonMarkedComplete ? snapshot.lessonId : null,
      );
    } catch (_) {}

    if (!snapshot.lessonMarkedComplete) {
      try {
        await CoursesService.instance.updateLessonProgress(
          snapshot.courseId,
          snapshot.lessonId,
          watchedSeconds: snapshot.watchedSeconds,
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
      } else {
        final normalized = ApiEndpoints.getImageUrl(t);
        if (normalized.isNotEmpty) {
          urls.add(normalized);
        }
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

  Widget _buildImagesSection(List<String> imageUrls,
      {bool forAccordion = false}) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final gallery = SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          return GestureDetector(
            onTap: () {
              if (forAccordion) {
                _toggleLessonPanel(_lessonPanelImages);
                return;
              }
              showDialog<void>(
                context: context,
                builder: (context) => _LessonImagesViewerDialog(
                  urls: imageUrls,
                  initialIndex: index,
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
    );

    if (forAccordion) return gallery;

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
                AppLocalizations.of(context)!.lessonImages,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          gallery,
        ],
      ),
    );
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();

    // Non-media lessons (text / PDF / images only): mark complete after 5 s.
    if (!_hasAnyVideoSource() && _allAudioUrls.isEmpty) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted || _lessonMarkedComplete) return;
        unawaited(_markLessonComplete());
      });
      return;
    }

    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      bool isPlaying = false;
      int secondsToAdd = 30;

      // PodPlayer (YouTube / direct MP4)
      if (_controller != null) {
        try {
          final dynamic dynamicController = _controller!;
          isPlaying = dynamicController.isVideoPlaying == true;
        } catch (_) {
          isPlaying = false;
        }
      }

      // Vimeo: detect playback by time advancement
      if (!isPlaying && _isVimeoVideo) {
        try {
          final prev = _prevVimeoTimerCheckSeconds;
          final current = await _readVimeoCurrentSeconds();
          _prevVimeoTimerCheckSeconds = current;
          if (current > prev + 4) {
            secondsToAdd = (current - prev).clamp(0, 35);
            _watchedSeconds += secondsToAdd;
            isPlaying = true;
          }
        } catch (_) {}
      }

      // Audio player
      if (!isPlaying && _isAudioLesson && _audioPlayer != null) {
        try {
          if (_audioPlayer!.playing) isPlaying = true;
        } catch (_) {}
      }

      if (isPlaying) {
        if (!_isVimeoVideo) _watchedSeconds += 30;
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
      await _loadLessonExams();
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
      await _loadLessonExams();
    }
  }

  Future<void> _loadLessonExams() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    String? courseId = widget.courseId;
    courseId ??=
        lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    final lessonId = lesson['id']?.toString();
    if (courseId == null ||
        courseId.isEmpty ||
        lessonId == null ||
        lessonId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lessonExams = [];
        _isLoadingLessonExams = false;
      });
      return;
    }

    if (mounted) {
      setState(() => _isLoadingLessonExams = true);
    }

    try {
      final exams = await ExamsService.instance.getCourseExams(
        courseId,
        lessonId: lessonId,
      );
      if (!mounted) return;
      setState(() {
        _lessonExams =
            exams.map((e) => Map<String, dynamic>.from(e)).where((e) {
          final targetType =
              e['target_type']?.toString().toLowerCase().trim() ??
                  e['targetType']?.toString().toLowerCase().trim() ??
                  '';
          final examLessonId =
              e['lesson_id']?.toString() ?? e['lessonId']?.toString();
          final examTargetId =
              e['target_id']?.toString() ?? e['targetId']?.toString();
          final matchesLessonId = (examLessonId != null &&
                  examLessonId.isNotEmpty &&
                  examLessonId == lessonId) ||
              (examTargetId != null &&
                  examTargetId.isNotEmpty &&
                  examTargetId == lessonId);
          if (targetType == 'lesson') {
            // Strictly keep lesson exams bound to current lesson only.
            return matchesLessonId;
          }
          return matchesLessonId;
        }).toList();
        _isLoadingLessonExams = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lessonExams = [];
        _isLoadingLessonExams = false;
      });
    }
  }

  bool _lessonExamCanStart(Map<String, dynamic> exam) {
    final backendCanStart = exam['can_start'];
    if (backendCanStart is bool && backendCanStart == false) return false;

    final attemptsRemainingRaw = exam['attempts_remaining'];
    final attemptsRemaining = attemptsRemainingRaw is int
        ? attemptsRemainingRaw
        : (attemptsRemainingRaw is num
            ? attemptsRemainingRaw.toInt()
            : int.tryParse(attemptsRemainingRaw?.toString() ?? ''));
    if (attemptsRemaining != null) return attemptsRemaining > 0;

    final maxAttemptsRaw = exam['max_attempts'];
    final maxAttempts = maxAttemptsRaw is int
        ? maxAttemptsRaw
        : (maxAttemptsRaw is num
            ? maxAttemptsRaw.toInt()
            : int.tryParse(maxAttemptsRaw?.toString() ?? ''));
    final attemptsUsedRaw = exam['attempts_used'];
    final attemptsUsed = attemptsUsedRaw is int
        ? attemptsUsedRaw
        : (attemptsUsedRaw is num
            ? attemptsUsedRaw.toInt()
            : int.tryParse(attemptsUsedRaw?.toString() ?? '')) ??
            0;
    if (maxAttempts != null && maxAttempts > 0) {
      return attemptsUsed < maxAttempts;
    }

    return backendCanStart == true || backendCanStart == null;
  }

  Future<void> _startLessonExam(Map<String, dynamic> examData) async {
    final examId = examData['id']?.toString() ?? '';
    if (examId.isEmpty) return;
    if (!_lessonExamCanStart(examData)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No attempts remaining for this exam.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final lesson = widget.lesson;
    if (lesson == null) return;
    String? courseId = widget.courseId;
    courseId ??=
        lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      setState(() => _startingLessonExamId = examId);
      final examSession =
          await ExamsService.instance.startExam(courseId, examId);
      final questions = examSession['questions'] as List?;
      final attemptId = examSession['attempt_id']?.toString();
      if (questions == null || questions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.noQuestionsAvailable,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (!mounted) return;
      final submittedResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrialExamScreen(
            examId: examId,
            courseId: courseId!,
            attemptId: attemptId,
            courseName:
                (widget.lesson?['title']?.toString().isNotEmpty ?? false)
                    ? widget.lesson!['title'].toString()
                    : AppLocalizations.of(context)!.course,
            examData: examData,
            examSession: examSession,
          ),
        ),
      );
      if (!mounted) return;
      if (submittedResult is Map) {
        await _loadLessonExams();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _startingLessonExamId = null);
      }
    }
  }

  Widget _buildLessonExamsSection() {
    if (_isLoadingLessonExams) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
      );
    }
    if (_lessonExams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'لا توجد امتحانات لهذا الدرس حالياً'
              : 'No exams available for this lesson yet',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    return Column(
      children: _lessonExams.map((exam) {
        final examId = exam['id']?.toString() ?? '';
        final title = exam['title']?.toString().trim().isNotEmpty == true
            ? exam['title'].toString()
            : AppLocalizations.of(context)!.exam;
        final targetType =
            exam['target_type']?.toString().toLowerCase().trim() ??
                exam['targetType']?.toString().toLowerCase().trim() ??
                'lesson';
        final badgeText = targetType == 'course'
            ? (Localizations.localeOf(context).languageCode == 'ar'
                ? 'امتحان الدورة'
                : 'Course exam')
            : (Localizations.localeOf(context).languageCode == 'ar'
                ? 'امتحان الدرس'
                : 'Lesson exam');
        final canStart = _lessonExamCanStart(exam);
        final isStarting = _startingLessonExamId == examId;
        final isEnabled = canStart && !isStarting;
        final duration = exam['duration_minutes'];
        final questions = exam['questions_count'];
        final lessonName = exam['lesson_name']?.toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (lessonName != null &&
                  lessonName.trim().isNotEmpty &&
                  targetType == 'lesson') ...[
                const SizedBox(height: 4),
                Text(
                  lessonName,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (questions != null)
                    Text(
                      '${questions.toString()} ${AppLocalizations.of(context)!.question}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  if (questions != null && duration != null)
                    const SizedBox(width: 10),
                  if (duration != null)
                    Text(
                      '${duration.toString()} ${AppLocalizations.of(context)!.minute}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: isEnabled ? () => _startLessonExam(exam) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      minimumSize: const Size(92, 36),
                    ),
                    child: isStarting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            canStart
                                ? AppLocalizations.of(context)!.startExam
                                : (Localizations.localeOf(context)
                                            .languageCode ==
                                        'ar'
                                    ? 'غير متاح'
                                    : 'Unavailable'),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<String> _collectAllAudioUrls() {
    final urls = <String>{};
    void addIfValid(dynamic v) {
      final s = _extractUrlFromAny(v) ?? v?.toString().trim();
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
      final s = _extractUrlFromAny(v) ?? v?.toString().trim();
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
      final source = _extractUrlFromAny(s) ?? s;
      final cleaned = _cleanVideoUrl(source);
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
        addIfValid(_extractUrlFromAny(u) ?? u?.toString());
      }
    }
    final lessonVideos = widget.lesson?['videos'];
    if (lessonVideos is List) {
      for (final u in lessonVideos) {
        addIfValid(_extractUrlFromAny(u) ?? u?.toString());
      }
    }
    return urls;
  }

  Future<void> _switchVideoTrack(int index) async {
    if (index < 0 || index >= _allVideoUrls.length) return;
    if (index == _currentVideoIndex) return;

    _consumedVideoResumeSeek = true;
    await _pauseLessonAudioPlayback();

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
      _isYouTubeVideo = true;
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
      _isYouTubeVideo = false;
      final extracted = _extractVimeoId(videoUrl);
      if (extracted != null) {
        setState(() {
          _isVimeoVideo = true;
          _vimeoId = extracted;
          _vimeoHash = _extractVimeoHash(videoUrl);
          _isVideoLoading = false;
        });
      } else {
        // Vimeo URL matched, but we couldn't extract a numeric id.
        // Fall back to direct playback flow so the UI doesn't get stuck.
        setState(() {
          _isVimeoVideo = false;
          _vimeoId = null;
          _vimeoHash = null;
          _isVideoLoading = false;
        });
        _initializeDirectVideo(videoUrl);
      }
    } else {
      _isYouTubeVideo = false;
      _isVimeoVideo = false;
      _vimeoId = null;
      _vimeoHash = null;
      _initializeDirectVideo(videoUrl);
    }

    if (mounted) {
      setState(() {
        _lessonAccordionUserInteracted = true;
        _openLessonPanel = _lessonPanelVideos;
        _activePdfUrl = null;
      });
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
    var audioWasPlaying = false;
    _audioPlayer!.playingStream.listen((playing) {
      if (!mounted) return;
      if (playing && !audioWasPlaying) {
        _pauseVideoBecauseAudioStarted();
      }
      audioWasPlaying = playing;
      setState(() => _isAudioPlaying = playing);
    });
    _audioPlayer!.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_markLessonComplete());
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
    if (mounted) {
      setState(() {
        _lessonAccordionUserInteracted = true;
        _openLessonPanel = _lessonPanelAudio;
        _activePdfUrl = null;
      });
    }
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

  /// Extract Vimeo numeric video id from a Vimeo URL or id.
  ///
  /// Supports common formats like:
  /// - `vimeo.com/<id>/<hash>`
  /// - `vimeo.com/video/<id>`
  /// - `player.vimeo.com/video/<id>`
  /// - `vimeo.com/channels/<name>/<id>`
  String? _extractVimeoId(String? urlOrId) {
    final s = urlOrId?.trim();
    if (s == null || s.isEmpty) return null;

    // If the payload is already an id.
    if (RegExp(r'^\d+$').hasMatch(s)) return s;

    try {
      final uri = Uri.parse(s);
      for (final segment in uri.pathSegments) {
        if (RegExp(r'^\d+$').hasMatch(segment)) return segment;
      }
    } catch (_) {
      // If parsing fails, fall back to regex below.
    }

    // Fallback regex (best-effort for legacy formats).
    final match =
        RegExp(r'vimeo\.com/(?:video/)?(\d+)').firstMatch(s.toLowerCase());
    return match?.group(1);
  }

  /// Extract Vimeo hash token from URLs like `vimeo.com/<id>/<hash>`.
  String? _extractVimeoHash(String? url) {
    final s = url?.trim();
    if (s == null || s.isEmpty) return null;
    try {
      final uri = Uri.parse(s);
      final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
      for (var i = 0; i < segments.length - 1; i++) {
        if (RegExp(r'^\d+$').hasMatch(segments[i])) {
          final candidate = segments[i + 1].trim();
          if (candidate.isNotEmpty && !RegExp(r'^\d+$').hasMatch(candidate)) {
            return candidate;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _buildVimeoEmbedUrl({int? startAtSeconds}) {
    final id = _vimeoId ?? '';
    final hashPart = (_vimeoHash != null && _vimeoHash!.isNotEmpty)
        ? '&h=${Uri.encodeComponent(_vimeoHash!)}'
        : '';
    final startAt = (startAtSeconds ?? 0);
    final startFragment = startAt > 0 ? '#t=${startAt}s' : '';
    return 'https://player.vimeo.com/video/$id?autoplay=1&muted=0&background=0&playsinline=1&title=0&byline=0&portrait=0$hashPart$startFragment';
  }

  Future<int> _readVimeoCurrentSeconds() async {
    final controller = _webViewController;
    if (!_isVimeoVideo || _vimeoId == null || controller == null) {
      return _vimeoLastPositionSeconds;
    }

    int? _parseJsNumber(dynamic value) {
      final raw = '$value'.replaceAll('"', '').trim();
      final asDouble = double.tryParse(raw);
      if (asDouble != null && asDouble >= 0) return asDouble.floor();
      return null;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await controller.runJavaScriptReturningResult(
            'window.vimeoGetCurrentTime ? window.vimeoGetCurrentTime() : (window.vimeoLastTime ?? -1);');
        final parsed = _parseJsNumber(result);
        if (parsed != null) {
          _vimeoLastPositionSeconds = parsed;
          return _vimeoLastPositionSeconds;
        }
      } catch (_) {}

      // Fallback for WebView engines that don't resolve async JS return values.
      try {
        final fallback = await controller
            .runJavaScriptReturningResult('window.vimeoLastTime ?? -1;');
        final parsed = _parseJsNumber(fallback);
        if (parsed != null) {
          _vimeoLastPositionSeconds = parsed;
          return _vimeoLastPositionSeconds;
        }
      } catch (_) {}

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 140));
      }
    }
    return _vimeoLastPositionSeconds;
  }

  Future<void> _seekVimeoToSeconds(int seconds) async {
    final controller = _webViewController;
    if (!_isVimeoVideo || _vimeoId == null || controller == null) return;
    if (seconds < 0) return;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await controller.runJavaScript('window.vimeoLastTime = $seconds;');
        await controller.runJavaScript(
            'window.vimeoSeekTo ? window.vimeoSeekTo($seconds) : null;');
        _vimeoLastPositionSeconds = seconds;
        return;
      } catch (_) {}
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 180));
      }
    }
    _vimeoLastPositionSeconds = seconds;
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
    // If backend sends a full Vimeo URL instead of just the id, normalize it.
    vimeoId = vimeoId != null ? _extractVimeoId(vimeoId) : null;

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
      vimeoId = _extractVimeoId(videoUrl);
    }

    if (vimeoId != null) {
      if (kDebugMode) {
        print('🎬 Using Vimeo video: $vimeoId');
      }
      if (mounted) {
        setState(() {
          _isYouTubeVideo = false;
          _isVimeoVideo = true;
          _vimeoId = vimeoId;
          _vimeoHash = _extractVimeoHash(videoUrl);
          _isVideoLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isYouTubeVideo = false;
          _isVimeoVideo = false;
          _vimeoId = null;
          _vimeoHash = null;
          _lastLoadedVimeoEmbedUrl = null;
        });
      }
      // Use video URL if available, otherwise use YouTube ID
      if (videoUrl != null && videoUrl.isNotEmpty) {
        // Check if it's a YouTube URL
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          _isYouTubeVideo = true;
          final youtubeSource = _buildYoutubeSourceFromIdOrUrl(videoUrl);
          if (youtubeSource == null) {
            if (kDebugMode) {
              print(
                  '⚠️ Invalid YouTube URL in lesson data. Showing no-video state.');
            }
            _setVideoUnavailableState();
            return;
          }
          if (kDebugMode) {
            print('📺 Using YouTube URL: $youtubeSource');
          }
          _controller = PodPlayerController(
            playVideoFrom: PlayVideoFrom.youtube(youtubeSource),
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
              _setVideoUnavailableState();
            });
        } else {
          _isYouTubeVideo = false;
          // Direct video URL from server - use pod_player with network
          if (kDebugMode) {
            print('📹 Using pod_player for direct video URL: $videoUrl');
          }
          _initializeDirectVideo(videoUrl);
        }
      } else if (videoId.isNotEmpty) {
        _isYouTubeVideo = true;
        // Fallback to YouTube ID
        final youtubeSource = _buildYoutubeSourceFromIdOrUrl(videoId);
        if (youtubeSource == null) {
          if (kDebugMode) {
            print(
                '⚠️ Invalid YouTube ID/URL in lesson data. Showing no-video state.');
          }
          _setVideoUnavailableState();
          return;
        }
        if (kDebugMode) {
          print('📺 Using YouTube fallback source: $youtubeSource');
        }
        _controller = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(youtubeSource),
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
            _setVideoUnavailableState();
          });
      } else {
        _isYouTubeVideo = false;
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

  String? _buildYoutubeSourceFromIdOrUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (v.contains('youtube.com') || v.contains('youtu.be')) {
      final extracted = _extractYoutubeIdFromUrl(v);
      if (extracted == null) return null;
      return 'https://www.youtube.com/watch?v=$extracted';
    }
    final looksLikeYoutubeId = RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v);
    if (!looksLikeYoutubeId) return null;
    return 'https://www.youtube.com/watch?v=$v';
  }

  String? _extractYoutubeIdFromUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl.trim());
      final host = uri.host.toLowerCase();

      if (host.contains('youtu.be')) {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return id;
        return null;
      }

      if (host.contains('youtube.com')) {
        final v = uri.queryParameters['v'] ?? '';
        if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v)) return v;

        final segments = uri.pathSegments;
        if (segments.length >= 2 &&
            (segments.first == 'embed' || segments.first == 'shorts')) {
          final id = segments[1];
          if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return id;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _setVideoUnavailableState() {
    if (!mounted) return;
    setState(() {
      _controller = null;
      _webViewController = null;
      _useWebViewFallback = false;
      _isVideoLoading = false;
      _lastLoadedVimeoEmbedUrl = null;
    });
  }

  /// Initialize direct video playback using pod_player
  Future<void> _initializeDirectVideo(String videoUrl) async {
    try {
      _isYouTubeVideo = false;
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
      try {
        if (window.VideoBridge && window.VideoBridge.postMessage) {
          window.VideoBridge.postMessage('video_error');
        }
      } catch (e) {}
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
      ..addJavaScriptChannel(
        'VideoBridge',
        onMessageReceived: (message) {
          if (message.message == 'video_error') {
            _setVideoUnavailableState();
          }
        },
      )
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
    _vimeoHash = null;
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
    if (_isVimeoFullscreenActive) return;
    if (_isVimeoVideo) return;
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/videoNotFound.png',
                  width: 180,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.ondemand_video_rounded,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),
              ),
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
            _buildVideoSection(lesson),
            Expanded(
              child: _buildLessonInfo(lesson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroTopBar(
    Map<String, dynamic> lesson, {
    List<Widget> trailing = const [],
  }) {
    return Container(
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
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
          ),
          ...trailing,
        ],
      ),
    );
  }

  Widget _buildLessonDescriptionHeroBody() {
    if (_isLoadingContent) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.purple),
      );
    }
    final description = _lessonContent?['content'] as String? ?? '';

    if (description.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocalizations.of(context)!.noLessonDescription,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.mutedForeground,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_looksLikeHtml(description) && _descriptionWebViewController != null) {
      return WebViewWidget(controller: _descriptionWebViewController!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        description,
        style: GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.foreground,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildLessonDescriptionAccordionContent() {
    if (_activeHeroPanel() == _lessonPanelDescription) {
      if (_isLoadingContent) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(
              color: AppColors.purple,
            ),
          ),
        );
      }
      final description = _lessonContent?['content'] as String? ?? '';
      if (description.trim().isEmpty) {
        return Text(
          AppLocalizations.of(context)!.noLessonDescription,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.mutedForeground,
            height: 1.7,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppLocalizations.of(context)!.lessonDescriptionShownTop,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.mutedForeground,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return _buildLessonDescriptionBody();
  }

  Widget _buildHeroDescription(Map<String, dynamic> lesson) {
    final desc = _lessonContent?['content'] as String? ?? '';
    if (desc.isNotEmpty && _looksLikeHtml(desc)) {
      _ensureDescriptionWebViewLoaded(desc);
    }
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildHeroTopBar(lesson),
          SizedBox(
            height: 220,
            child: Container(
              color: const Color(0xFFF8F9FC),
              child: _buildLessonDescriptionHeroBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImages(Map<String, dynamic> lesson, List<String> imageUrls) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildHeroTopBar(
            lesson,
            trailing: [
              if (imageUrls.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${imageUrls.length}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 220,
            child: Container(
              color: const Color(0xFFF8F9FC),
              padding: const EdgeInsets.all(10),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = imageUrls[index];
                  return GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => _LessonImagesViewerDialog(
                          urls: imageUrls,
                          initialIndex: index,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.mutedForeground,
                              size: 24,
                            ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFiles(Map<String, dynamic> lesson) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildHeroTopBar(lesson),
          SizedBox(
            height: 220,
            child: Container(
              color: const Color(0xFFF8F9FC),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _isLoadingContent
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.purple),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        child: _buildResourcesList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(Map<String, dynamic> lesson) {
    final heroPanel = _activeHeroPanel();
    final imageUrls = _collectLessonImageUrls();

    if (heroPanel == _lessonPanelDescription) {
      return _buildHeroDescription(lesson);
    }
    if (heroPanel == _lessonPanelImages && imageUrls.isNotEmpty) {
      return _buildHeroImages(lesson, imageUrls);
    }
    if (heroPanel == _lessonPanelAudio && _allAudioUrls.isNotEmpty) {
      return _buildAudioPlayer();
    }
    if (heroPanel == _lessonPanelFiles) {
      return _buildHeroFiles(lesson);
    }

    // If there is no playable video source, use lesson images as
    // the primary hero content in gallery mode.
    if (!_hasAnyVideoSource() && imageUrls.isNotEmpty) {
      return _buildHeroImages(lesson, imageUrls);
    }

    if (_isAudioLesson) return _buildAudioPlayer();

    if (_isVimeoVideo && _vimeoId != null) {
      final embedUrl =
          _buildVimeoEmbedUrl(startAtSeconds: _vimeoLastPositionSeconds);
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
  <script src="https://player.vimeo.com/api/player.js"></script>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
      position: relative;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
    }
    iframe {
      position: fixed;
      inset: 0;
      width: 100vw;
      height: 100vh;
      border: 0;
      display: block;
      pointer-events: auto;
    }
    .menu-hit-blocker-left,
    .vimeo-top-actions-hit-blocker,
    .vimeo-settings-hit-blocker {
      position: fixed;
      z-index: 3;
      background: transparent;
      pointer-events: auto;
    }
    .menu-hit-blocker-left {
      top: 0;
      height: 64px;
    }
    .menu-hit-blocker-left {
      left: 0;
      width: 88px;
    }
    .vimeo-top-actions-hit-blocker {
      top: 0;
      right: 0;
      width: 170px;
      height: 88px;
    }
    .vimeo-settings-hit-blocker {
      right: 0;
      bottom: 0;
      width: 180px;
      height: 92px;
      border-radius: 999px;
      z-index: 9999;
    }
  </style>
</head>
<body>
  <iframe
    id="vimeoPlayer"
    src="$embedUrl"
    allow="autoplay">
  </iframe>
  <div class="menu-hit-blocker-left"></div>
  <div class="vimeo-top-actions-hit-blocker"></div>
  <div class="vimeo-settings-hit-blocker"></div>
  <script>
    // Security hardening: block long-press/context menu inside WebView.
    document.addEventListener('contextmenu', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('selectstart', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('dragstart', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('touchstart', function () {}, { passive: true });
    const iframe = document.getElementById('vimeoPlayer');
    const player = new Vimeo.Player(iframe);
    window.vimeoLastTime = ${_vimeoLastPositionSeconds};
    player.ready().then(async () => {
      try {
        await player.setVolume(1);
        await player.setMuted(false);
      } catch (_) {}
    });
    player.on('play', async function () {
      window.vimeoIsPlaying = true;
      try {
        await player.setVolume(1);
        await player.setMuted(false);
      } catch (_) {}
    });
    player.on('pause', function () {
      window.vimeoIsPlaying = false;
    });
    player.on('ended', function () {
      window.vimeoIsPlaying = false;
      window.vimeoEnded = true;
      try { FlutterBridge.postMessage('vimeo_ended'); } catch (_) {}
    });
    player.on('timeupdate', function (data) {
      try {
        const sec = Math.max(0, Math.floor((data && data.seconds) || 0));
        window.vimeoLastTime = sec;
      } catch (_) {}
    });
    window.vimeoGetCurrentTime = async function () {
      try {
        const sec = await player.getCurrentTime();
        window.vimeoLastTime = Math.max(0, Math.floor(sec || 0));
        return window.vimeoLastTime;
      } catch (_) {
        return window.vimeoLastTime ?? -1;
      }
    };
    window.vimeoSeekTo = async function (sec) {
      try {
        const target = Number(sec || 0);
        await player.setCurrentTime(target);
        return true;
      } catch (_) {
        return false;
      }
    };
  </script>
</body>
</html>
''';

      if (_webViewController == null) {
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..addJavaScriptChannel(
            'FlutterBridge',
            onMessageReceived: (JavaScriptMessage msg) {
              if (msg.message == 'vimeo_ended' && !_lessonMarkedComplete) {
                unawaited(_markLessonComplete());
              }
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                if (_allowEmbeddedVimeoTopLevelNavigation(request.url)) {
                  return NavigationDecision.navigate;
                }
                if (kDebugMode) {
                  print(
                      '🔒 Blocked Vimeo top-level navigation: ${request.url}');
                }
                return NavigationDecision.prevent;
              },
              onPageFinished: (_) {
                if (_vimeoLastPositionSeconds > 0) {
                  Future.delayed(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    unawaited(_seekVimeoToSeconds(_vimeoLastPositionSeconds));
                  });
                }
              },
            ),
          );
      }
      if (_lastLoadedVimeoEmbedUrl != embedUrl) {
        _webViewController!.loadHtmlString(html);
        _lastLoadedVimeoEmbedUrl = embedUrl;
      }
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
                IconButton(
                  tooltip: _isBookmarkedLesson
                      ? 'Remove bookmark'
                      : 'Bookmark lesson',
                  onPressed: _toggleLessonBookmark,
                  icon: Icon(
                    _isBookmarkedLesson
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isBookmarkedLesson
                        ? const Color(0xFFF59E0B)
                        : Colors.white,
                    size: 24,
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
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          'assets/images/videoNotFound.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.black,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.ondemand_video_rounded,
                                              color: Colors.white70,
                                              size: 34,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black
                                                    .withValues(alpha: 0.08),
                                                Colors.black
                                                    .withValues(alpha: 0.45),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 14),
                                            child: Text(
                                              AppLocalizations.of(context)!
                                                  .noVideoUrlToDownload,
                                              style: GoogleFonts.cairo(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                if (_controller == null)
                  IgnorePointer(child: _buildVideoWatermarkOverlay()),
                if (!_isVideoLoading &&
                    _isVimeoVideo &&
                    _vimeoId != null &&
                    _webViewController != null)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        tooltip: 'Fullscreen',
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _openVideoFullscreen,
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

  Widget _buildCustomPodOverlay(OverLayOptions options) {
    final showOverlay = options.isOverlayVisible;
    final showControls = showOverlay && _showVideoOverlayButtons;
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final isFullscreen = options.isFullScreen == true;
    final watermark = '$_watermarkUserName • $_watermarkSessionTag';
    return Stack(
      fit: StackFit.expand,
      children: [
        // Single tap: show/hide controls only (play/pause via button below).
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final c = _controller;
            if (c == null) return;
            try {
              final next = !_showVideoOverlayButtons;
              if (mounted) {
                setState(() => _showVideoOverlayButtons = next);
              } else {
                _showVideoOverlayButtons = next;
              }
              if (next) c.showOverlay();
              if (mounted) setState(() {});
            } catch (_) {}
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: showControls
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
        if (showControls) ...[
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
                Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    tooltip: options.podVideoState == PodVideoState.paused
                        ? 'Play'
                        : 'Pause',
                    icon: Icon(
                      options.podVideoState == PodVideoState.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
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
                  ),
                ),
                const SizedBox(width: 6),
                if (_isYouTubeVideo) ...[
                  _buildQuickSeekButton(
                    icon: Icons.replay_10_rounded,
                    onPressed: () =>
                        _seekYoutubeBy(const Duration(seconds: -10)),
                  ),
                  const SizedBox(width: 10),
                  _buildQuickSeekButton(
                    icon: Icons.forward_10_rounded,
                    onPressed: () =>
                        _seekYoutubeBy(const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 6),
                ],
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

  Widget _buildQuickSeekButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Future<void> _seekYoutubeBy(Duration delta) async {
    if (!_isYouTubeVideo) return;
    final c = _controller;
    if (c == null) return;
    try {
      final inner = Get.find<PodGetXVideoController>(tag: c.getTag);
      final videoCtr = inner.videoCtr;
      final value = videoCtr?.value;
      if (videoCtr == null || value == null) return;

      final current = value.position;
      final total = value.duration;
      var target = current + delta;
      if (target < Duration.zero) target = Duration.zero;
      if (total > Duration.zero && target > total) {
        target = total - const Duration(milliseconds: 250);
        if (target < Duration.zero) target = Duration.zero;
      }

      await videoCtr.seekTo(target);
      // Force an immediate + short delayed repaint so progress bar
      // stays visually in sync with quick seek controls.
      if (mounted) setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (mounted) setState(() {});
      c.showOverlay();
    } catch (e) {
      if (kDebugMode) {
        print('YouTube quick seek failed: $e');
      }
    }
  }

  Future<void> _openVideoFullscreen() async {
    if (_isVimeoVideo && _vimeoId != null && mounted) {
      setState(() => _isVimeoFullscreenActive = true);
      try {
        final startAtSeconds = await _readVimeoCurrentSeconds();
        _vimeoLastPositionSeconds = startAtSeconds;
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        final returnedSeconds = await Navigator.of(context).push<int>(
          MaterialPageRoute<int>(
            builder: (_) => _VimeoFullscreenScreen(
              embedUrl: _buildVimeoEmbedUrl(startAtSeconds: startAtSeconds),
              startAtSeconds: startAtSeconds,
            ),
          ),
        );
        final resumeAt = (returnedSeconds ?? startAtSeconds).clamp(0, 1 << 30);
        _vimeoLastPositionSeconds = resumeAt;
        await _seekVimeoToSeconds(resumeAt);
      } finally {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (mounted) {
          setState(() => _isVimeoFullscreenActive = false);
        } else {
          _isVimeoFullscreenActive = false;
        }
      }
      return;
    }

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
                        AppLocalizations.of(context)!.loadingAudioDuration,
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

  Widget _buildAudioFilesSection({bool forAccordion = false}) {
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

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );

    if (forAccordion) return body;

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
                AppLocalizations.of(context)!.audioFiles,
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
          body,
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
    final name = _displayNameForIndexedUrl(
      url,
      kind: 'audio',
      index: index,
      fallback: 'Audio ${index + 1}',
    );
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
                    AppLocalizations.of(context)!.audioClipLabel(index + 1),
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

  Widget _buildVideoFilesSection({bool forAccordion = false}) {
    if (_allVideoUrls.isEmpty) {
      if (!forAccordion) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppLocalizations.of(context)!.tapToShowVideoTop,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.mutedForeground,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_allVideoUrls.length == 1 && forAccordion) {
      return _buildVideoTrackItem(0, _allVideoUrls.first, true);
    }
    if (_allVideoUrls.length <= 1) return const SizedBox.shrink();

    final tracks = List.generate(_allVideoUrls.length, (index) {
      final url = _allVideoUrls[index];
      final isCurrent = index == _currentVideoIndex;
      return _buildVideoTrackItem(index, url, isCurrent);
    });

    if (forAccordion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tracks,
      );
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.video_library_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.videoFiles,
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
          ...tracks,
        ],
      ),
    );
  }

  Widget _buildVideoTrackItem(int index, String url, bool isCurrent) {
    final name = _displayNameForIndexedUrl(
      url,
      kind: 'video',
      index: index,
      fallback: 'Video ${index + 1}',
    );
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
                    AppLocalizations.of(context)!.videoLabel(index + 1),
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
                  AppLocalizations.of(context)!.nowPlaying,
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

  Widget _buildPdfFilesSection({bool forAccordion = false}) {
    final pdfUrls = _collectAllPdfUrls();
    if (pdfUrls.isEmpty) return const SizedBox.shrink();

    final items = List.generate(pdfUrls.length, (index) {
      return _buildPdfItem(index, pdfUrls[index]);
    });

    if (forAccordion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      );
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.pdfFiles,
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
          ...items,
        ],
      ),
    );
  }

  Widget _buildPdfItem(int index, String url) {
    final name = _displayNameForIndexedUrl(
      url,
      kind: 'pdf',
      index: index,
      fallback: 'Document ${index + 1}',
    );
    final isActive = _activePdfUrl == url;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _pauseMainVideoPlayback();
        unawaited(_pauseLessonAudioPlayback());
        setState(() {
          _lessonAccordionUserInteracted = true;
          _activePdfUrl = url;
        });
        final normalizedPdfUrl = googleDriveDirectDownloadUrl(url) ?? url;
        context.push(
          RouteNames.pdfViewer,
          extra: {
            'pdfUrl': normalizedPdfUrl,
            'title': name,
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.orange.withOpacity(0.08)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: Colors.orange.withOpacity(0.3))
              : null,
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
                    AppLocalizations.of(context)!.pdfFileLabel(index + 1),
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.orange.withOpacity(0.14)
                    : AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive ? Icons.check_rounded : Icons.preview_rounded,
                color: isActive ? Colors.orange : AppColors.purple,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonDescriptionBody() {
    if (_isLoadingContent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(
            color: AppColors.purple,
          ),
        ),
      );
    }
    return Builder(
      builder: (context) {
        final description = _lessonContent?['content'] as String? ?? '';

        if (description.trim().isEmpty) {
          return Text(
            AppLocalizations.of(context)!.noLessonDescription,
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
    );
  }

  Widget _buildDownloadSectionBody() {
    if (_isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      );
    }
    if (_isDownloaded) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
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
      );
    }
    return ElevatedButton.icon(
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
    );
  }

  Widget _buildLessonInfo(Map<String, dynamic> lesson) {
    final imageUrls = _collectLessonImageUrls();
    final pdfUrls = _collectAllPdfUrls();

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

            _lessonAccordionCard(
              panelId: _lessonPanelDescription,
              title: AppLocalizations.of(context)!.lessonDescriptionTitle,
              icon: Icons.description_rounded,
              accent: AppColors.purple,
              child: _buildLessonDescriptionAccordionContent(),
            ),
            if (imageUrls.isNotEmpty)
              _lessonAccordionCard(
                panelId: _lessonPanelImages,
                title: AppLocalizations.of(context)!.lessonImages,
                icon: Icons.image_rounded,
                accent: Colors.blue,
                badge: imageUrls.length,
                child: _activeHeroPanel() == _lessonPanelImages
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          AppLocalizations.of(context)!.imageGalleryShownTop,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _buildImagesSection(imageUrls, forAccordion: true),
              ),
            if (_shouldShowLessonAudioPanel())
              _lessonAccordionCard(
                panelId: _lessonPanelAudio,
                title: AppLocalizations.of(context)!.audioFiles,
                icon: Icons.headphones_rounded,
                accent: Colors.deepPurple,
                badge: _allAudioUrls.length,
                child: _buildAudioFilesSection(forAccordion: true),
              ),
            _lessonAccordionCard(
              panelId: _lessonPanelExams,
              title: AppLocalizations.of(context)!.exams,
              icon: Icons.quiz_rounded,
              accent: const Color(0xFF0C52B3),
              badge: _lessonExams.isEmpty ? null : _lessonExams.length,
              child: _buildLessonExamsSection(),
            ),
            if (_hasAnyVideoSource() || _allVideoUrls.isNotEmpty)
              _lessonAccordionCard(
                panelId: _lessonPanelVideos,
                title: AppLocalizations.of(context)!.videoFiles,
                icon: Icons.video_library_rounded,
                accent: Colors.red,
                badge: _allVideoUrls.isNotEmpty ? _allVideoUrls.length : null,
                child: _buildVideoFilesSection(forAccordion: true),
              ),
            if (pdfUrls.isNotEmpty)
              _lessonAccordionCard(
                panelId: _lessonPanelPdfs,
                title: AppLocalizations.of(context)!.pdfFiles,
                icon: Icons.picture_as_pdf_rounded,
                accent: Colors.orange,
                badge: pdfUrls.length,
                child: _buildPdfFilesSection(forAccordion: true),
              ),
            _lessonAccordionCard(
              panelId: _lessonPanelDownload,
              title: AppLocalizations.of(context)!.downloadForOffline,
              icon: Icons.download_rounded,
              accent: AppColors.purple,
              child: _activeHeroPanel() == _lessonPanelDownload
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        AppLocalizations.of(context)!.downloadShownTop,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _buildDownloadSectionBody(),
            ),
            _lessonAccordionCard(
              panelId: _lessonPanelFiles,
              title: AppLocalizations.of(context)!.lessonFiles,
              icon: Icons.folder_rounded,
              accent: Colors.orange,
              child: _isLoadingContent
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: AppColors.purple,
                        ),
                      ),
                    )
                  : _activeHeroPanel() == _lessonPanelFiles
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            AppLocalizations.of(context)!.lessonFilesShownTop,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _buildResourcesList(),
            ),
            const SizedBox(height: 4),

            // Navigation Buttons
            Builder(builder: (context) {
              final allLessons = widget.allLessons;
              final idx = widget.lessonIndex;
              final hasPrev = idx > 0 && allLessons.isNotEmpty;
              final hasNext =
                  idx >= 0 && idx < allLessons.length - 1;

              void goToLesson(int targetIndex) {
                final targetLesson = allLessons[targetIndex];
                context.pushReplacement(RouteNames.lessonViewer, extra: {
                  'lesson': targetLesson,
                  'courseId': widget.courseId,
                  'allLessons': allLessons,
                  'lessonIndex': targetIndex,
                });
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildNavButton(
                      AppLocalizations.of(context)!.previousLesson,
                      Icons.arrow_back_rounded,
                      false,
                      hasPrev
                          ? () => goToLesson(idx - 1)
                          : () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNavButton(
                      AppLocalizations.of(context)!.nextLesson,
                      Icons.arrow_forward_rounded,
                      true,
                      hasNext ? () => goToLesson(idx + 1) : null,
                    ),
                  ),
                ],
              );
            }),
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

  String? _fileNameFromQueryParams(String url) {
    try {
      final uri = Uri.parse(url);
      const keys = [
        'filename',
        'file_name',
        'file',
        'name',
        'title',
        'download'
      ];
      for (final k in keys) {
        final v = uri.queryParameters[k]?.trim();
        if (v != null && v.isNotEmpty) return Uri.decodeComponent(v);
      }
    } catch (_) {}
    return null;
  }

  bool _looksMachineGeneratedName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return true;
    final base = n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
    if (base.length >= 14 && RegExp(r'^[a-z0-9_-]+$').hasMatch(base)) {
      final hasLetters = RegExp(r'[a-z]').hasMatch(base);
      final hasDigits = RegExp(r'\d').hasMatch(base);
      if (hasLetters && hasDigits) return true;
    }
    if (RegExp(r'^[a-f0-9]{16,}$').hasMatch(base)) return true; // hash-like
    return false;
  }

  String _prettyFileName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return name;
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name;
  }

  String? _nameFromParallelListKey(
      Map<String, dynamic>? source, List<String> keys, int index) {
    if (source == null || index < 0) return null;
    for (final key in keys) {
      final raw = source[key];
      if (raw is! List || index >= raw.length) continue;
      final item = raw[index];
      String? value;
      if (item is String) {
        value = item.trim();
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        value = map['title']?.toString().trim() ??
            map['name']?.toString().trim() ??
            map['file_name']?.toString().trim() ??
            map['label']?.toString().trim();
      } else {
        value = item?.toString().trim();
      }
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _displayNameFromParallelArrays({
    required String kind,
    required int index,
  }) {
    final keys = <String>[];
    switch (kind) {
      case 'pdf':
        keys.addAll(
            ['pdf_names', 'pdf_titles', 'pdf_labels', 'pdf_files_names']);
        break;
      case 'audio':
        keys.addAll([
          'audio_names',
          'audio_titles',
          'audio_labels',
          'audio_files_names'
        ]);
        break;
      case 'video':
        keys.addAll([
          'video_names',
          'video_titles',
          'video_labels',
          'video_files_names'
        ]);
        break;
      case 'drive':
        keys.addAll([
          'google_drive_names',
          'google_drive_titles',
          'drive_names',
          'drive_titles'
        ]);
        break;
      case 'file':
        keys.addAll(
            ['file_names', 'file_titles', 'files_names', 'files_titles']);
        break;
      default:
        return null;
    }
    final fromContent = _nameFromParallelListKey(_lessonContent, keys, index);
    final fromLesson = _nameFromParallelListKey(widget.lesson, keys, index);
    final candidate = (fromContent ?? fromLesson)?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    final pretty = _prettyFileName(candidate);
    if (pretty.isEmpty || _looksMachineGeneratedName(pretty)) return null;
    return pretty;
  }

  String _normalizeUrlForLookup(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    try {
      final uri = Uri.parse(raw);
      final normalizedPath = uri.path.isEmpty ? '/' : uri.path;
      return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$normalizedPath';
    } catch (_) {
      return raw.split('?').first.trim();
    }
  }

  String _urlLastSegmentKey(String url) {
    final name = _fileNameFromUrl(url).trim().toLowerCase();
    return name;
  }

  String? _extractUrlFromAny(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final s = value.trim();
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      return null;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final urlKeys = [
        'url',
        'file_url',
        'file_path',
        'path',
        'src',
        'link',
        'video_url',
        'audio_url',
        'pdf_url',
        'google_drive_url',
      ];
      for (final key in urlKeys) {
        final candidate = map[key]?.toString().trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            (candidate.startsWith('http://') ||
                candidate.startsWith('https://'))) {
          return candidate;
        }
      }
    }
    return null;
  }

  String? _extractDisplayNameFromAny(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final nameKeys = [
      'title',
      'name',
      'file_name',
      'filename',
      'original_name',
      'display_name',
      'label',
    ];
    for (final key in nameKeys) {
      final candidate = map[key]?.toString().trim();
      if (candidate != null &&
          candidate.isNotEmpty &&
          candidate.toLowerCase() != 'google drive') {
        return candidate;
      }
    }
    return null;
  }

  Map<String, String> _buildUrlDisplayNameIndex() {
    final index = <String, String>{};

    void addEntriesFromList(dynamic raw) {
      if (raw is! List) return;
      for (final entry in raw) {
        final url = _extractUrlFromAny(entry);
        if (url == null) continue;
        final name = _extractDisplayNameFromAny(entry);
        if (name == null || name.isEmpty) continue;
        final key = _normalizeUrlForLookup(url);
        index.putIfAbsent(key, () => name);
        final lastSeg = _urlLastSegmentKey(url);
        if (lastSeg.isNotEmpty) {
          index.putIfAbsent('seg::$lastSeg', () => name);
        }
      }
    }

    addEntriesFromList(_lessonContent?['media']);
    addEntriesFromList(widget.lesson?['media']);
    addEntriesFromList(_lessonContent?['files']);
    addEntriesFromList(widget.lesson?['files']);
    addEntriesFromList(_lessonContent?['attachments']);
    addEntriesFromList(widget.lesson?['attachments']);
    addEntriesFromList(_lessonContent?['audio_urls']);
    addEntriesFromList(widget.lesson?['audio_urls']);
    addEntriesFromList(_lessonContent?['pdf_urls']);
    addEntriesFromList(widget.lesson?['pdf_urls']);
    addEntriesFromList(_lessonContent?['videos']);
    addEntriesFromList(widget.lesson?['videos']);
    addEntriesFromList(_lessonContent?['file_urls']);
    addEntriesFromList(widget.lesson?['file_urls']);
    addEntriesFromList(_lessonContent?['google_drive_links']);
    addEntriesFromList(widget.lesson?['google_drive_links']);

    return index;
  }

  String _displayNameForUrl(String url, {String? fallback}) {
    final key = _normalizeUrlForLookup(url);
    final index = _buildUrlDisplayNameIndex();
    final fromIndex = index[key]?.trim();
    if (fromIndex != null && fromIndex.isNotEmpty) {
      final pretty = _prettyFileName(fromIndex);
      if (pretty.isNotEmpty && !_looksMachineGeneratedName(pretty)) {
        return pretty;
      }
    }
    final fromSegment = index['seg::${_urlLastSegmentKey(url)}']?.trim();
    if (fromSegment != null && fromSegment.isNotEmpty) {
      final pretty = _prettyFileName(fromSegment);
      if (pretty.isNotEmpty && !_looksMachineGeneratedName(pretty)) {
        return pretty;
      }
    }
    final fromQuery = _fileNameFromQueryParams(url)?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      final pretty = _prettyFileName(fromQuery);
      if (pretty.isNotEmpty) return pretty;
    }
    final fromUrl = _fileNameFromUrl(url).trim();
    if (fromUrl.isNotEmpty) {
      final pretty = _prettyFileName(fromUrl);
      if (!_looksMachineGeneratedName(pretty)) return pretty;
    }
    return (fallback == null || fallback.trim().isEmpty)
        ? 'File'
        : fallback.trim();
  }

  String _displayNameForIndexedUrl(
    String url, {
    required String kind,
    required int index,
    required String fallback,
  }) {
    final fromParallel =
        _displayNameFromParallelArrays(kind: kind, index: index);
    if (fromParallel != null && fromParallel.isNotEmpty) return fromParallel;
    return _displayNameForUrl(url, fallback: fallback);
  }

  Widget _buildResourcesList() {
    final List<Map<String, dynamic>> resourceList = [];

    // General files from both sources
    final fileUrlsSet = <String>{};
    final contentFileUrls = _lessonContent?['file_urls'];
    if (contentFileUrls is List) {
      for (final u in contentFileUrls) {
        final s = _extractUrlFromAny(u) ?? u?.toString().trim() ?? '';
        if (s.isNotEmpty) fileUrlsSet.add(s);
      }
    }
    final lessonFileUrls = widget.lesson?['file_urls'];
    if (lessonFileUrls is List) {
      for (final u in lessonFileUrls) {
        final s = _extractUrlFromAny(u) ?? u?.toString().trim() ?? '';
        if (s.isNotEmpty) fileUrlsSet.add(s);
      }
    }
    var fileIndex = 0;
    for (final u in fileUrlsSet) {
      resourceList.add({
        'title': _displayNameForIndexedUrl(
          u,
          kind: 'file',
          index: fileIndex++,
          fallback: 'File',
        ),
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
        final s = _extractUrlFromAny(u) ?? u?.toString().trim() ?? '';
        if (s.isNotEmpty) driveLinksSet.add(s);
      }
    }
    final lessonDriveLinks = widget.lesson?['google_drive_links'];
    if (lessonDriveLinks is List) {
      for (final u in lessonDriveLinks) {
        final s = _extractUrlFromAny(u) ?? u?.toString().trim() ?? '';
        if (s.isNotEmpty) driveLinksSet.add(s);
      }
    }
    var driveIndex = 0;
    for (final u in driveLinksSet) {
      resourceList.add({
        'title': _displayNameForIndexedUrl(
          u,
          kind: 'drive',
          index: driveIndex++,
          fallback: 'Google Drive',
        ),
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
    final isPdf =
        resourceLooksLikePdf(url, title) || icon == Icons.picture_as_pdf;
    final isDrive = isGoogleDriveUrl(url);
    final lowerUrl = url.toLowerCase();
    final isImage = lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp') ||
        icon == Icons.image;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: url.isNotEmpty
          ? () async {
              if (kDebugMode) {
                print('Opening resource: $url');
              }

              if (isPdf) {
                // Open PDF in viewer screen
                final normalizedPdfUrl =
                    googleDriveDirectDownloadUrl(url) ?? url;
                context.push(
                  RouteNames.pdfViewer,
                  extra: {
                    'pdfUrl': normalizedPdfUrl,
                    'title': title,
                  },
                );
              } else if (isDrive) {
                final embeddedUrl = googleDriveFilePreviewUrl(url) ??
                    googleDriveFolderEmbedUrl(url) ??
                    url;
                context.push(
                  RouteNames.embedWebViewer,
                  extra: {
                    'url': embeddedUrl,
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
                                      AppLocalizations.of(context)!
                                          .imageLoadFailed,
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
                final uri = Uri.tryParse(url);
                if (uri == null) return;
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.cannotLoadThisVideo,
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
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
                isPdf
                    ? Icons.preview_rounded
                    : (isDrive
                        ? Icons.open_in_new_rounded
                        : Icons.download_rounded),
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
      String text, IconData icon, bool isPrimary, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
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
      ),
    );
  }
}

class _LessonImagesViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _LessonImagesViewerDialog({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_LessonImagesViewerDialog> createState() =>
      _LessonImagesViewerDialogState();
}

class _LessonImagesViewerDialogState extends State<_LessonImagesViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: widget.urls.length,
                itemBuilder: (context, index) {
                  final url = widget.urls[index];
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AppLocalizations.of(context)!.imageLoadFailed,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Text(
                  '${_currentIndex + 1} / ${widget.urls.length}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VimeoFullscreenScreen extends StatefulWidget {
  final String embedUrl;
  final int startAtSeconds;

  const _VimeoFullscreenScreen({
    required this.embedUrl,
    required this.startAtSeconds,
  });

  @override
  State<_VimeoFullscreenScreen> createState() => _VimeoFullscreenScreenState();
}

class _VimeoFullscreenScreenState extends State<_VimeoFullscreenScreen> {
  late final WebViewController _controller;

  Future<int> _readCurrentSeconds() async {
    int? parsedFromRaw(dynamic value) {
      final raw = '$value'.replaceAll('"', '').trim();
      final asDouble = double.tryParse(raw);
      if (asDouble != null && asDouble >= 0) return asDouble.floor();
      return null;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _controller.runJavaScriptReturningResult(
            'window.vimeoGetCurrentTimeFs ? window.vimeoGetCurrentTimeFs() : (window.vimeoLastTimeFs ?? -1);');
        final parsed = parsedFromRaw(result);
        if (parsed != null) return parsed;
      } catch (_) {}

      try {
        final fallback = await _controller
            .runJavaScriptReturningResult('window.vimeoLastTimeFs ?? -1;');
        final parsed = parsedFromRaw(fallback);
        if (parsed != null) return parsed;
      } catch (_) {}

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    return widget.startAtSeconds;
  }

  Future<void> _closeWithCurrentTime() async {
    final sec = await _readCurrentSeconds();
    if (!mounted) return;
    Navigator.of(context).pop(sec);
  }

  @override
  void initState() {
    super.initState();
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
  <script src="https://player.vimeo.com/api/player.js"></script>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
      position: relative;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
    }
    iframe {
      position: fixed;
      inset: 0;
      width: 100vw;
      height: 100vh;
      border: 0;
      display: block;
      pointer-events: auto;
    }
    .menu-hit-blocker-left,
    .vimeo-top-actions-hit-blocker,
    .vimeo-settings-hit-blocker {
      position: fixed;
      z-index: 3;
      background: transparent;
      pointer-events: auto;
    }
    .menu-hit-blocker-left {
      top: 0;
      height: 64px;
    }
    .menu-hit-blocker-left {
      left: 0;
      width: 88px;
    }
    .vimeo-top-actions-hit-blocker {
      top: 0;
      right: 0;
      width: 170px;
      height: 88px;
    }
    .vimeo-settings-hit-blocker {
      right: 0;
      bottom: 0;
      width: 220px;
      height: 110px;
      border-radius: 999px;
      z-index: 9999;
    }
  </style>
</head>
<body>
  <iframe
    id="vimeoPlayerFs"
    src="${widget.embedUrl}"
    allow="autoplay">
  </iframe>
  <div class="menu-hit-blocker-left"></div>
  <div class="vimeo-top-actions-hit-blocker"></div>
  <div class="vimeo-settings-hit-blocker"></div>
  <script>
    // Security hardening: block long-press/context menu inside WebView.
    document.addEventListener('contextmenu', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('selectstart', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('dragstart', function (e) { e.preventDefault(); }, { passive: false });
    document.addEventListener('touchstart', function () {}, { passive: true });
    const iframe = document.getElementById('vimeoPlayerFs');
    const player = new Vimeo.Player(iframe);
    const startAt = ${widget.startAtSeconds};
    window.vimeoLastTimeFs = startAt;
    player.ready().then(async () => {
      try {
        await player.setVolume(1);
        await player.setMuted(false);
        if (startAt > 0) {
          await player.setCurrentTime(startAt);
        }
      } catch (_) {}
    });
    player.on('play', async function () {
      try {
        await player.setVolume(1);
        await player.setMuted(false);
      } catch (_) {}
    });
    player.on('timeupdate', function (data) {
      try {
        const sec = Math.max(0, Math.floor((data && data.seconds) || 0));
        window.vimeoLastTimeFs = sec;
      } catch (_) {}
    });
    window.vimeoGetCurrentTimeFs = async function () {
      try {
        const sec = await player.getCurrentTime();
        window.vimeoLastTimeFs = Math.max(0, Math.floor(sec || 0));
        return window.vimeoLastTimeFs;
      } catch (_) {
        return window.vimeoLastTimeFs ?? -1;
      }
    };
  </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_allowEmbeddedVimeoTopLevelNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            if (kDebugMode) {
              print('🔒 Blocked Vimeo fullscreen navigation: ${request.url}');
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(html);

    // Force landscape immersive mode for true video fullscreen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore lesson screen defaults on exit.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _closeWithCurrentTime();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit_rounded,
                      color: Colors.white),
                  onPressed: _closeWithCurrentTime,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
