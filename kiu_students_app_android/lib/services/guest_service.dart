/// Service to manage guest mode content restrictions
/// Guest users can only see limited content based on hierarchy levels
class GuestService {
  // Singleton pattern
  static final GuestService _instance = GuestService._internal();
  factory GuestService() => _instance;
  GuestService._internal();

  // Guest content limits
  static const int maxAudioFiles = 1;
  static const int maxPdfFiles = 1;

  // Category limits per level
  static const int level1Limit = 1; // Main Category
  static const int level2Limit = 2; // Sub Category
  static const int level3Limit = 1; // Sub-Sub Category

  /// Initialize is no longer needed for hardcoded logic
  Future<void> initialize() async {
    // No-op
  }

  /// Filter categories for guest mode based on their hierarchy level
  List<T> filterCategoriesForGuest<T>(List<T> categories) {
    if (categories.isEmpty) return [];

    // Determine limit based on level of first item
    int limit = 1; // Default
    try {
      final first = categories.first as dynamic;
      // Check if it has 'level' property
      if (first.level != null) {
        final int level = first.level;
        if (level == 1)
          limit = level1Limit;
        else if (level == 2)
          limit = level2Limit;
        else if (level >= 3)
          limit = level3Limit;
      }
    } catch (e) {
      // If casting fails or property missing, default to 1
      limit = 1;
    }

    return categories.take(limit).toList();
  }

  /// Filter content for guest mode - limit audio and PDF
  List<T> filterContentForGuest<T>(
    List<T> contents, {
    required String Function(T) getFileType,
  }) {
    if (contents.isEmpty) return [];

    int audioCount = 0;
    int pdfCount = 0;
    final filtered = <T>[];

    for (final content in contents) {
      final fileType = getFileType(content).toLowerCase();

      if (fileType.contains('audio') || fileType.contains('mp3')) {
        if (audioCount < maxAudioFiles) {
          filtered.add(content);
          audioCount++;
        }
      } else if (fileType.contains('pdf') || fileType.contains('document')) {
        if (pdfCount < maxPdfFiles) {
          filtered.add(content);
          pdfCount++;
        }
      }

      // Stop if we've reached both limits
      if (audioCount >= maxAudioFiles && pdfCount >= maxPdfFiles) {
        break;
      }
    }

    return filtered;
  }

  /// Check if content type is allowed for guest
  bool isContentTypeAllowedForGuest(String fileType) {
    final type = fileType.toLowerCase();
    return type.contains('audio') ||
        type.contains('mp3') ||
        type.contains('pdf') ||
        type.contains('document');
  }
}
