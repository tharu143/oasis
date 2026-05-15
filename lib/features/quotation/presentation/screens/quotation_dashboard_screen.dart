import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/quotation/presentation/screens/quotation_list_screen.dart';
import 'package:oasis/features/quotation/presentation/screens/quotation_form_screen.dart';

class QuotationDashboardScreen extends StatefulWidget {
  const QuotationDashboardScreen({super.key});

  @override
  State<QuotationDashboardScreen> createState() => _QuotationDashboardScreenState();
}

class _QuotationDashboardScreenState extends State<QuotationDashboardScreen> {
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
        _userName = _userName.split(' ')[0]; // Just use first name for a friendlier feel
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('oasis_mobile.api.quotation.get_quotation_dashboard');
      setState(() {
        _dashboardData = response['message'] ?? {};
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildWelcomeHeader(),
                  const SizedBox(height: 24),
                  _buildActionNeededCard(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Work Overview',
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
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Last 30 Days',
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
                  const SizedBox(height: 100), // Bottom padding for FAB
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
          'Quotation Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        background: Container(color: const Color(0xFFF8FAFC)),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
              )
            ],
          ),
          child: IconButton(
            onPressed: _fetchDashboardData,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_userName! 👋',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage and track your quotation flow.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: const Icon(Icons.person_outline_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'Draft', 'status': 'Draft', 'count': _dashboardData['data']?['Draft'] ?? 0, 'icon': Icons.edit_note_rounded, 'color': Colors.blueGrey},
      {'label': 'Pending', 'status': 'Pending', 'count': _dashboardData['data']?['Pending'] ?? 0, 'icon': Icons.timer_outlined, 'color': Colors.orange},
      {'label': 'Cancelled', 'status': 'Cancelled', 'count': _dashboardData['data']?['Cancelled'] ?? 0, 'icon': Icons.block_flipped, 'color': Colors.grey},
      
      {'label': 'Verified (Fin)', 'status': 'Verified By Finance Team', 'count': _dashboardData['data']?['Verified By Finance Team'] ?? 0, 'icon': Icons.verified_outlined, 'color': Colors.blue},
      {'label': 'Rejected (Fin)', 'status': 'Rejected By Finance Team', 'count': _dashboardData['data']?['Rejected By Finance Team'] ?? 0, 'icon': Icons.assignment_return_outlined, 'color': Colors.redAccent},
      {'label': 'Expired', 'status': 'Expired', 'count': _dashboardData['data']?['Expired'] ?? 0, 'icon': Icons.history_rounded, 'color': Colors.brown},
      
      {'label': 'Approved (MD)', 'status': 'Approved By MD', 'count': _dashboardData['data']?['Approved By MD'] ?? 0, 'icon': Icons.check_circle_outline_rounded, 'color': Colors.green},
      {'label': 'Rejected (MD)', 'status': 'Rejected By MD', 'count': _dashboardData['data']?['Rejected By MD'] ?? 0, 'icon': Icons.cancel_outlined, 'color': Colors.red},
      {'label': 'All Records', 'status': '', 'count': _dashboardData['total'] ?? 0, 'icon': Icons.grid_view_rounded, 'color': AppColors.primary},
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildInnovativeCard(stat);
      },
    );
  }

  Widget _buildInnovativeCard(Map<String, dynamic> stat) {
    final Color baseColor = stat['color'] as Color;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuotationListScreen(filterStatus: stat['status']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(stat['icon'] as IconData, color: baseColor, size: 20),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        stat['count'].toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildActionNeededCard() {
    final int actionCount = _dashboardData['action_required'] ?? 0;
    if (actionCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Needed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have $actionCount quotes to review',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB91C1C).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFB91C1C), size: 14),
          ),
        ],
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
        _buildActionTile(
          'View All Records',
          'History and performance tracking',
          Icons.folder_open_rounded,
          const Color(0xFF6366F1),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuotationListScreen())),
        ),
        _buildActionTile(
          'Reports & Analytics',
          'Coming soon in next update',
          Icons.analytics_outlined,
          const Color(0xFF10B981),
          () {},
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textLight.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildCustomFAB() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuotationFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        label: Text(
          'Create Quote',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
