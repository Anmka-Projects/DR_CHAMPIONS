import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/services/download_manager.dart';

class YoutubeVideoService {
  YoutubeVideoService._();
  static final instance = YoutubeVideoService._();
  final YoutubeExplode _yt = YoutubeExplode();

  /// Download YouTube video and return local file path (or null on fail)
  Future<String?> downloadYoutubeVideo(
    String youtubeUrl, {
    required Function(int progress) onProgress,
    String? fileName,
  }) async {
    try {
      final video = await _yt.videos.get(youtubeUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Pick highest MP4 progressive stream (video + audio)
      final streamInfo = manifest.muxed.withHighestBitrate();
      if (streamInfo == null) {
        print('❌ No muxed MP4 stream found for $youtubeUrl');
        return null;
      }

      final directUrl = streamInfo.url.toString();
      print('🎥 YouTube direct stream URL: $directUrl');

      // Use your existing DownloadManager to download as .mp4
      final localPath = await DownloadManager.download(
        directUrl,
        name: fileName ?? 'yt_${video.id}.mp4',
        onDownload: onProgress,
        isOpen: false,
      );

      return localPath;
    } catch (e) {
      print('❌ Error downloading YouTube video: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _yt.close();
  }
}
