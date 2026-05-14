import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Quotation Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchDashboardData,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    _buildActionNeededCard(),
                    const SizedBox(height: 30),
                      Text(
                        'Overview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildStatsGrid(),
                    const SizedBox(height: 40),
                    _buildQuickActions(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuotationFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Quote',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Team!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your quotations and workflow here.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'Draft', 'status': 'Draft', 'count': _dashboardData['data']?['Draft'] ?? 0, 'icon': Icons.edit_document, 'color': Colors.grey},
      {'label': 'Pending', 'status': 'Pending', 'count': _dashboardData['data']?['Pending'] ?? 0, 'icon': Icons.pending_actions, 'color': Colors.amber},
      {'label': 'Verified (Fin)', 'status': 'Verified By Finance Team', 'count': _dashboardData['data']?['Verified By Finance Team'] ?? 0, 'icon': Icons.verified_user_outlined, 'color': Colors.blue},
      {'label': 'Approved (MD)', 'status': 'Approved By MD', 'count': _dashboardData['data']?['Approved By MD'] ?? 0, 'icon': Icons.check_circle_outline, 'color': const Color(0xFF10B981)},
      {'label': 'Rejected (Fin)', 'status': 'Rejected By Finance Team', 'count': _dashboardData['data']?['Rejected By Finance Team'] ?? 0, 'icon': Icons.error_outline, 'color': Colors.redAccent},
      {'label': 'Rejected (MD)', 'status': 'Rejected By MD', 'count': _dashboardData['data']?['Rejected By MD'] ?? 0, 'icon': Icons.cancel_outlined, 'color': Colors.red},
      {'label': 'Cancelled', 'status': 'Cancelled', 'count': _dashboardData['data']?['Cancelled'] ?? 0, 'icon': Icons.cancel_presentation_outlined, 'color': Colors.blueGrey},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 130, // Fixed height ensures no overflow
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildGlassCard(stat);
      },
    );
  }

  Widget _buildGlassCard(Map<String, dynamic> stat) {
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (stat['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(stat['icon'] as IconData, color: stat['icon_color'] ?? stat['color'] as Color, size: 18),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stat['count'].toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat['label'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          'Quick Access',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          'All Quotations',
          'View your entire history',
          Icons.list_alt,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuotationListScreen())),
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.list_alt, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
      ),
    );
  }

  Widget _buildActionNeededCard() {
    final int actionCount = _dashboardData['action_required'] ?? 0;
    if (actionCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.notification_important_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Needed',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'You have $actionCount quotes pending your approval.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}
