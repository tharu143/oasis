import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/timesheet_model.dart';
import 'timesheet_form_screen.dart';

class TimesheetDetailScreen extends StatefulWidget {
  final TimesheetModel timesheet;
  const TimesheetDetailScreen({super.key, required this.timesheet});

  @override
  State<TimesheetDetailScreen> createState() => _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends State<TimesheetDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late TimesheetModel _timesheet;
  List<String> _availableActions = [];
  bool _isLoading = false;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _timesheet = widget.timesheet;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.timesheet.get_timesheet',
        params: {'name': _timesheet.name ?? ''},
      );

      final dynamic body = response['message'] ?? response['data'] ?? response;
      if (body != null && body['data'] != null) {
        setState(() {
          _timesheet = TimesheetModel.fromJson(Map<String, dynamic>.from(body['data']));
          _availableActions = List<String>.from(response['available_actions'] ?? body['available_actions'] ?? []);
          _isLoading = false;
        });
      } else if (response['data'] != null) {
        setState(() {
          _timesheet = TimesheetModel.fromJson(Map<String, dynamic>.from(response['data']));
          _availableActions = List<String>.from(response['available_actions'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching timesheet details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitTimesheet() async {
    final confirm = await _showConfirmDialog(
      title: 'Submit Timesheet',
      message: 'Are you sure you want to submit ${_timesheet.name}? Once submitted, logs will be locked for editing.',
      confirmText: 'Submit',
      confirmColor: const Color(0xFF10B981),
    );
    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _apiClient.post(
        'oasis_mobile.api.timesheet.submit_timesheet',
        {'name': _timesheet.name ?? ''},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timesheet submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelTimesheet() async {
    final confirm = await _showConfirmDialog(
      title: 'Cancel Timesheet',
      message: 'Are you sure you want to cancel ${_timesheet.name}?',
      confirmText: 'Cancel Timesheet',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _apiClient.post(
        'oasis_mobile.api.timesheet.cancel_timesheet',
        {'name': _timesheet.name ?? ''},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet cancelled successfully.')),
        );
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _deleteTimesheet() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Timesheet',
      message: 'Are you sure you want to permanently delete draft ${_timesheet.name}?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _apiClient.post(
        'oasis_mobile.api.timesheet.delete_timesheet',
        {'name': _timesheet.name ?? ''},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet deleted.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = _timesheet.status.toLowerCase() == 'draft' && _timesheet.docstatus == 0;
    final isSubmitted = _timesheet.status.toLowerCase() == 'submitted' || _timesheet.docstatus == 1;

    final canSubmit = _availableActions.contains('Submit') || isDraft;
    final canEdit = _availableActions.contains('Edit') || isDraft;
    final canDelete = _availableActions.contains('Delete') || isDraft;
    final canCancel = _availableActions.contains('Cancel') || isSubmitted;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _timesheet.name ?? 'Timesheet Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (_timesheet.employeeName != null)
              Text(
                _timesheet.employeeName!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimesheetFormScreen(timesheet: _timesheet),
                  ),
                ).then((_) => _fetchDetails());
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildHoursSummaryCard(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TIME LOGS (${_timesheet.timeLogs.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textLight,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (isDraft)
                        Text(
                          '${_timesheet.timeLogs.length} entries recorded',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF0284C7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_timesheet.timeLogs.isEmpty)
                    _buildEmptyLogsCard()
                  else
                    ..._timesheet.timeLogs.asMap().entries.map((entry) {
                      return _buildTimeLogTile(entry.value, entry.key + 1);
                    }),
                  if (_timesheet.note != null && _timesheet.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: (_isLoading || _isProcessingAction)
          ? null
          : _buildBottomActionBar(
              canSubmit: canSubmit,
              canCancel: canCancel,
              canDelete: canDelete,
              canEdit: canEdit,
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _timesheet.name ?? 'Draft Timesheet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _timesheet.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _timesheet.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _timesheet.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _timesheet.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          _buildInfoRow('Employee', '${_timesheet.employeeName ?? _timesheet.employee} (${_timesheet.employee})'),
          const SizedBox(height: 8),
          if (_timesheet.company.isNotEmpty) ...[
            _buildInfoRow('Company', _timesheet.company),
            const SizedBox(height: 8),
          ],
          if (_timesheet.parentProject != null && _timesheet.parentProject!.isNotEmpty) ...[
            _buildInfoRow('Parent Project', _timesheet.parentProject!),
            const SizedBox(height: 8),
          ],
          if (_timesheet.startDate != null) ...[
            _buildInfoRow('Date Range', '${_timesheet.startDate} to ${_timesheet.endDate ?? _timesheet.startDate}'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoursSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Logged Hours',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_timesheet.totalHours.toStringAsFixed(1)} hrs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Billable Hours',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_timesheet.totalBillableHours.toStringAsFixed(1)} hrs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLogTile(TimeLogModel log, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$index',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    log.activityType.isNotEmpty ? log.activityType : 'Activity Log',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: log.isBillable == 1
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.isBillable == 1 ? 'Billable' : 'Non-Billable',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: log.isBillable == 1 ? const Color(0xFF10B981) : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // From / To Time Row
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${log.fromTime.isNotEmpty ? log.fromTime : "—"}  ➜  ${log.toTime.isNotEmpty ? log.toTime : "—"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${log.hours.toStringAsFixed(1)} hrs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),

          if (log.project.isNotEmpty || log.task.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (log.project.isNotEmpty) ...[
                  const Icon(Icons.folder_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      log.projectName ?? log.project,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                if (log.project.isNotEmpty && log.task.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('•', style: TextStyle(color: Colors.grey)),
                  ),
                if (log.task.isNotEmpty) ...[
                  const Icon(Icons.assignment_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      log.task,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (log.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                log.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyLogsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          'No time logs recorded in this timesheet.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes / Remarks',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _timesheet.note!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar({
    required bool canSubmit,
    required bool canCancel,
    required bool canDelete,
    required bool canEdit,
  }) {
    if (!canSubmit && !canCancel && !canDelete && !canEdit) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (canDelete) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteTimesheet,
              tooltip: 'Delete Draft',
            ),
            const SizedBox(width: 8),
          ],
          if (canCancel) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelTimesheet,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel Timesheet',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (canSubmit) ...[
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submitTimesheet,
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Submit Timesheet',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
