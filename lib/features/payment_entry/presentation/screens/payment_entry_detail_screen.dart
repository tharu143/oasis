import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
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
  List<String> _userRoles = [];
  List<String> _workflowActions = [];

  @override
  void initState() {
    super.initState();
    _loadRolesAndFetchDetails();
  }

  Future<void> _loadRolesAndFetchDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRoles = prefs.getStringList('roles') ?? [];
    });
    await _fetchDetails();
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

      final msg = res['message'] ?? 'Action applied successfully';
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.approvedMD),
        );
      }
      _fetchDetails();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.rejectedMD),
        );
      }
    }
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
    final state = (doc.workflowState ?? 'Draft').toLowerCase();

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
        if (state == 'draft') ...[
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
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rejectedMD),
            onPressed: _deleteEntry,
          ),
        ],
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
                  color: doc.statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: doc.statusColor.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Text(
                  doc.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: doc.statusColor),
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
    if (_workflowActions.isEmpty) return const SizedBox.shrink();

    final state = (doc.workflowState ?? 'Draft').toLowerCase();

    bool isAccountant = false;
    bool isOasisManager = false;

    // Substring matching roles
    for (var r in _userRoles) {
      final lr = r.toLowerCase();
      if (lr.contains('account') || lr.contains('finance')) {
        isAccountant = true;
      }
      if (lr.contains('manager') || lr.contains('md') || lr.contains('oasis')) {
        isOasisManager = true;
      }
    }

    // Default if roles is empty (allow developer review)
    if (_userRoles.isEmpty) {
      isAccountant = true;
      isOasisManager = true;
    }

    List<Widget> buttons = [];

    for (var action in _workflowActions) {
      bool show = false;

      if (state == 'draft') {
        if (action == 'Review') {
          show = true;
        }
      }
      if (state == 'pending') {
        if (isAccountant && (action == 'Verified' || action == 'Reject')) {
          show = true;
        }
      }
      if (state.contains('verified by finance') || state.contains('verified')) {
        if (isOasisManager && (action == 'Approve' || action == 'Reject')) {
          show = true;
        }
      }

      if (show) {
        final isReject = action == 'Reject';

        buttons.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ElevatedButton(
                onPressed: () => _applyWorkflowAction(action),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReject ? AppColors.rejectedMD : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  action == 'Review'
                      ? 'Submit for Review'
                      : action == 'Verified'
                          ? 'Verify Payment'
                          : action == 'Approve'
                              ? 'Approve Payment'
                              : '$action Payment',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: buttons),
    );
  }
}
