import 'dart:developer';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/services/download_manager.dart';
import '../models/download_model.dart';
import '../services/token_storage_service.dart';

class VideoDownloadService {
  static final VideoDownloadService _instance =
      VideoDownloadService._internal();
  factory VideoDownloadService() => _instance;
  VideoDownloadService._internal();

  static Database? _database;
  static const String _tableName = 'downloaded_videos';

  // Initialize the download service
  Future<void> initialize() async {
    await _initializeDatabase();
  }

  String _sanitizeFileName(String input) {
    var sanitized = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) return 'video';
    // اختصار الاسم الطويل جداً
    if (sanitized.length > 60) {
      sanitized = sanitized.substring(0, 60);
    }
    return sanitized;
  }

  // Initialize local database for downloaded videos
  Future<void> _initializeDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'downloaded_videos.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          '''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            lesson_id TEXT,
            course_id TEXT,
            course_title TEXT,
            title TEXT,
            description TEXT,
            video_url TEXT,
            local_path TEXT,
            file_size INTEGER,
            file_size_mb REAL,
            file_type TEXT,
            duration INTEGER,
            duration_text TEXT,
            video_source TEXT,
            downloaded_at TEXT,
            thumbnail_path TEXT
          )
          ''',
        );
      },
    );
  }

  // Request storage permission
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          // Android 13+
          final videoStatus = await Permission.videos.status;
          final audioStatus = await Permission.audio.status;
          final photoStatus = await Permission.photos.status;

          if (videoStatus == PermissionStatus.granted ||
              audioStatus == PermissionStatus.granted ||
              photoStatus == PermissionStatus.granted) {
            return true;
          }

          final videoStatusAfter = await Permission.videos.request();
          final audioStatusAfter = await Permission.audio.request();
          final photoStatusAfter = await Permission.photos.request();

          return videoStatusAfter == PermissionStatus.granted ||
              audioStatusAfter == PermissionStatus.granted ||
              photoStatusAfter == PermissionStatus.granted;
        } else if (sdkInt >= 30) {
          // Android 11-12
          final manageStorageStatus =
              await Permission.manageExternalStorage.status;
          if (manageStorageStatus == PermissionStatus.granted) {
            return true;
          }

          final storageStatus = await Permission.storage.status;
          if (storageStatus == PermissionStatus.granted) {
            return true;
          }

          final manageStorageStatusAfter =
              await Permission.manageExternalStorage.request();
          if (manageStorageStatusAfter == PermissionStatus.granted) {
            return true;
          }

          final storageStatusAfter = await Permission.storage.request();
          return storageStatusAfter == PermissionStatus.granted;
        } else {
          // Android 10 and below
          final storageStatus = await Permission.storage.status;
          if (storageStatus == PermissionStatus.granted) {
            return true;
          }

          final storageStatusAfter = await Permission.storage.request();
          return storageStatusAfter == PermissionStatus.granted;
        }
      }
      return true; // iOS doesn't need explicit permission for app documents
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  // Check current permission status
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        final videoStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;
        final photoStatus = await Permission.photos.status;

        return videoStatus == PermissionStatus.granted ||
            audioStatus == PermissionStatus.granted ||
            photoStatus == PermissionStatus.granted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12
        final manageStorageStatus =
            await Permission.manageExternalStorage.status;
        if (manageStorageStatus == PermissionStatus.granted) {
          return true;
        }

        final storageStatus = await Permission.storage.status;
        return storageStatus == PermissionStatus.granted;
      } else {
        // Android 10 and below
        final storageStatus = await Permission.storage.status;
        return storageStatus == PermissionStatus.granted;
      }
    }
    return true; // iOS doesn't need explicit permission for app documents
  }

  /// تحميل فيديو باستخدام DownloadManager
  Future<String?> downloadVideoWithManager({
    required String videoUrl,
    required String lessonId,
    required String courseId,
    required String title,
    String? courseTitle,
    String? description,
    double? fileSizeMb,
    String? durationText,
    String? videoSource,
    Function(int progress)? onProgress,
  }) async {
    try {
      print('🎬 Starting video download with DownloadManager');
      print('Video URL: $videoUrl');
      print('Lesson ID: $lessonId');

      // الحصول على token للمصادقة
      final token = await TokenStorageService.instance.getAccessToken();

      // إنشاء اسم ملف فريد يعتمد على اسم الكورس واسم الدرس
      final safeCourseTitle =
          _sanitizeFileName(courseTitle ?? 'course_$courseId');
      final safeLessonTitle = _sanitizeFileName(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${safeCourseTitle}_${safeLessonTitle}_$timestamp.mp4';

      // تحميل الفيديو باستخدام DownloadManager
      String? localPath = await DownloadManager.download(
        videoUrl,
        name: fileName,
        onDownload: (progress) {
          print('Download progress: $progress%');
          // استدعاء callback التقدم إذا كان موجوداً
          if (onProgress != null) {
            onProgress(progress);
          }
        },
        isOpen: false,
        authToken: token,
      );

      if (localPath != null) {
        log(localPath);
        //print('✅ Video downloaded successfully to: $localPath');

        // حفظ معلومات الفيديو في قاعدة البيانات
        String videoId = DateTime.now().millisecondsSinceEpoch.toString();

        await _database?.insert(
          _tableName,
          {
            'id': videoId,
            'lesson_id': lessonId,
            'course_id': courseId,
            'course_title': courseTitle ?? 'كورس $courseId',
            'title': title,
            'description': description ?? '',
            'video_url': videoUrl,
            'local_path': localPath,
            'file_size': 0, // سيتم حسابه لاحقاً
            'file_size_mb': fileSizeMb ?? 0.0,
            'file_type': 'video/mp4',
            'duration': 0,
            'duration_text': durationText ?? '',
            'video_source': videoSource ?? 'server',
            'downloaded_at': DateTime.now().toIso8601String(),
            'thumbnail_path': '',
          },
        );

        print('✅ Video info saved to database');
        return videoId;
      } else {
        print('❌ Video download failed');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading video with DownloadManager: $e');
      return null;
    }
  }

  /// حفظ فيديو تم تحميله مسبقاً (مثلاً من YouTube) في قاعدة البيانات
  Future<String?> saveDownloadedVideoRecord({
    required String lessonId,
    required String courseId,
    required String title,
    required String videoUrl,
    required String localPath,
    String? courseTitle,
    String? description,
    double? fileSizeMb,
    String? durationText,
    String videoSource = 'server',
  }) async {
    try {
      if (_database == null) {
        await _initializeDatabase();
      }

      final videoId = DateTime.now().millisecondsSinceEpoch.toString();

      await _database?.insert(
        _tableName,
        {
          'id': videoId,
          'lesson_id': lessonId,
          'course_id': courseId,
          'course_title': courseTitle ?? 'كورس $courseId',
          'title': title,
          'description': description ?? '',
          'video_url': videoUrl,
          'local_path': localPath,
          'file_size': 0,
          'file_size_mb': fileSizeMb ?? 0.0,
          'file_type': 'video/mp4',
          'duration': 0,
          'duration_text': durationText ?? '',
          'video_source': videoSource,
          'downloaded_at': DateTime.now().toIso8601String(),
          'thumbnail_path': '',
        },
      );

      print('✅ External video info saved to database (source: $videoSource)');
      return videoId;
    } catch (e) {
      print('❌ Error saving downloaded video record: $e');
      return null;
    }
  }

  /// Register an assignment PDF saved under app storage so it appears on [DownloadsScreen].
  Future<String?> registerAssignmentPdfDownload({
    required String assignmentId,
    required String courseId,
    required String title,
    required String sourceUrl,
    required String localPath,
    String? courseTitle,
  }) async {
    try {
      if (_database == null) {
        await _initializeDatabase();
      }

      await _database?.delete(
        _tableName,
        where: 'lesson_id = ? AND video_source = ?',
        whereArgs: [assignmentId, 'assignment_pdf'],
      );

      final file = File(localPath);
      if (!await file.exists()) {
        print('❌ registerAssignmentPdfDownload: file missing at $localPath');
        return null;
      }

      final fileSize = await file.length();
      final fileSizeMb = fileSize / (1024 * 1024);
      final id =
          'assign_pdf_${assignmentId}_${DateTime.now().millisecondsSinceEpoch}';

      await _database?.insert(
        _tableName,
        {
          'id': id,
          'lesson_id': assignmentId,
          'course_id': courseId,
          'course_title': courseTitle ?? '',
          'title': title,
          'description': '',
          'video_url': sourceUrl,
          'local_path': localPath,
          'file_size': fileSize,
          'file_size_mb': fileSizeMb,
          'file_type': 'application/pdf',
          'duration': 0,
          'duration_text': '',
          'video_source': 'assignment_pdf',
          'downloaded_at': DateTime.now().toIso8601String(),
          'thumbnail_path': '',
        },
      );

      print('✅ Assignment PDF registered in downloads DB: $id');
      return id;
    } catch (e) {
      print('❌ registerAssignmentPdfDownload: $e');
      return null;
    }
  }

  /// الحصول على معلومات التحميل من API
  Future<DownloadData?> getDownloadInfo(String lessonId) async {
    try {
      // TODO: إضافة endpoint للتحميل في API إذا كان موجوداً
      // حالياً سنستخدم lesson content للحصول على معلومات الفيديو
      // يمكن تعديل هذا لاحقاً إذا كان هناك endpoint مخصص للتحميل

      // يمكن إضافة endpoint مثل: ApiEndpoints.downloadLesson(lessonId)
      return null;
    } catch (e) {
      print('❌ Error getting download info: $e');
      return null;
    }
  }

  /// التحقق من وجود ملف محمل مسبقاً
  Future<String?> checkLocalVideoFile(String lessonId) async {
    // البحث في قاعدة البيانات أولاً
    final result = await _database?.query(
      _tableName,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );

    if (result?.isNotEmpty ?? false) {
      final localPath = result!.first['local_path'] as String;

      // التحقق من وجود الملف فعلياً
      final file = File(localPath);
      if (await file.exists()) {
        print('✅ Local video file exists: $localPath');
        return localPath;
      } else {
        print('🚫 Local video file not found, cleaning database entry');
        // حذف السجل من قاعدة البيانات إذا كان الملف غير موجود
        await _database?.delete(
          _tableName,
          where: 'lesson_id = ?',
          whereArgs: [lessonId],
        );
      }
    }

    return null;
  }

  /// الحصول على جميع الفيديوهات المحملة
  Future<List<DownloadedVideoModel>> getDownloadedVideosWithManager() async {
    try {
      print('Getting downloaded videos from database...');

      if (_database == null) {
        await _initializeDatabase();
      }

      final results = await _database?.query(_tableName);

      if (results == null || results.isEmpty) {
        print('No downloaded videos found in database');
        return [];
      }

      print('Found ${results.length} videos in database');

      List<DownloadedVideoModel> videos = [];

      for (final row in results) {
        final localPath = row['local_path'] as String;
        final file = File(localPath);

        // التحقق من وجود الملف
        if (await file.exists()) {
          print('✅ Video file exists: $localPath');

          // حساب حجم الملف الفعلي
          int fileSize = await file.length();
          double fileSizeMb = fileSize / (1024 * 1024);

          videos.add(DownloadedVideoModel(
            id: row['id'] as String,
            lessonId: row['lesson_id'] as String,
            courseId: row['course_id'] as String,
            courseTitle:
                row['course_title'] as String? ?? 'كورس ${row['course_id']}',
            title: row['title'] as String,
            description: row['description'] as String,
            videoUrl: row['video_url'] as String,
            localPath: localPath,
            fileSize: fileSize,
            fileSizeMb: fileSizeMb,
            fileType: row['file_type'] as String,
            duration: row['duration'] as int,
            durationText: row['duration_text'] as String,
            videoSource: row['video_source'] as String,
            downloadedAt: DateTime.parse(row['downloaded_at'] as String),
            thumbnailPath: row['thumbnail_path'] as String? ?? '',
          ));
        } else {
          print('🚫 Video file not found, removing from database: $localPath');
          // حذف السجل إذا كان الملف غير موجود
          await _database?.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      print('Returning ${videos.length} valid videos');
      return videos;
    } catch (e) {
      print('Error getting downloaded videos: $e');
      return [];
    }
  }

  /// حذف فيديو محمل
  Future<bool> deleteDownloadedVideo(String videoId) async {
    try {
      // الحصول على معلومات الفيديو من قاعدة البيانات
      final result = await _database?.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
        limit: 1,
      );

      if (result?.isNotEmpty ?? false) {
        final localPath = result!.first['local_path'] as String;
        final fileName = localPath.split('/').last;

        // حذف الملف من التخزين
        await DownloadManager.deleteFile(fileName);

        // حذف السجل من قاعدة البيانات
        await _database?.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [videoId],
        );

        print('✅ Video deleted successfully');
        return true;
      } else {
        print('🚫 Video not found in database');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting video: $e');
      return false;
    }
  }

  /// التحقق من أن الفيديو محمل
  Future<bool> isVideoDownloaded(String lessonId) async {
    final result = await _database?.query(
      _tableName,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );

    if (result?.isNotEmpty ?? false) {
      final localPath = result!.first['local_path'] as String;
      final file = File(localPath);
      return await file.exists();
    }

    return false;
  }
}
