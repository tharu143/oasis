import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/services/role_helper.dart';

// Module list imports for routing
import 'package:oasis/features/quotation/presentation/screens/quotation_list_screen.dart';
import 'package:oasis/features/sales_order/presentation/screens/sales_order_list_screen.dart';
import 'package:oasis/features/delivery_note/presentation/screens/delivery_note_list_screen.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_list_screen.dart';
import 'package:oasis/features/purchase_order/presentation/screens/purchase_order_list_screen.dart';
import 'package:oasis/features/material_request/presentation/screens/material_request_list_screen.dart';
import 'package:oasis/features/journal_entry/presentation/screens/journal_entry_list_screen.dart';
import 'package:oasis/features/payment_entry/presentation/screens/payment_entry_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _userName = 'User';
  List<String> _userRoles = [];
  RoleInfo _roleInfo = RoleInfo(
    roles: [],
    actionState: 'Draft',
    actionLabel: 'Pending Review',
    actionSubtitle: 'These drafts need to be sent for review.',
    actionColor: AppColors.primary,
    actionIcon: Icons.rate_review_rounded,
  );

  // Action Required counts per module — fetched from backend
  Map<String, int> _actionCounts = {};
  bool _loadingActions = false;

  final ApiClient _apiClient = ApiClient();

  // ─── Role detection delegated to RoleHelper ───────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('roles') ?? [];
    final roleInfo = await RoleHelper.getRoleInfoFromPrefs();
    setState(() {
      _userName = prefs.getString('full_name') ?? 'User';
      _userRoles = roles;
      _roleInfo = roleInfo;
    });
    // Fetch action-required counts after roles are loaded
    _fetchActionCounts();
  }

  // ─── Fetch pending counts for all modules ────────────────────────────────

  Future<void> _fetchActionCounts() async {
    setState(() => _loadingActions = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.dashboard.get_action_required_counts',
        params: {'workflow_state': _roleInfo.actionState},
      );
      final data = response['message'] ?? response['data'] ?? {};
      if (data is Map) {
        final Map<String, int> counts = {};
        data.forEach((key, value) {
          counts[key.toString()] = (value as num? ?? 0).toInt();
        });
        setState(() {
          _actionCounts = counts;
          _loadingActions = false;
        });
      } else {
        setState(() => _loadingActions = false);
      }
    } catch (_) {
      setState(() => _loadingActions = false);
    }
  }

  int get _totalActionCount =>
      _actionCounts.values.fold(0, (sum, v) => sum + v);

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sid');
      await prefs.remove('full_name');
      await prefs.remove('roles');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsBanner(),
                    const SizedBox(height: 24),
                    _buildActionRequiredSection(),
                    const SizedBox(height: 32),
                    _buildModulesGrid(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _getGreetingIcon(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 16);
    }
    if (hour < 17) {
      return const Icon(Icons.wb_cloudy_rounded, color: Colors.blue, size: 16);
    }
    return const Icon(Icons.nightlight_round, color: Colors.indigo, size: 16);
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        _buildActionIcon(
          Icons.refresh_rounded,
          AppColors.primary,
          () {
            _fetchActionCounts();
          },
        ),
        const SizedBox(width: 12),
        _buildActionIcon(
          Icons.logout_rounded,
          Colors.redAccent,
          _logout,
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=oasis'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ─── Stats Banner ─────────────────────────────────────────────────────────

  Widget _buildStatsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oasis Dashboard',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor your business\nperformance in real-time.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Active Session',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Action Required Section ──────────────────────────────────────────────

  Widget _buildActionRequiredSection() {
    if (_loadingActions) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Text(
              'Checking your action items...',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_totalActionCount == 0) return const SizedBox.shrink();

    final color = _roleInfo.actionColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ACTION REQUIRED',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_totalActionCount',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_roleInfo.actionIcon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleInfo.actionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _roleInfo.actionSubtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Per-module action cards
        ..._buildModuleActionCards(color),
      ],
    );
  }

  List<Widget> _buildModuleActionCards(Color color) {
    final modules = _moduleList();
    final List<Widget> cards = [];

    for (final m in modules) {
      final count = _actionCounts[m['key'] as String] ?? 0;
      if (count == 0) continue;

      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildModuleActionTile(
            title: m['title'] as String,
            count: count,
            icon: m['icon'] as IconData,
            color: color,
            onTap: () => _navigateToModuleList(m['key'] as String),
          ),
        ),
      );
    }
    return cards;
  }

  Widget _buildModuleActionTile({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Count badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count pending',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  // ─── Navigation per module ────────────────────────────────────────────────

  void _navigateToModuleList(String moduleKey) {
    // Note: Quotation/SO/DN/SI/PO use `filterStatus`; MR/JE/PE use `initialState`
    final state = _roleInfo.actionState;
    Widget screen;
    switch (moduleKey) {
      case 'quotation':
        screen = QuotationListScreen(filterStatus: state);
        break;
      case 'sales_order':
        screen = SalesOrderListScreen(filterStatus: state);
        break;
      case 'delivery_note':
        screen = DeliveryNoteListScreen(filterStatus: state);
        break;
      case 'sales_invoice':
        screen = SalesInvoiceListScreen(filterStatus: state);
        break;
      case 'purchase_order':
        screen = PurchaseOrderListScreen(filterStatus: state);
        break;
      case 'material_request':
        screen = MaterialRequestListScreen(initialState: state);
        break;
      case 'journal_entry':
        screen = JournalEntryListScreen(initialState: state);
        break;
      case 'payment_entry':
        screen = PaymentEntryListScreen(initialState: state);
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _fetchActionCounts());
  }

  // ─── Module definitions ───────────────────────────────────────────────────

  List<Map<String, dynamic>> _moduleList() => [
        {
          'key': 'quotation',
          'title': 'Quotation',
          'icon': Icons.request_quote_rounded,
          'color': AppColors.primary,
        },
        {
          'key': 'sales_order',
          'title': 'Sales Order',
          'icon': Icons.shopping_cart_rounded,
          'color': const Color(0xFF10B981),
        },
        {
          'key': 'delivery_note',
          'title': 'Delivery Note',
          'icon': Icons.local_shipping_rounded,
          'color': const Color(0xFF8B5CF6),
        },
        {
          'key': 'sales_invoice',
          'title': 'Sales Invoice',
          'icon': Icons.receipt_long_rounded,
          'color': const Color(0xFF6366F1),
        },
        {
          'key': 'purchase_order',
          'title': 'Purchase Order',
          'icon': Icons.shopping_bag_rounded,
          'color': const Color(0xFFF59E0B),
        },
        {
          'key': 'material_request',
          'title': 'Material Request',
          'icon': Icons.inventory_2_rounded,
          'color': const Color(0xFF06B6D4),
        },
        {
          'key': 'journal_entry',
          'title': 'Journal Entry',
          'icon': Icons.account_balance_wallet_rounded,
          'color': const Color(0xFFEC4899),
        },
        {
          'key': 'payment_entry',
          'title': 'Payment Entry',
          'icon': Icons.payments_rounded,
          'color': const Color(0xFFF43F5E),
        },
      ];

  // ─── Modules Grid ─────────────────────────────────────────────────────────

  Widget _buildModulesGrid() {
    final modules = _moduleList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUSINESS MODULES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textLight,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Explore',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 125,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final m = modules[index];
            final key = m['key'] as String;
            final count = _actionCounts[key] ?? 0;
            return _buildModuleCard(
              m['title'] as String,
              m['icon'] as IconData,
              m['color'] as Color,
              count,
              () => _navigateToModule(key),
            );
          },
        ),
      ],
    );
  }

  void _navigateToModule(String key) {
    switch (key) {
      case 'quotation':
        Navigator.pushNamed(context, '/quotation-dashboard');
        break;
      case 'sales_order':
        Navigator.pushNamed(context, '/sales-order-dashboard');
        break;
      case 'delivery_note':
        Navigator.pushNamed(context, '/delivery-note-dashboard');
        break;
      case 'sales_invoice':
        Navigator.pushNamed(context, '/sales-invoice-dashboard');
        break;
      case 'purchase_order':
        Navigator.pushNamed(context, '/purchase-order-dashboard');
        break;
      case 'material_request':
        Navigator.pushNamed(context, '/material-request-dashboard');
        break;
      case 'journal_entry':
        Navigator.pushNamed(context, '/journal-entry-dashboard');
        break;
      case 'payment_entry':
        Navigator.pushNamed(context, '/payment-entry-dashboard');
        break;
    }
  }

  Widget _buildModuleCard(
    String title,
    IconData icon,
    Color color,
    int pendingCount,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.15),
                          color.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Pending badge on module card
            if (pendingCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleInfo.actionColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
