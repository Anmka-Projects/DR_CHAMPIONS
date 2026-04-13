import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';

class DownloadedVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  const DownloadedVideoPlayer({
    super.key,
    required this.videoPath,
    required this.videoTitle,
  });

  @override
  State<DownloadedVideoPlayer> createState() => _DownloadedVideoPlayerState();
}

class _DownloadedVideoPlayerState extends State<DownloadedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    print('Initializing video player with path: ${widget.videoPath}');

    // Check if file exists
    final file = File(widget.videoPath);
    if (!file.existsSync()) {
      print('Video file does not exist: ${widget.videoPath}');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ملف الفيديو غير موجود',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Extra debug: log file size and extension to help diagnose format issues
    try {
      final fileSize = file.lengthSync();
      final ext = widget.videoPath.split('.').last.toLowerCase();
      print('Local video file details -> size: ${fileSize} bytes, ext: .$ext');
      if (fileSize < 1024) {
        print(
            '⚠️ Video file is very small (<1KB). It might be an HTML/JSON error page, not a real video file.');
      }
    } catch (e) {
      print('Error reading video file info: $e');
    }

    _controller = VideoPlayerController.file(file);

    _controller!.initialize().then((_) {
      print('Video controller initialized successfully');
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
    }).catchError((error) {
      print('Error initializing video controller: $error');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحميل الفيديو: $error',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.videoTitle,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
              ),
            )
          : _controller!.value.isInitialized
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),

                        // Controls Overlay
                        if (_showControls)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.3),
                              child: Stack(
                                children: [
                                  // Center play button - truly centered on video
                                  Center(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (_isPlaying) {
                                              _controller!.pause();
                                            } else {
                                              _controller!.play();
                                            }
                                            _isPlaying = !_isPlaying;
                                          });
                                        },
                                        customBorder: const CircleBorder(),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: const BoxDecoration(
                                            color: AppColors.purple,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Bottom controls
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Progress bar
                                          VideoProgressIndicator(
                                            _controller!,
                                            allowScrubbing: true,
                                            colors: VideoProgressColors(
                                              playedColor: AppColors.purple,
                                              bufferedColor: Colors.white54,
                                              backgroundColor: Colors.white24,
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Bottom row controls
                                          Row(
                                            children: [
                                              // Play/Pause button
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    if (_isPlaying) {
                                                      _controller!.pause();
                                                    } else {
                                                      _controller!.play();
                                                    }
                                                    _isPlaying = !_isPlaying;
                                                  });
                                                },
                                                icon: Icon(
                                                  _isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),

                                              // Time display
                                              Expanded(
                                                child: Text(
                                                  '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                                                  style: GoogleFonts.cairo(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),

                                              // Speed control
                                              PopupMenuButton<double>(
                                                icon: const Icon(
                                                  Icons.speed,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 0.5,
                                                    child: Text('0.5x'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 0.75,
                                                    child: Text('0.75x'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 1.0,
                                                    child: Text('1x'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 1.25,
                                                    child: Text('1.25x'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 1.5,
                                                    child: Text('1.5x'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 2.0,
                                                    child: Text('2x'),
                                                  ),
                                                ],
                                                onSelected: (speed) {
                                                  _controller!
                                                      .setPlaybackSpeed(speed);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ في تحميل الفيديو',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'مسار الفيديو: ${widget.videoPath}',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        label: Text(
                          'رجوع',
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
