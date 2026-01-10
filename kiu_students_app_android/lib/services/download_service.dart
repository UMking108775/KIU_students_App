import 'dart:convert';
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

  DownloadedItem({
    required this.contentId,
    required this.title,
    required this.contentType,
    required this.localPath,
    required this.originalUrl,
    required this.downloadedAt,
    this.fileSize = 0,
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
    };
  }

  factory DownloadedItem.fromContent(
    ContentModel content,
    String localPath,
    int fileSize,
  ) {
    return DownloadedItem(
      contentId: content.id,
      title: content.title,
      contentType: content.contentType,
      localPath: localPath,
      originalUrl: content.backblazeUrl,
      downloadedAt: DateTime.now(),
      fileSize: fileSize,
    );
  }
}

/// Service for managing downloaded files in app's private storage
class DownloadService {
  static const String _downloadedItemsKey = 'downloaded_items';

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all downloaded items
  Future<List<DownloadedItem>> getAllDownloads() async {
    await _init();
    final jsonStr = _prefs!.getString(_downloadedItemsKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((e) => DownloadedItem.fromJson(e)).toList();
  }

  /// Get downloaded audio files
  Future<List<DownloadedItem>> getDownloadedAudio() async {
    final all = await getAllDownloads();
    return all
        .where((item) => item.contentType.toLowerCase() == 'audio')
        .toList();
  }

  /// Get downloaded PDF files
  Future<List<DownloadedItem>> getDownloadedPDFs() async {
    final all = await getAllDownloads();
    return all
        .where((item) => item.contentType.toLowerCase() == 'pdf')
        .toList();
  }

  /// Check if content is downloaded
  Future<bool> isDownloaded(int contentId) async {
    final all = await getAllDownloads();
    return all.any((item) => item.contentId == contentId);
  }

  /// Get downloaded item by content ID
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

    // Remove existing if any
    all.removeWhere((i) => i.contentId == item.contentId);
    all.add(item);

    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }

  /// Remove download record
  Future<void> removeDownload(int contentId) async {
    await _init();
    final all = await getAllDownloads();
    all.removeWhere((i) => i.contentId == contentId);

    final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs!.setString(_downloadedItemsKey, jsonStr);
  }
}
