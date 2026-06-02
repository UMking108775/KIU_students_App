import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/category_service.dart';
import '../../services/content_service.dart';
import '../../services/help_service.dart';

/// Loading screen that prefetches all data after login
/// Shows "Fetching all content please wait" message
class DataLoadingScreen extends StatefulWidget {
  const DataLoadingScreen({super.key});

  @override
  State<DataLoadingScreen> createState() => _DataLoadingScreenState();
}

class _DataLoadingScreenState extends State<DataLoadingScreen> {
  final CategoryService _categoryService = CategoryService();
  final ContentService _contentService = ContentService();
  final CacheService _cacheService = CacheService();
  final HelpService _helpService = HelpService(apiService: ApiService());

  String _statusMessage = 'Initializing...';
  double _progress = 0;
  int _totalItems = 0;
  int _loadedItems = 0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefetchAllData();
  }

  Future<void> _prefetchAllData() async {
    try {
      setState(() {
        _statusMessage = 'Fetching main categories...';
        _progress = 0.05;
      });

      // Step 1: Fetch main categories
      final mainCategoriesResponse = await _categoryService.getMainCategories(
        forceRefresh: true,
      );

      if (!mainCategoriesResponse.success ||
          mainCategoriesResponse.data == null) {
        throw Exception(mainCategoriesResponse.message);
      }

      final mainCategories = mainCategoriesResponse.data!;

      setState(() {
        _statusMessage = 'Main categories: ${mainCategories.length}';
        _progress = 0.1;
      });

      // Step 2: Fetch subcategories for each main category
      List<dynamic> allSubcategories = [];
      for (int i = 0; i < mainCategories.length; i++) {
        final mainCat = mainCategories[i];

        setState(() {
          _statusMessage = 'Loading: ${mainCat.title}';
          _progress = 0.1 + (0.3 * (i / mainCategories.length));
        });

        final subResponse = await _categoryService.getSubcategories(mainCat.id);
        if (subResponse.success && subResponse.data != null) {
          allSubcategories.addAll(subResponse.data!);

          // Also fetch 3rd level categories
          for (final subCat in subResponse.data!) {
            final thirdLevelResponse = await _categoryService.getSubcategories(
              subCat.id,
            );
            if (thirdLevelResponse.success && thirdLevelResponse.data != null) {
              allSubcategories.addAll(thirdLevelResponse.data!);
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 30));
      }

      setState(() {
        _statusMessage = 'Loading materials...';
        _progress = 0.4;
      });

      // Step 3: Fetch content for all categories (main + sub + 3rd level)
      final allCategoriesForContent = [...mainCategories, ...allSubcategories];
      _totalItems = allCategoriesForContent.length;

      for (int i = 0; i < allCategoriesForContent.length; i++) {
        final category = allCategoriesForContent[i];

        setState(() {
          _loadedItems = i + 1;
          _statusMessage = 'Content: ${category.title}';
          _progress = 0.4 + (0.5 * (_loadedItems / _totalItems));
        });

        // Fetch content for this category
        await _contentService.getContentsByCategory(
          category.id,
          forceRefresh: true,
        );

        await Future.delayed(const Duration(milliseconds: 30));
      }

      setState(() {
        _statusMessage = 'Loading FAQs...';
        _progress = 0.93;
      });

      // Step 4: Prefetch FAQs
      await _helpService.getFaqs(forceRefresh: true);

      setState(() {
        _statusMessage = 'Almost done...';
        _progress = 0.97;
      });

      // Update last sync time
      await _cacheService.updateLastSyncTime();

      setState(() {
        _statusMessage = 'Ready!';
        _progress = 1.0;
      });

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to home
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = 'Error loading data';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/kiu_logo.png',
                    height: 80,
                    width: 80,
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Loading Your Content',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Please wait while we prepare everything for you',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Progress indicator
                if (!_hasError) ...[
                  SizedBox(
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status message
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  if (_totalItems > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_loadedItems / $_totalItems',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],

                // Error state
                if (_hasError) ...[
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Something went wrong',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _errorMessage = null;
                          });
                          _prefetchAllData();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Skip prefetch and go to home anyway
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        },
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
