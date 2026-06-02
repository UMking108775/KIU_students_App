import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart';

/// Model for downloaded items
class DownloadedItem {
  final int contentId;
  final String title;
  final String contentType;
  final String localPath;
  final String originalUrl;
  final DateTime downloadedAt;
  final int fileSize;
  final String userKiuId; // KIU ID of user who downloaded this

  DownloadedItem({
    required this.contentId,
    required this.title,
    required this.contentType,
    required this.localPath,
    required this.originalUrl,
    required this.downloadedAt,
    this.fileSize = 0,
    required this.userKiuId,
  });

  factory DownloadedItem.fromJson(Map<String, dynamic> json) {
    return DownloadedItem(
      contentId: json['content_id'] as int,
      title: json['title'] as String,
      contentType: json['content_type'] as String,
      localPath: json['local_path'] as String,
      originalUrl: json['original_url'] as String,
      downloadedAt: DateTime.parse(json['downloaded_at'] as String),
      fileSize: json['file_size'] as int? ?? 0,
      userKiuId:
          json['user_kiu_id'] as String? ?? '', // Handle legacy downloads
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content_id': contentId,
      'title': title,
      'content_type': contentType,
      'local_path': localPath,
      'original_url': originalUrl,
      'downloaded_at': downloadedAt.toIso8601String(),
      'file_size': fileSize,
      'user_kiu_id': userKiuId,
    };
  }

  factory DownloadedItem.fromContent(
    ContentModel content,
    String localPath,
    int fileSize,
    String userKiuId,
  ) {
    return DownloadedItem(
      contentId: content.id,
      title: content.title,
      contentType: content.contentType,
      localPath: localPath,
      originalUrl: content.backblazeUrl,
      downloadedAt: DateTime.now(),
      fileSize: fileSize,
      userKiuId: userKiuId,
    );
  }
}

/// Service for managing downloaded files in app's private storage
/// Downloads are organized by user KIU ID for multi-account support
class DownloadService {
  static const String _downloadedItemsKey = 'downloaded_items';

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get base downloads directory
  Future<Directory> _getDownloadsBaseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/downloads');
  }

  /// Get download directory for a specific user (by KIU ID)
  Future<Directory> getUserDownloadDir(String kiuId) async {
    final baseDir = await _getDownloadsBaseDir();
    final userDir = Directory('${baseDir.path}/$kiuId');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    return userDir;
  }

  /// Get audio download directory for a specific user
  Future<Directory> getUserAudioDir(String kiuId) async {
    final userDir = await getUserDownloadDir(kiuId);
    final audioDir = Directory('${userDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Get PDF download directory for a specific user
  Future<Directory> getUserPdfDir(String kiuId) async {
    final userDir = await getUserDownloadDir(kiuId);
    final pdfDir = Directory('${userDir.path}/pdf');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Get all downloaded items (all users)
  Future<List<DownloadedItem>> getAllDownloads() async {
    await _init();
    final jsonStr = _prefs!.getString(_downloadedItemsKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((e) => DownloadedItem.fromJson(e)).toList();
  }

  /// Get downloaded audio files for a specific user (by KIU ID)
  Future<List<DownloadedItem>> getDownloadedAudioForUser(String kiuId) async {
    final all = await getAllDownloads();
    return all
        .where(
          (item) =>
              item.contentType.toLowerCase() == 'audio' &&
              item.userKiuId == kiuId,
        )
        .toList();
  }

  /// Get downloaded PDF files for a specific user (by KIU ID)
  Future<List<DownloadedItem>> getDownloadedPDFsForUser(String kiuId) async {
    final all = await getAllDownloads();
    return all
        .where(
          (item) =>
              item.contentType.toLowerCase() == 'pdf' &&
              item.userKiuId == kiuId,
        )
        .toList();
  }

  /// Get all downloads for a specific user (by KIU ID)
  Future<List<DownloadedItem>> getDownloadsForUser(String kiuId) async {
    final all = await getAllDownloads();
    return all.where((item) => item.userKiuId == kiuId).toList();
  }

  /// Check if content is downloaded by a specific user
  Future<bool> isDownloadedByUser(int contentId, String kiuId) async {
    final all = await getAllDownloads();
    return all.any(
      (item) => item.contentId == contentId && item.userKiuId == kiuId,
    );
  }

  /// Check if content is downloaded (by any user - for backward compatibility)
  Future<bool> isDownloaded(int contentId) async {
    final all = await getAllDownloads();
    return all.any((item) => item.contentId == contentId);
  }

  /// Get downloaded item by content ID for a specific user
  Future<DownloadedItem?> getDownloadedItemForUser(
    int contentId,
    String kiuId,
  ) async {
    final all = await getAllDownloads();
    try {
      return all.firstWhere(
        (item) => item.contentId == contentId && item.userKiuId == kiuId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get downloaded item by content ID (any user - for backward compatibility)
  Future<DownloadedItem?> getDownloadedItem(int contentId) async {
    final all = await getAllDownloads();
    try {
      return all.firstWhere((item) => item.contentId == contentId);
    } catch (_) {
      return null;
    }
  }

  /// Save download record
  Future<void> saveDownload(DownloadedItem item) async {
    await _init();
    final all = await getAllDownloads();

    // Remove existing if any (same content, same user)
    all.removeWhere(
      (i) => i.contentId == item.contentId && i.userKiuId == item.userKiuId,
    );
    all.add(item);

    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }

  /// Remove download record for a specific user
  Future<void> removeDownloadForUser(int contentId, String kiuId) async {
    await _init();
    final all = await getAllDownloads();

    // Find and delete the actual file
    final item = all
        .where((i) => i.contentId == contentId && i.userKiuId == kiuId)
        .firstOrNull;

    if (item != null) {
      try {
        final file = File(item.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    // Remove from records
    all.removeWhere((i) => i.contentId == contentId && i.userKiuId == kiuId);

    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }

  /// Remove download record (legacy - removes first match)
  Future<void> removeDownload(int contentId) async {
    await _init();
    final all = await getAllDownloads();
    all.removeWhere((i) => i.contentId == contentId);

    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }

  /// Clear all downloads for a specific user only
  Future<void> clearDownloadsForUser(String kiuId) async {
    await _init();

    // Get downloads for this user and delete files
    final userDownloads = await getDownloadsForUser(kiuId);
    for (final item in userDownloads) {
      try {
        final file = File(item.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore errors with individual files
      }
    }

    // Delete user's download directory
    try {
      final userDir = await getUserDownloadDir(kiuId);
      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore directory deletion errors
    }

    // Remove only this user's records from the list
    final all = await getAllDownloads();
    all.removeWhere((i) => i.userKiuId == kiuId);
    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }
}
