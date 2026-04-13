class DownloadResponseModel {
  final bool success;
  final String message;
  final DownloadData data;

  const DownloadResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory DownloadResponseModel.fromJson(Map<String, dynamic> json) {
    return DownloadResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: DownloadData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.toJson(),
    };
  }
}

class DownloadData {
  final String lessonId;
  final String courseId;
  final String title;
  final String description;
  final String videoUrl;
  final int fileSize;
  final double fileSizeMb;
  final String fileType;
  final int duration;
  final String durationText;
  final bool downloadable;
  final String videoSource;
  final String downloadNote;

  const DownloadData({
    required this.lessonId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.fileSize = 0,
    this.fileSizeMb = 0.0,
    this.fileType = 'video/mp4',
    this.duration = 0,
    this.durationText = '',
    this.downloadable = true,
    required this.videoSource,
    this.downloadNote = '',
  });

  factory DownloadData.fromJson(Map<String, dynamic> json) {
    return DownloadData(
      lessonId: json['lesson_id']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      fileSize: json['file_size'] ?? 0,
      fileSizeMb: (json['file_size_mb'] ?? 0.0).toDouble(),
      fileType: json['file_type']?.toString() ?? 'video/mp4',
      duration: json['duration'] ?? 0,
      durationText: json['duration_text']?.toString() ?? '',
      downloadable: json['downloadable'] ?? true,
      videoSource: json['video_source']?.toString() ?? 'server',
      downloadNote: json['download_note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lesson_id': lessonId,
      'course_id': courseId,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'file_size': fileSize,
      'file_size_mb': fileSizeMb,
      'file_type': fileType,
      'duration': duration,
      'duration_text': durationText,
      'downloadable': downloadable,
      'video_source': videoSource,
      'download_note': downloadNote,
    };
  }
}

// Downloaded video model for local storage
class DownloadedVideoModel {
  final String id;
  final String lessonId;
  final String courseId;
  final String courseTitle;
  final String title;
  final String description;
  final String videoUrl;
  final String localPath;
  final int fileSize;
  final double fileSizeMb;
  final String fileType;
  final int duration;
  final String durationText;
  final String videoSource;
  final DateTime downloadedAt;
  final String thumbnailPath;

  const DownloadedVideoModel({
    required this.id,
    required this.lessonId,
    required this.courseId,
    required this.courseTitle,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.localPath,
    required this.fileSize,
    required this.fileSizeMb,
    required this.fileType,
    required this.duration,
    required this.durationText,
    required this.videoSource,
    required this.downloadedAt,
    required this.thumbnailPath,
  });

  factory DownloadedVideoModel.fromJson(Map<String, dynamic> json) {
    return DownloadedVideoModel(
      id: json['id']?.toString() ?? '',
      lessonId: json['lesson_id']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      courseTitle: json['course_title']?.toString() ?? 'كورس ${json['course_id']}',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      localPath: json['local_path']?.toString() ?? '',
      fileSize: json['file_size'] ?? 0,
      fileSizeMb: (json['file_size_mb'] ?? 0.0).toDouble(),
      fileType: json['file_type']?.toString() ?? 'video/mp4',
      duration: json['duration'] ?? 0,
      durationText: json['duration_text']?.toString() ?? '',
      videoSource: json['video_source']?.toString() ?? 'server',
      downloadedAt: json['downloaded_at'] != null
          ? DateTime.parse(json['downloaded_at'])
          : DateTime.now(),
      thumbnailPath: json['thumbnail_path']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'course_id': courseId,
      'course_title': courseTitle,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'local_path': localPath,
      'file_size': fileSize,
      'file_size_mb': fileSizeMb,
      'file_type': fileType,
      'duration': duration,
      'duration_text': durationText,
      'video_source': videoSource,
      'downloaded_at': downloadedAt.toIso8601String(),
      'thumbnail_path': thumbnailPath,
    };
  }
}








