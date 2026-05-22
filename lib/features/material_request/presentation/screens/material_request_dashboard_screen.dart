import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'material_request_list_screen.dart';
import 'material_request_form_screen.dart';

class MaterialRequestDashboardScreen extends StatefulWidget {
  const MaterialRequestDashboardScreen({super.key});

  @override
  State<MaterialRequestDashboardScreen> createState() => _MaterialRequestDashboardScreenState();
}

class _MaterialRequestDashboardScreenState extends State<MaterialRequestDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  String _userName = 'Team';
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchDashboardData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('full_name') ?? 'Team';
      if (_userName.contains(' ')) {
        _userName = _userName.split(' ')[0];
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('oasis_mobile.api.material_request.get_material_request_dashboard');
      debugPrint('MR API Response: $response');
      setState(() {
        _dashboardData = response['message'] ?? response['data'] ?? response;
        debugPrint('MR _dashboardData: $_dashboardData');
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 100),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildWelcomeHeader(),
                        const SizedBox(height: 24),
                        _buildActionRequiredCard(),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Requests Overview',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Real-time',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildStatsGrid(),
                        const SizedBox(height: 40),
                        _buildQuickActions(),
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCustomFAB(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Text(
          'Material Request Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        background: Container(color: const Color(0xFFF8FAFC)),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '$_userName 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRequiredCard() {
    final int actionRequired = _dashboardData['action_required'] ?? 0;
    if (actionRequired == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.feedback_rounded, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You have $actionRequired material requests waiting for review or approval.',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.blue[850],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            color: Colors.blue[900],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaterialRequestListScreen(initialState: 'Pending'),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = (_dashboardData['data'] is Map)
        ? Map<String, dynamic>.from(_dashboardData['data'])
        : _dashboardData;
    debugPrint('MR stats map: $stats');
    
    // Extracted counts
    final draftVal = stats['Draft'] ?? 0;
    final pendingVal = stats['Pending'] ?? 0;
    final verifiedVal = stats['Verified By Finance Team'] ?? 0;
    final rejectedFinanceVal = stats['Rejected By Finance Team'] ?? 0;
    final rejectedMdVal = stats['Rejected By MD'] ?? 0;
    final approvedVal = stats['Approved By MD'] ?? stats['Submitted'] ?? 0;
    final submittedVal = stats['Submitted'] ?? 0;
    
    final totalVal = stats['Total'] ?? (draftVal + pendingVal + verifiedVal + rejectedFinanceVal + rejectedMdVal + approvedVal);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Draft', draftVal, AppColors.draft, Icons.mode_edit_rounded),
        _buildStatCard('Pending', pendingVal, AppColors.pendingFinance, Icons.hourglass_empty_rounded),
        _buildStatCard('Verified', verifiedVal, AppColors.verifiedFinance, Icons.verified_user_rounded),
        _buildStatCard('Rejected', rejectedFinanceVal + rejectedMdVal, AppColors.rejectedMD, Icons.cancel_rounded),
        _buildStatCard('Approved / Submitted', approvedVal + submittedVal, AppColors.approvedMD, Icons.check_circle_rounded),
        _buildStatCard('Total Requests', totalVal, AppColors.primary, Icons.folder_rounded),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    String stateFilter = title;
    if (title.contains('Approved')) stateFilter = 'Approved By MD';
    if (title.contains('Total')) stateFilter = '';
    if (title == 'Rejected') stateFilter = 'Rejected By Finance Team';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialRequestListScreen(initialState: stateFilter),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  count.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                'New Request',
                Icons.add_shopping_cart_rounded,
                AppColors.primary,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaterialRequestFormScreen()),
                ).then((_) => _fetchDashboardData()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionBtn(
                'All Requests',
                Icons.list_alt_rounded,
                AppColors.accent,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaterialRequestListScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaterialRequestFormScreen()),
        ).then((_) => _fetchDashboardData());
      },
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Create Request',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
