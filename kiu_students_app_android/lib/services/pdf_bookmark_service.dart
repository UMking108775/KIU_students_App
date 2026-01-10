import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a PDF bookmark
class PdfBookmark {
  final String contentId;
  final int pageNumber;
  final String? note;
  final DateTime createdAt;

  PdfBookmark({
    required this.contentId,
    required this.pageNumber,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'pageNumber': pageNumber,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PdfBookmark.fromJson(Map<String, dynamic> json) => PdfBookmark(
    contentId: json['contentId'],
    pageNumber: json['pageNumber'],
    note: json['note'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

/// Service for managing PDF bookmarks
class PdfBookmarkService {
  static const String _bookmarksKey = 'pdf_bookmarks';

  /// Get all bookmarks for a PDF
  Future<List<PdfBookmark>> getBookmarks(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    if (data == null) return [];

    final List<dynamic> allBookmarks = json.decode(data);
    return allBookmarks
        .map((b) => PdfBookmark.fromJson(b))
        .where((b) => b.contentId == contentId)
        .toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  /// Add a bookmark
  Future<void> addBookmark(PdfBookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    List<dynamic> allBookmarks = data != null ? json.decode(data) : [];

    // Remove existing bookmark for same page
    allBookmarks.removeWhere(
      (b) =>
          b['contentId'] == bookmark.contentId &&
          b['pageNumber'] == bookmark.pageNumber,
    );

    allBookmarks.add(bookmark.toJson());
    await prefs.setString(_bookmarksKey, json.encode(allBookmarks));
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String contentId, int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);

    if (data == null) return;

    List<dynamic> allBookmarks = json.decode(data);
    allBookmarks.removeWhere(
      (b) => b['contentId'] == contentId && b['pageNumber'] == pageNumber,
    );

    await prefs.setString(_bookmarksKey, json.encode(allBookmarks));
  }

  /// Check if a page is bookmarked
  Future<bool> isBookmarked(String contentId, int pageNumber) async {
    final bookmarks = await getBookmarks(contentId);
    return bookmarks.any((b) => b.pageNumber == pageNumber);
  }

  /// Get last read page for a PDF
  Future<int> getLastReadPage(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_page_$contentId') ?? 1;
  }

  /// Save last read page for a PDF
  Future<void> saveLastReadPage(String contentId, int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_$contentId', pageNumber);
  }
}
