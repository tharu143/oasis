import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/widgets/workflow_action_bar.dart';
import 'package:oasis/core/services/role_helper.dart';
import '../../models/payment_entry_model.dart';
import 'payment_entry_form_screen.dart';

class PaymentEntryDetailScreen extends StatefulWidget {
  final PaymentEntryModel paymentEntry;
  const PaymentEntryDetailScreen({super.key, required this.paymentEntry});

  @override
  State<PaymentEntryDetailScreen> createState() => _PaymentEntryDetailScreenState();
}

class _PaymentEntryDetailScreenState extends State<PaymentEntryDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  PaymentEntryModel? _details;
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
        'oasis_mobile.api.payment_entry.get_payment_entry',
        params: {'name': widget.paymentEntry.name ?? ''},
      );

      if (res['status'] == 'success' || res['message'] != null) {
        final message = res['message'] ?? res;
        setState(() {
          final docData = Map<String, dynamic>.from(message['data'] ?? {});
          final List<dynamic> actions = message['workflow_actions'] ?? [];
          _details = PaymentEntryModel.fromJson(docData);
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

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Draft', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this draft payment entry?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(color: AppColors.rejectedMD, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiClient.post(
        'oasis_mobile.api.payment_entry.delete_payment_entry',
        {'name': widget.paymentEntry.name ?? ''},
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
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.rejectedMD),
        );
      }
    }
  }

  Future<void> _applyWorkflowAction(String action) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.post(
        'oasis_mobile.api.payment_entry.apply_workflow_action',
        {
          'name': _details?.name ?? widget.paymentEntry.name ?? '',
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
    final doc = _details ?? widget.paymentEntry;

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
                    SliverToBoxAdapter(child: _buildAmountsSection(doc)),
                    SliverToBoxAdapter(child: _buildReferencesSection(doc)),
                    SliverToBoxAdapter(child: _buildRemarksSection(doc)),
                    SliverToBoxAdapter(child: _buildAuditSection(doc)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  PreferredSizeWidget _buildAppBar(PaymentEntryModel doc) {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        doc.name ?? 'Payment Details',
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
                  builder: (_) => PaymentEntryFormScreen(paymentEntry: doc),
                ),
              ).then((_) => _fetchDetails());
            },
          ),
        if (doc.docstatus == 0)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rejectedMD),
            onPressed: _deleteEntry,
          ),
      ],
    );
  }

  Widget _buildHeaderCard(PaymentEntryModel doc) {
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
                  doc.paymentType,
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
            doc.name ?? 'New Payment',
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
                  doc.company.isNotEmpty ? doc.company : 'Al Waha Engineering',
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

  Widget _buildMetadataSection(PaymentEntryModel doc) {
    String postDate = '';
    try {
      if (doc.postingDate.isNotEmpty) {
        postDate = DateFormat('dd MMM yyyy').format(DateTime.parse(doc.postingDate));
      }
    } catch (_) {
      postDate = doc.postingDate;
    }

    String refDate = '';
    try {
      if (doc.referenceDate != null && doc.referenceDate!.isNotEmpty) {
        refDate = DateFormat('dd MMM yyyy').format(DateTime.parse(doc.referenceDate!));
      }
    } catch (_) {
      refDate = doc.referenceDate ?? '';
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
          const Divider(color: AppColors.border),
          _buildInfoRow('Mode of Payment', doc.modeOfPayment),
          if (doc.partyType != null && doc.party != null) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Party (${doc.partyType})', doc.party!),
          ],
          if (doc.referenceNo != null && doc.referenceNo!.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Cheque/Ref Number', doc.referenceNo!),
          ],
          if (refDate.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Cheque/Ref Date', refDate),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountsSection(PaymentEntryModel doc) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20),
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
            'Ledger Accounts & Currency',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Paid From', doc.paidFrom),
          const Divider(color: AppColors.border),
          _buildInfoRow('Paid To', doc.paidTo),
          const Divider(color: AppColors.border),
          _buildInfoRow('Paid Amount', 'QAR ${doc.paidAmount.toStringAsFixed(2)}'),
          const Divider(color: AppColors.border),
          _buildInfoRow('Received Amount', 'QAR ${doc.receivedAmount.toStringAsFixed(2)}'),
          const Divider(color: AppColors.border),
          _buildInfoRow('Target Exchange Rate', doc.targetExchangeRate.toStringAsFixed(4)),
        ],
      ),
    );
  }

  Widget _buildReferencesSection(PaymentEntryModel doc) {
    if (doc.references.isEmpty) return const SizedBox.shrink();

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
            'Linked References (${doc.references.length})',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doc.references.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
            itemBuilder: (context, index) {
              final ref = doc.references[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref.referenceName,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        Text(
                          'QAR ${ref.allocatedAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref.referenceDoctype,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Total: QAR ${ref.totalAmount.toStringAsFixed(2)} | O/S: QAR ${ref.outstandingAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection(PaymentEntryModel doc) {
    if (doc.remarks == null || doc.remarks!.isEmpty) return const SizedBox.shrink();

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
            doc.remarks!,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditSection(PaymentEntryModel doc) {
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionTransitions(PaymentEntryModel doc) {
    return WorkflowActionBar(
      workflowActions: _workflowActions,
      currentState: doc.workflowState ?? 'Draft',
      docStatus: doc.docstatus,
      isLoading: _isLoading,
      onAction: (action) => _applyWorkflowAction(action),
    );
  }
}
