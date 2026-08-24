import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'timesheet_list_screen.dart';
import 'timesheet_form_screen.dart';

class TimesheetDashboardScreen extends StatefulWidget {
  const TimesheetDashboardScreen({super.key});

  @override
  State<TimesheetDashboardScreen> createState() => _TimesheetDashboardScreenState();
}

class _TimesheetDashboardScreenState extends State<TimesheetDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardCounts = {};
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _employeeContext = {};
  int _actionRequired = 0;
  String _userName = 'Employee';
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
      _userName = prefs.getString('full_name') ?? 'Employee';
      if (_userName.contains(' ')) {
        _userName = _userName.split(' ')[0];
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('oasis_mobile.api.timesheet.get_timesheet_dashboard');
      final dynamic body = response['message'] ?? response['data'] ?? response;

      if (body != null) {
        setState(() {
          _dashboardCounts = Map<String, dynamic>.from(body['data'] ?? {});
          _metrics = Map<String, dynamic>.from(body['metrics'] ?? {});
          _employeeContext = Map<String, dynamic>.from(body['employee_context'] ?? {});
          _actionRequired = (body['action_required'] is num)
              ? (body['action_required'] as num).toInt()
              : (int.tryParse(body['action_required']?.toString() ?? '0') ?? 0);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading timesheet dashboard: $e')),
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

                        // Employee Card Info Banner
                        if (_employeeContext.isNotEmpty) _buildEmployeeBanner(),

                        if (_employeeContext.isNotEmpty) const SizedBox(height: 20),

                        // Quick Hours Highlight Cards
                        _buildHoursMetricRow(),

                        const SizedBox(height: 24),

                        // Action Required Banner
                        if (_actionRequired > 0) ...[
                          _buildActionRequiredBanner(),
                          const SizedBox(height: 24),
                        ],

                        // Status Pipeline / Grid
                        Text(
                          'TIMESHEET STATUS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textLight,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildStatusGrid(),

                        const SizedBox(height: 28),

                        // Quick Actions
                        Text(
                          'QUICK ACTIONS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textLight,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildQuickActions(),

                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimesheetFormScreen()),
          ).then((_) => _fetchDashboardData());
        },
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Timesheet',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF0284C7),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchDashboardData,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Timesheets Overview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track work hours & project logs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeBanner() {
    final empName = _employeeContext['employee_name'] ?? _userName;
    final dept = _employeeContext['department'] ?? '';
    final empId = _employeeContext['name'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [if (empId.isNotEmpty) empId, if (dept.isNotEmpty) dept].join(' • '),
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
    );
  }

  Widget _buildHoursMetricRow() {
    final totalHours = (_metrics['total_hours'] is num)
        ? (_metrics['total_hours'] as num).toDouble()
        : double.tryParse(_metrics['total_hours']?.toString() ?? '0') ?? 0.0;

    final billableHours = (_metrics['billable_hours'] is num)
        ? (_metrics['billable_hours'] as num).toDouble()
        : double.tryParse(_metrics['billable_hours']?.toString() ?? '0') ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Hours',
            value: '${totalHours.toStringAsFixed(1)} hrs',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            title: 'Billable Hours',
            value: '${billableHours.toStringAsFixed(1)} hrs',
            icon: Icons.monetization_on_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRequiredBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TimesheetListScreen(filterStatus: 'Draft'),
          ),
        ).then((_) => _fetchDashboardData());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_actionRequired Draft Timesheets Pending',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to review and submit pending logs',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD97706)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusGrid() {
    final statusList = [
      {'label': 'Draft', 'key': 'Draft', 'icon': Icons.edit_note_rounded, 'color': const Color(0xFFF59E0B)},
      {'label': 'Submitted', 'key': 'Submitted', 'icon': Icons.check_circle_outline_rounded, 'color': const Color(0xFF10B981)},
      {'label': 'Billed', 'key': 'Billed', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF6366F1)},
      {'label': 'Payslip', 'key': 'Payslip', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF0EA5E9)},
      {'label': 'Cancelled', 'key': 'Cancelled', 'icon': Icons.cancel_outlined, 'color': const Color(0xFFEF4444)},
      {'label': 'Total', 'key': 'Total', 'icon': Icons.all_inbox_rounded, 'color': const Color(0xFF475569)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 105,
      ),
      itemCount: statusList.length,
      itemBuilder: (context, index) {
        final item = statusList[index];
        final key = item['key'] as String;
        final count = _dashboardCounts[key] ?? 0;
        final color = item['color'] as Color;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TimesheetListScreen(
                  filterStatus: key == 'Total' ? null : key,
                ),
              ),
            ).then((_) => _fetchDashboardData());
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(item['icon'] as IconData, color: color, size: 20),
                    Text(
                      '$count',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  item['label'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            title: 'View All',
            subtitle: 'Browse all logs',
            icon: Icons.list_alt_rounded,
            color: const Color(0xFF0284C7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimesheetListScreen()),
              ).then((_) => _fetchDashboardData());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            title: 'New Entry',
            subtitle: 'Log daily work',
            icon: Icons.add_task_rounded,
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimesheetFormScreen()),
              ).then((_) => _fetchDashboardData());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
