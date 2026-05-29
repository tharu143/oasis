import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/widgets/workflow_action_bar.dart';
import 'package:oasis/features/purchase_order/models/purchase_order_model.dart';
import 'purchase_order_form_screen.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String purchaseOrderId;

  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  PurchaseOrderModel? _purchaseOrder;
  List<String> _workflowActions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  bool canEdit({required int docStatus, required List<String> workflowActions}) {
    if (docStatus != 0) return false;
    if (workflowActions.isEmpty) return false;
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
      final response = await _apiClient.get(
        'oasis_mobile.api.purchase_order.get_purchase_order',
        params: {'name': widget.purchaseOrderId},
      );
      
      final dynamic body = response['message'] ?? response['data'] ?? response;
      if (response['status'] == 'success' || body['status'] == 'success' || body['data'] != null) {
        setState(() {
          final data = Map<String, dynamic>.from(body['data'] ?? {});
          _workflowActions = List<String>.from(body['workflow_actions'] ?? []);
          _purchaseOrder = PurchaseOrderModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching purchase order details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Future<void> _applyAction(String action) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Action', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to apply action "$action"?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.purchase_order.apply_workflow_action',
        {
          'name': _purchaseOrder!.name ?? '',
          'action': action,
        },
      );
      
      final message = response['message'] ?? response;
      if (response['status'] == 'success' || message['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message['message'] ?? 'Action applied successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        _fetchDetails();
      } else {
        throw Exception(message['message'] ?? 'Workflow action failed.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Workflow Error'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Document', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to permanently delete this Purchase Order?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.purchase_order.delete_purchase_order',
        {'name': _purchaseOrder!.name ?? ''},
      );

      final status = response['status'] ?? response['message']?['status'];
      if (status == 'success' || response['message'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase Order deleted successfully'), backgroundColor: Colors.redAccent),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('API delete request failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting order: $e'), backgroundColor: Colors.red),
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _purchaseOrder?.name ?? widget.purchaseOrderId,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
        ),
        actions: [
          if (_purchaseOrder != null && canEdit(docStatus: _purchaseOrder!.docstatus, workflowActions: _workflowActions))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseOrderFormScreen(purchaseOrder: _purchaseOrder),
                  ),
                );
                if (result == true) {
                  _fetchDetails();
                }
              },
            ),
          if (_purchaseOrder != null && _purchaseOrder!.docstatus == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteOrder,
            ),
        ],
      ),
      body: _isLoading || _purchaseOrder == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildGlassmorphicHeaderCard(),
                          const SizedBox(height: 24),
                          _buildGeneralDetailsCard(),
                          const SizedBox(height: 24),
                          _buildItemsCard(),
                        ],
                      ),
                    ),
                    _buildBottomActionTransitions(),
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

  Widget _buildGlassmorphicHeaderCard() {
    final order = _purchaseOrder!;
    final badgeColor = workflowStateColor(order.workflowState ?? 'Draft');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Text(
                  order.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Grand Total',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                '${order.currency} ',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                intl.NumberFormat("#,##0.00").format(order.grandTotal ?? 0.0),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralDetailsCard() {
    final order = _purchaseOrder!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Information',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          _buildInfoRow('Supplier Code', order.supplier),
          _buildInfoRow('Supplier Name', order.supplierName ?? ''),
          _buildInfoRow('Transaction Date', order.transactionDate),
          _buildInfoRow('Price List', order.buyingPriceList),
          _buildInfoRow('Currency', order.currency),
          if (order.customRef != null && order.customRef!.isNotEmpty)
            _buildInfoRow('Reference', order.customRef!),
          if (order.customRemarks != null && order.customRemarks!.isNotEmpty)
            _buildInfoRow('Remarks', order.customRemarks!),
          if (order.customPreparedBy != null && order.customPreparedBy!.isNotEmpty)
            _buildInfoRow('Prepared By', order.customPreparedBy!),
          if (order.customVerifiedBy != null && order.customVerifiedBy!.isNotEmpty)
            _buildInfoRow('Verified By', order.customVerifiedBy!),
          if (order.customApprovedBy != null && order.customApprovedBy!.isNotEmpty)
            _buildInfoRow('Approved By', order.customApprovedBy!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final order = _purchaseOrder!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Breakdown',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.widgets_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName ?? item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${item.qty.toStringAsFixed(0)} ${item.uom} x ${order.currency} ${intl.NumberFormat("#,##0.00").format(item.rate)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Req by: ${item.scheduleDate}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text('${order.currency} ${intl.NumberFormat("#,##0.00").format(item.amount ?? (item.qty * item.rate))}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionTransitions() {
    final order = _purchaseOrder!;
    return WorkflowActionBar(
      workflowActions: _workflowActions,
      currentState: order.workflowState ?? 'Draft',
      docStatus: order.docstatus,
      isLoading: _isLoading,
      onAction: (action) => _applyAction(action),
    );
  }
}
