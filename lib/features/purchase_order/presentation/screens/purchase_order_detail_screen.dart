import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
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
  List<String> _userRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRoles = prefs.getStringList('roles') ?? [];
    });
  }

  bool get isPurchaseUser => _userRoles.any((r) => r.toLowerCase().contains('purchase') || r.toLowerCase().contains('sales'));
  bool get isAccountsManager => _userRoles.any((r) => r.toLowerCase().contains('account') || r.toLowerCase().contains('finance'));
  bool get isOasisManager => _userRoles.any((r) => r.toLowerCase().contains('oasis') || r.toLowerCase().contains('manager') || r.toLowerCase().contains('md') || r.toLowerCase().contains('stock'));

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message['message'] ?? 'Action applied successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
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
          if (_purchaseOrder != null && (_purchaseOrder!.workflowState ?? '').toLowerCase() == 'draft') ...[
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
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteOrder,
            ),
          ],
        ],
      ),
      body: _isLoading || _purchaseOrder == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildGlassmorphicHeaderCard(),
                    const SizedBox(height: 24),
                    _buildGeneralDetailsCard(),
                    const SizedBox(height: 24),
                    _buildItemsCard(),
                  ],
                ),
                _buildFloatingBottomActions(),
              ],
            ),
    );
  }

  Widget _buildGlassmorphicHeaderCard() {
    final order = _purchaseOrder!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [order.statusColor, order.statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: order.statusColor.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
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
              color: Colors.white.withOpacity(0.7),
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
                  color: Colors.white.withOpacity(0.9),
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
                        color: AppColors.primary.withOpacity(0.1),
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

  Widget _buildFloatingBottomActions() {
    final state = (_purchaseOrder!.workflowState ?? '').toLowerCase();

    List<Widget> buttons = [];

    // Role checks
    if (state == 'draft') {
      if (isPurchaseUser || _userRoles.isEmpty) {
        buttons.add(
          _buildActionButton('Submit for Review', AppColors.primary, () => _applyAction('Review')),
        );
      }
    } else if (state == 'pending') {
      if (isAccountsManager || _userRoles.isEmpty) {
        buttons.add(
          _buildActionButton('Verify Order', const Color(0xFF10B981), () => _applyAction('Verified')),
        );
        buttons.add(
          _buildActionButton('Reject Order', AppColors.rejectedMD, () => _applyAction('Reject')),
        );
      }
    } else if (state.contains('verified by finance') || state == 'verified') {
      if (isOasisManager || _userRoles.isEmpty) {
        buttons.add(
          _buildActionButton('Approve Order', const Color(0xFF10B981), () => _applyAction('Approve')),
        );
        buttons.add(
          _buildActionButton('Reject Order', AppColors.rejectedMD, () => _applyAction('Reject')),
        );
      }
    }

    // Default fallbacks in case custom actions are loaded but no matching buttons were generated
    if (buttons.isEmpty && _workflowActions.isNotEmpty) {
      for (var action in _workflowActions) {
        Color btnColor = AppColors.primary;
        if (action.toLowerCase().contains('reject')) btnColor = AppColors.rejectedMD;
        if (action.toLowerCase().contains('verify') || action.toLowerCase().contains('approve')) btnColor = const Color(0xFF10B981);
        
        buttons.add(
          _buildActionButton(action, btnColor, () => _applyAction(action)),
        );
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: buttons.map((btn) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: btn))).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
