import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/material_request_model.dart';
import 'material_request_form_screen.dart';

class MaterialRequestDetailScreen extends StatefulWidget {
  final MaterialRequestModel materialRequest;
  const MaterialRequestDetailScreen({super.key, required this.materialRequest});

  @override
  State<MaterialRequestDetailScreen> createState() => _MaterialRequestDetailScreenState();
}

class _MaterialRequestDetailScreenState extends State<MaterialRequestDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  MaterialRequestModel? _details;
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
        'oasis_mobile.api.material_request.get_material_request',
        params: {'name': widget.materialRequest.name ?? ''},
      );

      if (res['status'] == 'success' || res['message'] != null) {
        final message = res['message'] ?? res;
        setState(() {
          final docData = Map<String, dynamic>.from(message['data'] ?? {});
          final List<dynamic> actions = message['workflow_actions'] ?? [];
          _details = MaterialRequestModel.fromJson(docData);
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

  // --- Deleting Draft Request ---
  Future<void> _deleteRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Draft', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this draft request?', style: GoogleFonts.plusJakartaSans()),
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
        'oasis_mobile.api.material_request.delete_material_request',
        {'name': widget.materialRequest.name ?? ''},
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
        'oasis_mobile.api.material_request.apply_workflow_action',
        {
          'name': _details?.name ?? '',
          'action': action,
        },
      );

      String msg = 'Action applied successfully';
      if (res['message'] != null) {
        if (res['message'] is Map) {
          msg = res['message']['message'] ?? 'Action applied successfully';
        } else {
          msg = res['message'].toString();
        }
      }
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
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _details ?? widget.materialRequest;

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
                    SliverToBoxAdapter(child: _buildDetailsSection(doc)),
                    SliverToBoxAdapter(child: _buildItemsSection(doc)),
                    SliverToBoxAdapter(child: _buildRemarksSection(doc)),
                    SliverToBoxAdapter(child: _buildAuditSection(doc)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB space
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

  PreferredSizeWidget _buildAppBar(MaterialRequestModel doc) {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        doc.name ?? 'Details',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
      ),
      actions: [
        if (doc.docstatus == 0) ...[
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MaterialRequestFormScreen(materialRequest: doc),
                ),
              ).then((_) => _fetchDetails());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deleteRequest,
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(MaterialRequestModel doc) {
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
                  doc.materialRequestType,
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
            doc.customSubject ?? 'No Subject',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
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

  Widget _buildDetailsSection(MaterialRequestModel doc) {
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
          _buildInfoRow('Transaction Date', doc.transactionDate),
          if (doc.customCustomer != null && doc.customCustomer!.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Customer', doc.customCustomer!),
          ],
          if (doc.customSalesOrder != null && doc.customSalesOrder!.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            _buildInfoRow('Sales Order Link', doc.customSalesOrder!),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
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

  Widget _buildItemsSection(MaterialRequestModel doc) {
    if (doc.items.isEmpty) return const SizedBox.shrink();

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
            'Requested Items (${doc.items.length})',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doc.items.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
            itemBuilder: (context, index) {
              final item = doc.items[index];
              String reqDate = '';
              try {
                if (item.scheduleDate.isNotEmpty) {
                  reqDate = DateFormat('dd MMM').format(DateTime.parse(item.scheduleDate));
                }
              } catch (_) {}

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName ?? item.itemCode,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Required Date: $reqDate',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.qty} ${item.uom}',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection(MaterialRequestModel doc) {
    if (doc.customRemarks == null || doc.customRemarks!.isEmpty) return const SizedBox.shrink();

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
            'Remarks / Justification',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            doc.customRemarks!,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditSection(MaterialRequestModel doc) {
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
          _buildAuditRow('Prepared By', doc.customRequestedByName ?? doc.customRequestedBy ?? 'N/A'),
          const Divider(color: AppColors.border),
          _buildAuditRow('Checked By', doc.customCheckedByName ?? doc.customCheckedBy ?? 'N/A'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
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

  Widget _buildBottomActionTransitions(MaterialRequestModel doc) {
    if (_workflowActions.isEmpty) return const SizedBox.shrink();

    List<Widget> buttons = [];

    for (var action in _workflowActions) {
      final actLower = action.toLowerCase();
      final isReject = actLower.contains('reject') || actLower.contains('cancel');
      final isSuccess = actLower.contains('approve') || actLower.contains('verify') || actLower.contains('review') || actLower.contains('submit') || actLower.contains('verified');
      
      Color bgColor = AppColors.primary;
      if (isSuccess) bgColor = const Color(0xFF10B981);
      if (isReject) bgColor = const Color(0xFFEF4444);

      buttons.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ElevatedButton(
              onPressed: () => _applyWorkflowAction(action),
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 50),
                elevation: 0,
              ),
              child: Text(
                action == 'Review'
                    ? 'Submit for Review'
                    : action == 'Verified'
                        ? 'Verify Request'
                        : action == 'Verify'
                            ? 'Verify Request'
                            : action == 'Approve'
                                ? 'Approve Request'
                                : '$action Request',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: buttons),
    );
  }
}
