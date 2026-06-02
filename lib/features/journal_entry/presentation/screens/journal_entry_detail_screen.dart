import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/widgets/workflow_action_bar.dart';
import 'package:oasis/core/services/role_helper.dart';
import '../../models/journal_entry_model.dart';
import 'journal_entry_form_screen.dart';

class JournalEntryDetailScreen extends StatefulWidget {
  final JournalEntryModel journalEntry;
  const JournalEntryDetailScreen({super.key, required this.journalEntry});

  @override
  State<JournalEntryDetailScreen> createState() => _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState extends State<JournalEntryDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  JournalEntryModel? _details;
  List<String> _workflowActions = [];
  String? _userActionState;

  @override
  void initState() {
    super.initState();
    _loadUserActionState();
    _fetchDetails();
  }

  Future<void> _loadUserActionState() async {
    final state = await RoleHelper.getActionStateFromPrefs();
    if (mounted) {
      setState(() {
        _userActionState = state;
      });
    }
  }

  bool canEdit({required int docStatus, required List<String> workflowActions, String? workflowState}) {
    if (docStatus != 0) return false;
    if (workflowActions.isEmpty) return false;
    final docState = workflowState ?? 'Draft';
    if (docState != _userActionState) return false;
    return true;
  }

  Color workflowStateColor(String state) {
    switch (state) {
      case 'Draft':                      return const Color(0xFF6B7280); // grey
      case 'Pending':                    return const Color(0xFFF59E0B); // amber
      case 'Verified By Finance Team':   return const Color(0xFF3B82F6); // blue
      case 'Verified By Accounts Team':  return const Color(0xFF3B82F6); // blue
      case 'Approved By MD':             return const Color(0xFF16A34A); // green
      case 'Submitted':                  return const Color(0xFF16A34A); // green
      case 'Rejected By Finance Team':   return const Color(0xFFDC2626); // red
      case 'Rejected By MD':             return const Color(0xFFDC2626); // red
      case 'Cancelled':                  return const Color(0xFF9CA3AF); // light grey
      default:                           return const Color(0xFF6B7280);
    }
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.journal_entry.get_journal_entry',
        params: {'name': widget.journalEntry.name ?? ''},
      );

      if (res['status'] == 'success' || res['message'] != null) {
        final message = res['message'] ?? res;
        setState(() {
          final docData = Map<String, dynamic>.from(message['data'] ?? {});
          final List<dynamic> actions = message['workflow_actions'] ?? [];
          _details = JournalEntryModel.fromJson(docData);
          _workflowActions = actions.map((e) => e.toString()).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch details: $e')),
        );
      }
    }
  }

  // --- Deleting Draft Entry ---
  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Draft', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this draft entry?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiClient.post(
        'oasis_mobile.api.journal_entry.delete_journal_entry',
        {'name': widget.journalEntry.name ?? ''},
      );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft deleted successfully'), backgroundColor: AppColors.approvedMD),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // --- Workflow actions triggers ---
  Future<void> _applyWorkflowAction(String action) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.post(
        'oasis_mobile.api.journal_entry.apply_workflow_action',
        {
          'name': _details?.name ?? '',
          'action': action,
        },
      );

      // res['message'] can be a Map {status, message, workflow_state}
      // or a plain String — handle both safely.
      final dynamic rawMsg = res['message'];
      final String displayMsg;
      if (rawMsg is Map) {
        displayMsg = rawMsg['message']?.toString() ?? 'Action applied successfully';
      } else {
        displayMsg = rawMsg?.toString() ?? 'Action applied successfully';
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayMsg), backgroundColor: AppColors.approvedMD),
        );
      }
      _fetchDetails();
    } catch (e) {
      final errStr = _cleanHtml(e.toString());
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Action Failed', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            content: Text(errStr, style: GoogleFonts.plusJakartaSans()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Strip HTML tags from server error messages for clean display.
  String _cleanHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _details ?? widget.journalEntry;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(doc),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeaderCard(doc)),
                    SliverToBoxAdapter(child: _buildMetadataSection(doc)),
                    SliverToBoxAdapter(child: _buildLedgerSection(doc)),
                    SliverToBoxAdapter(child: _buildRemarksSection(doc)),
                    SliverToBoxAdapter(child: _buildAuditSection(doc)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom spacing
                  ],
                ),
              ),
              _buildBottomActionTransitions(doc),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(JournalEntryModel doc) {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        doc.name ?? 'Voucher Details',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
      ),
      actions: [
        if (canEdit(docStatus: doc.docstatus, workflowActions: _workflowActions, workflowState: doc.workflowState))
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JournalEntryFormScreen(journalEntry: doc),
                ),
              ).then((_) => _fetchDetails());
            },
          ),
        if (doc.docstatus == 0)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deleteEntry,
          ),
      ],
    );
  }

  Widget _buildHeaderCard(JournalEntryModel doc) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doc.voucherType,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: workflowStateColor(doc.workflowState ?? 'Draft').withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: workflowStateColor(doc.workflowState ?? 'Draft').withValues(alpha: 0.6), width: 1.5),
                ),
                child: Text(
                  doc.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: workflowStateColor(doc.workflowState ?? 'Draft')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            doc.name ?? 'New Entry',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.business_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  doc.company.isNotEmpty ? doc.company : 'Oasis Qatar',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(JournalEntryModel doc) {
    String postDate = '';
    try {
      if (doc.postingDate.isNotEmpty) {
        postDate = DateFormat('dd MMM yyyy').format(DateTime.parse(doc.postingDate));
      }
    } catch (_) {
      postDate = doc.postingDate;
    }

    String chqDate = '';
    try {
      if (doc.chequeDate != null && doc.chequeDate!.isNotEmpty) {
        chqDate = DateFormat('dd MMM yyyy').format(DateTime.parse(doc.chequeDate!));
      }
    } catch (_) {
      chqDate = doc.chequeDate ?? '';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information Details',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Posting Date', postDate),
          if (doc.chequeNo != null && doc.chequeNo!.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Cheque/Ref Number', doc.chequeNo!),
          ],
          if (chqDate.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Reference Date', chqDate),
          ],
          if (doc.customReferenceId != null && doc.customReferenceId!.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Custom Ref ID', doc.customReferenceId!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLedgerSection(JournalEntryModel doc) {
    if (doc.accounts.isEmpty) return const SizedBox.shrink();

    final deb = doc.totalDebit ?? 0.0;
    final cred = doc.totalCredit ?? 0.0;
    final diff = doc.difference ?? 0.0;
    final isBalanced = diff.abs() < 0.001;

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ledger Accounts (${doc.accounts.length})',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doc.accounts.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
            itemBuilder: (context, index) {
              final acc = doc.accounts[index];
              final debitVal = acc.debit ?? 0.0;
              final creditVal = acc.credit ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            acc.account,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (debitVal > 0)
                          Text(
                            '+ QAR ${debitVal.toStringAsFixed(2)} (Dr)',
                            style: GoogleFonts.plusJakartaSans(color: AppColors.approvedMD, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        if (creditVal > 0)
                          Text(
                            '- QAR ${creditVal.toStringAsFixed(2)} (Cr)',
                            style: GoogleFonts.plusJakartaSans(color: AppColors.rejectedMD, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                      ],
                    ),
                    if ((acc.costCenter != null && acc.costCenter!.isNotEmpty) || (acc.project != null && acc.project!.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (acc.costCenter != null && acc.costCenter!.isNotEmpty) ...[
                            Icon(Icons.center_focus_strong_rounded, size: 10, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              acc.costCenter!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (acc.project != null && acc.project!.isNotEmpty) ...[
                            Icon(Icons.assignment_turned_in_rounded, size: 10, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              acc.project!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ]
                  ],
                ),
              );
            },
          ),
          const Divider(color: AppColors.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Debit', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('QAR ${deb.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Credit', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('QAR ${cred.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isBalanced
                  ? AppColors.approvedMD.withValues(alpha: 0.1)
                  : AppColors.pendingFinance.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle_rounded : Icons.warning_rounded,
                  size: 14,
                  color: isBalanced ? AppColors.approvedMD : AppColors.pendingFinance,
                ),
                const SizedBox(width: 6),
                Text(
                  isBalanced ? 'Balanced Ledger Double-Entry' : 'Unbalanced Ledger! Diff: QAR ${diff.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isBalanced ? AppColors.approvedMD : AppColors.pendingFinance,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRemarksSection(JournalEntryModel doc) {
    if (doc.userRemark == null || doc.userRemark!.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remarks / Notes',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            doc.userRemark!,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditSection(JournalEntryModel doc) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audit Timeline',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildAuditRow('Prepared By', doc.customPreparedByName ?? doc.customPreparedBy ?? 'N/A'),
          const Divider(color: AppColors.border),
          _buildAuditRow('Checked By', doc.customVerifiedByName ?? doc.customVerifiedBy ?? 'N/A'),
          const Divider(color: AppColors.border),
          _buildAuditRow('Approved By', doc.customApprovedByName ?? doc.customApprovedBy ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String role, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(role, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomActionTransitions(JournalEntryModel doc) {
    return WorkflowActionBar(
      workflowActions: _workflowActions,
      currentState: doc.workflowState ?? 'Draft',
      docStatus: doc.docstatus,
      isLoading: _isLoading,
      onAction: (action) => _applyWorkflowAction(action),
    );
  }
}
