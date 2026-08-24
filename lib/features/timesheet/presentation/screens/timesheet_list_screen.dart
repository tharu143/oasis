import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/timesheet_model.dart';
import 'timesheet_detail_screen.dart';
import 'timesheet_form_screen.dart';

class TimesheetListScreen extends StatefulWidget {
  final String? filterStatus;
  const TimesheetListScreen({super.key, this.filterStatus});

  @override
  State<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends State<TimesheetListScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<TimesheetModel> _timesheets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _start = 0;
  final int _limit = 25;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;

  final List<String> _statusFilters = [
    'All',
    'Draft',
    'Submitted',
    'Billed',
    'Payslip',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.filterStatus;
    _fetchTimesheets();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _fetchTimesheets();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimesheets({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _start = 0;
        _timesheets.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, String> params = {
        'limit_start': _start.toString(),
        'limit_page_length': _limit.toString(),
      };

      if (_selectedStatus != null && _selectedStatus!.isNotEmpty && _selectedStatus != 'All') {
        params['status'] = _selectedStatus!;
      }

      if (_searchQuery.isNotEmpty) {
        params['search_txt'] = _searchQuery;
      }

      final response = await _apiClient.get(
        'oasis_mobile.api.timesheet.get_timesheet_list',
        params: params,
      );

      final dynamic body = response['message'] ?? response['data'] ?? response;
      final List<dynamic> data = (body is Map && body['data'] is List)
          ? body['data']
          : (response['data'] is List ? response['data'] : (body is List ? body : []));

      final bool hasMoreFromServer = (body is Map && body['has_more'] is bool)
          ? body['has_more']
          : (response['has_more'] ?? false);

      final List<TimesheetModel> newItems = data
          .map((item) => TimesheetModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      setState(() {
        _timesheets.addAll(newItems);
        _start += _limit;
        _hasMore = (body is Map && body.containsKey('has_more')) ? hasMoreFromServer : newItems.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching timesheets: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedStatus != null && _selectedStatus != 'All'
              ? '$_selectedStatus Timesheets'
              : 'Timesheets',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => _fetchTimesheets(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchTimesheets(refresh: true),
              color: const Color(0xFF0284C7),
              child: _timesheets.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _timesheets.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _timesheets.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                            ),
                          );
                        }
                        return _buildTimesheetCard(_timesheets[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimesheetFormScreen()),
          ).then((_) => _fetchTimesheets(refresh: true));
        },
        backgroundColor: const Color(0xFF0284C7),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by TS ID, employee, project...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
                icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchTimesheets(refresh: true);
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
              onSubmitted: (_) => _fetchTimesheets(refresh: true),
            ),
          ),
          const SizedBox(height: 12),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _statusFilters.map((status) {
                final isSelected = (_selectedStatus == null && status == 'All') ||
                    _selectedStatus == status ||
                    (_selectedStatus == 'All' && status == 'All');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = status == 'All' ? null : status;
                      });
                      _fetchTimesheets(refresh: true);
                    },
                    selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    checkmarkColor: const Color(0xFF0284C7),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0284C7) : AppColors.textSecondary,
                    ),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetCard(TimesheetModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TimesheetDetailScreen(timesheet: item),
              ),
            ).then((_) => _fetchTimesheets(refresh: true));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: TS ID & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.name ?? 'New Timesheet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(item.status, item.statusColor),
                  ],
                ),
                const SizedBox(height: 12),

                // Employee Row
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.employeeName ?? item.employee,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (item.startDate != null)
                      Text(
                        item.startDate!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),

                // Project Row if available
                if (item.parentProject != null && item.parentProject!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Project: ${item.parentProject}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Note preview if present
                if (item.note != null && item.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${item.totalHours.toStringAsFixed(1)} hrs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Billable: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${item.totalBillableHours.toStringAsFixed(1)} hrs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textLight),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, size: 48, color: Color(0xFF0284C7)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Timesheets Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No logs match your current search or filter criteria.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimesheetFormScreen()),
                  ).then((_) => _fetchTimesheets(refresh: true));
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Create Timesheet',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
