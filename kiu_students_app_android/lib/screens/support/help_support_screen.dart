import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../models/support_models.dart';
import '../../services/api_service.dart';
import '../../services/help_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../widgets/home/app_drawer.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();
  late TabController _tabController;
  late HelpService _helpService;
  final GlobalKey<_TicketsTabState> _ticketsTabKey =
      GlobalKey<_TicketsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _helpService = HelpService(
      apiService: ApiService(),
      storageService: StorageService(),
    );
  }

  @override
  void dispose() {
    _zoomDrawerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ChangeNotifierProvider.value(
      value: _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: AppBar(
              toolbarHeight: 48,
              leading: IconButton(
                icon: const Icon(Icons.menu, size: 22),
                onPressed: () => _zoomDrawerController.toggle(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              title: const Text(
                'Help & Support',
                style: TextStyle(fontSize: 16),
              ),
              centerTitle: true,
            ),
          ),
          body: Column(
            children: [
              // Custom TabBar with background color
              Container(
                color: colors.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.primary,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: const [
                    Tab(text: 'FAQs', height: 40),
                    Tab(text: 'My Tickets', height: 40),
                    Tab(text: 'Contact', height: 40),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FaqTab(helpService: _helpService),
                    _TicketsTab(key: _ticketsTabKey, helpService: _helpService),
                    _ContactTab(
                      helpService: _helpService,
                      onTicketSubmitted: () {
                        _ticketsTabKey.currentState?._loadTickets();
                        _tabController.animateTo(1); // Switch to My Tickets
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== FAQ TAB ==================
class _FaqTab extends StatefulWidget {
  final HelpService helpService;
  const _FaqTab({required this.helpService});

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> with AutomaticKeepAliveClientMixin {
  List<FaqModel> _faqs = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await widget.helpService.getFaqs();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success) {
          _faqs = response.data ?? [];
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.textSecondary)),
            TextButton(onPressed: _loadFaqs, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_faqs.isEmpty) {
      return const Center(child: Text('No FAQs available'));
    }
    return RefreshIndicator(
      onRefresh: _loadFaqs,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _faqs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: colors.primary,
                  ),
                ),
                title: Text(
                  faq.question,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                children: [
                  Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================== TICKETS TAB ==================
class _TicketsTab extends StatefulWidget {
  final HelpService helpService;
  const _TicketsTab({super.key, required this.helpService});

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab>
    with AutomaticKeepAliveClientMixin {
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadTickets(silent: true);
    });
  }

  Future<void> _loadTickets({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // Pass forceRefresh if this is a hard refresh (pull-to-refresh)
    final response = await widget.helpService.getMyTickets(
      forceRefresh: forceRefresh,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success) {
          _tickets = response.data ?? [];
        } else if (!silent) {
          // Only show error if not silent (don't disturb user for bg updates)
          _error = response.message;
        }
      });
    }
  }

  Color _getStatusColor(String status, ThemeColors colors) {
    switch (status.toLowerCase()) {
      case 'responded':
        return colors.success;
      case 'closed':
        return colors.textSecondary;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.textSecondary)),
            TextButton(onPressed: _loadTickets, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_chat_unread_outlined,
              size: 48,
              color: colors.textHint,
            ),
            const SizedBox(height: 8),
            Text(
              'No support tickets yet',
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadTickets(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _tickets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          final statusColor = _getStatusColor(ticket.status, colors);
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showTicketDetail(ticket),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ticket.statusDisplay,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (ticket.status.toLowerCase() == 'responded') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.support_agent,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Admin Responded',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: colors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(ticket.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textHint,
                          ),
                        ),
                        if (ticket.hasResponse) ...[
                          const Spacer(),
                          Icon(Icons.reply, size: 12, color: colors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Admin replied',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTicketDetail(SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

class _TicketDetailSheet extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketDetailSheet({required this.ticket});

  Color _getStatusColor(String status, ThemeColors colors) {
    switch (status.toLowerCase()) {
      case 'responded':
        return colors.success;
      case 'closed':
        return colors.textSecondary;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _getStatusColor(ticket.status, colors);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ticket.statusDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User message
                  _MessageBubble(
                    isAdmin: false,
                    message: ticket.message,
                    date: ticket.createdAt,
                  ),
                  const SizedBox(height: 12),
                  // Admin response
                  if (ticket.hasResponse)
                    _MessageBubble(
                      isAdmin: true,
                      message: ticket.adminResponse!,
                      date: ticket.respondedAt,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_empty,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Awaiting admin response...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isAdmin;
  final String message;
  final DateTime? date;

  const _MessageBubble({
    required this.isAdmin,
    required this.message,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdmin ? colors.primary.withValues(alpha: 0.1) : colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAdmin
              ? colors.primary.withValues(alpha: 0.3)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin ? colors.primary : colors.textSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAdmin ? 'Admin' : 'You',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (date != null) ...[
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date!),
                  style: TextStyle(fontSize: 10, color: colors.textHint),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ================== CONTACT TAB ==================
class _ContactTab extends StatefulWidget {
  final HelpService helpService;
  final VoidCallback? onTicketSubmitted;
  const _ContactTab({required this.helpService, this.onTicketSubmitted});

  @override
  State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final response = await widget.helpService.submitTicket(
      _subjectController.text.trim(),
      _messageController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: response.success
              ? AppColors.of(context).success
              : AppColors.of(context).error,
        ),
      );
      if (response.success) {
        _subjectController.clear();
        _messageController.clear();
        widget.onTicketSubmitted?.call();
      }
    }
  }

  Future<void> _contactWhatsApp() async {
    const phoneNumber = AppConfig.adminWhatsApp;
    // Use web URL which is more reliable across devices
    final webUri = Uri.parse(
      'https://wa.me/${phoneNumber.replaceAll("+", "")}',
    );
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WhatsApp Card - Compact
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF25D366), const Color(0xFF128C7E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Support',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Chat with us on WhatsApp',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _contactWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF128C7E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Submit Ticket Form
          Text(
            'Submit a Ticket',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'ll get back to you as soon as possible',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief description',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter a subject'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe your issue in detail',
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 4,
                  validator: (v) => (v == null || v.length < 10)
                      ? 'Min 10 characters required'
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
