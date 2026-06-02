import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../widgets/home/app_drawer.dart';
import 'scan_to_pdf_screen.dart';
import 'pdf_organizer_screen.dart';
import 'pdf_compress_screen.dart';
import 'pdf_split_screen.dart';
import 'gpa_calculator_screen.dart';
import 'my_pdfs_screen.dart';

/// Landing page for student utility tools. Currently hosts the
/// "Scan & Make PDF" tool and "My PDFs" history; built to grow over time.
class ToolsHubScreen extends StatefulWidget {
  const ToolsHubScreen({super.key});

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> {
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ChangeNotifierProvider(
      create: (_) => _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _zoomDrawerController.toggle(),
            ),
            title: const Text('Tools'),
            centerTitle: true,
          ),
          body: _buildBody(colors),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Student Tools',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Handy utilities to help with your studies.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.15,
          children: [
            _ToolCard(
              icon: Icons.document_scanner_rounded,
              title: 'Scan & Make PDF',
              subtitle: 'Camera or gallery → PDF',
              gradient: [colors.primary, colors.primaryLight],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanToPdfScreen()),
              ),
            ),
            _ToolCard(
              icon: Icons.reorder_rounded,
              title: 'Organize PDF',
              subtitle: 'Reorder / delete pages',
              gradient: [colors.accent, colors.accentLight],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfOrganizerScreen()),
              ),
            ),
            _ToolCard(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              subtitle: 'Make the file smaller',
              gradient: [colors.warning, colors.error],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfCompressScreen()),
              ),
            ),
            _ToolCard(
              icon: Icons.call_split_rounded,
              title: 'Split PDF',
              subtitle: 'By parts or by size',
              gradient: [colors.info, colors.primaryLight],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfSplitScreen()),
              ),
            ),
            _ToolCard(
              icon: Icons.calculate_rounded,
              title: 'GPA Calculator',
              subtitle: 'Out of 4.0, 5.0, 10.0',
              gradient: [colors.success, colors.accent],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GpaCalculatorScreen()),
              ),
            ),
            _ToolCard(
              icon: Icons.folder_copy_rounded,
              title: 'My PDFs',
              subtitle: 'Your created files',
              gradient: [colors.primaryDark, colors.primary],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPdfsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: colors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'More tools coming soon.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? colors.border : colors.border.withValues(alpha: 0.7),
        ),
        boxShadow: [
          // Crisp drop shadow toward the bottom-right for a tactile, designed feel.
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFF1E293B).withValues(alpha: 0.18),
            blurRadius: 9,
            offset: const Offset(4, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.last.withValues(alpha: 0.35),
                        blurRadius: 7,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 23),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -0.2,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
