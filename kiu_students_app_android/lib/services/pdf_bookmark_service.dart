import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a PDF bookmark
class PdfBookmark {
  final String contentId;
  final String userKiuId; // Added for multi-user support
  final int pageNumber;
  final String? note;
  final DateTime createdAt;

  PdfBookmark({
    required this.contentId,
    required this.userKiuId,
    required this.pageNumber,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'userKiuId': userKiuId,
    'pageNumber': pageNumber,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PdfBookmark.fromJson(Map<String, dynamic> json) => PdfBookmark(
    contentId: json['contentId'],
    userKiuId: json['userKiuId'] ?? '', // Backward compatibility
    pageNumber: json['pageNumber'],
    note: json['note'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

/// Service for managing PDF bookmarks
/// Now supports multi-user isolation via userKiuId
class PdfBookmarkService {
  static const String _bookmarksKey = 'pdf_bookmarks';

  /// Get all bookmarks for a PDF for a specific user
  Future<List<PdfBookmark>> getBookmarks(
    String contentId,
    String userKiuId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    if (data == null) return [];

    final List<dynamic> allBookmarks = json.decode(data);
    return allBookmarks
        .map((b) => PdfBookmark.fromJson(b))
        .where((b) => b.contentId == contentId && b.userKiuId == userKiuId)
        .toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  /// Add a bookmark (userKiuId is part of the PdfBookmark)
  Future<void> addBookmark(PdfBookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    List<dynamic> allBookmarks = data != null ? json.decode(data) : [];

    // Remove existing bookmark for same page by same user
    allBookmarks.removeWhere(
      (b) =>
          b['contentId'] == bookmark.contentId &&
          b['userKiuId'] == bookmark.userKiuId &&
          b['pageNumber'] == bookmark.pageNumber,
    );

    allBookmarks.add(bookmark.toJson());
    await prefs.setString(_bookmarksKey, json.encode(allBookmarks));
  }

  /// Remove a bookmark for a specific user
  Future<void> removeBookmark(
    String contentId,
    String userKiuId,
    int pageNumber,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    if (data == null) return;

    List<dynamic> allBookmarks = json.decode(data);
    allBookmarks.removeWhere(
      (b) =>
          b['contentId'] == contentId &&
          b['userKiuId'] == userKiuId &&
          b['pageNumber'] == pageNumber,
    );

    await prefs.setString(_bookmarksKey, json.encode(allBookmarks));
  }

  /// Check if a page is bookmarked by a specific user
  Future<bool> isBookmarked(
    String contentId,
    String userKiuId,
    int pageNumber,
  ) async {
    final bookmarks = await getBookmarks(contentId, userKiuId);
    return bookmarks.any((b) => b.pageNumber == pageNumber);
  }

  /// Get last read page for a PDF for a specific user
  Future<int> getLastReadPage(String contentId, String userKiuId) async {
    final prefs = await SharedPreferences.getInstance();
    // User-specific key
    return prefs.getInt('last_page_${userKiuId}_$contentId') ?? 1;
  }

  /// Save last read page for a PDF for a specific user
  Future<void> saveLastReadPage(
    String contentId,
    String userKiuId,
    int pageNumber,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // User-specific key
    await prefs.setInt('last_page_${userKiuId}_$contentId', pageNumber);
  }
}
