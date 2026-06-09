import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/services/role_helper.dart';
import '../../models/sales_invoice_model.dart';
import 'sales_invoice_form_screen.dart';
import '../../../payment_entry/presentation/screens/payment_entry_form_screen.dart';

class SalesInvoiceDetailScreen extends StatefulWidget {
  final SalesInvoiceModel salesInvoice;

  const SalesInvoiceDetailScreen({super.key, required this.salesInvoice});

  @override
  State<SalesInvoiceDetailScreen> createState() => _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late SalesInvoiceModel _salesInvoice;
  bool _hasWorkflow = false;
  List<String> _workflowActions = [];
  List<String> _availableActions = [];
  List<String> _userRoles = [];
  bool _isLoading = false;
  String? _userActionState;
  Map<String, dynamic>? _mappingStatus;

  @override
  void initState() {
    super.initState();
    _salesInvoice = widget.salesInvoice;
    _loadUserActionState();
    _fetchDetails();
    _loadUserRoles();
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
    final docState = (workflowState == null || workflowState.isEmpty) ? 'Draft' : workflowState;
    if (docState.toLowerCase() == 'draft') return true;
    if (workflowActions.isEmpty) return false;
    if (docState != _userActionState) return false;
    return true;
  }

  Future<void> _loadUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRoles = prefs.getStringList('roles') ?? [];
    });
  }

  bool get isSalesUser => _userRoles.any((r) => r.toLowerCase().contains('sales') || r.toLowerCase().contains('manager'));
  bool get isAccountsUser => _userRoles.any((r) => r.toLowerCase().contains('account') || r.toLowerCase().contains('finance'));

  Future<void> _fetchMappingStatus() async {
    try {
      final res = await _apiClient.post(
        'oasis_mobile.api.mapping.check_mapping_status',
        {
          'doctype': 'Sales Invoice',
          'docname': _salesInvoice.name ?? '',
        },
      );
      if (mounted && res['message'] != null) {
        setState(() {
          _mappingStatus = Map<String, dynamic>.from(res['message']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching mapping status: $e');
    }
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      dynamic response;
      try {
        response = await _apiClient.get(
          'oasis_mobile.api.sales_invoice.get_sales_invoice',
          params: {'name': _salesInvoice.name ?? ''},
        );
      } catch (_) {
        // Fallback: Fetch directly using standard REST resource endpoints
        response = await _apiClient.get(
          '../resource/Sales Invoice/${Uri.encodeComponent(_salesInvoice.name ?? "")}',
        );
      }
      
      final dynamic body = response['message'] ?? response['data'] ?? response;
      if (response['status'] == 'success' || body['status'] == 'success' || body['data'] != null || response['data'] != null) {
        setState(() {
          final data = Map<String, dynamic>.from(body['data'] ?? body);
          _hasWorkflow = response['has_workflow'] ?? body['has_workflow'] ?? false;
          _workflowActions = List<String>.from(response['workflow_actions'] ?? body['workflow_actions'] ?? []);
          _availableActions = List<String>.from(response['available_actions'] ?? body['available_actions'] ?? []);
          _salesInvoice = SalesInvoiceModel.fromJson(data);
          _isLoading = false;
        });
        _fetchMappingStatus();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching sales invoice details: $e');
      setState(() => _isLoading = false);
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
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.sales_invoice.apply_workflow_action',
        {
          'name': _salesInvoice.name ?? '',
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Workflow Error'),
            content: SingleChildScrollView(
              child: Text(
                _cleanHtml(e.toString().replaceAll('Exception: ', '')),
                style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.4),
              ),
            ),
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

  Future<void> _deleteInvoice() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Document', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to permanently delete this Sales Invoice?', style: GoogleFonts.plusJakartaSans()),
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
      dynamic response;
      try {
        response = await _apiClient.post(
          'oasis_mobile.api.sales_invoice.delete_sales_invoice',
          {'name': _salesInvoice.name ?? ''},
        );
      } catch (_) {
        // Fallback: Use direct resource DELETE
        response = await _apiClient.post(
          '../method/frappe.client.delete',
          {'doctype': 'Sales Invoice', 'name': _salesInvoice.name ?? ''},
        );
      }

      final status = response['status'] ?? response['message']?['status'] ?? response['message'];
      if (status == 'success' || response['message'] == 'success' || response['message'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sales Invoice deleted successfully'), backgroundColor: Colors.redAccent),
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
          SnackBar(content: Text('Error deleting invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _makePaymentEntry() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.mapping.map_sales_invoice_to_payment_entry',
        {'source_name': _salesInvoice.name ?? ''},
      );
      setState(() => _isLoading = false);
      Map<String, dynamic>? mappedData;
      String? errorMessage;
      
      if (response is Map) {
        final message = response['message'];
        if (message is Map) {
          if (message['status'] == 'error') {
            errorMessage = message['message']?.toString();
          } else if (message['status'] == 'success') {
            final d = message['data'];
            if (d is Map) {
              mappedData = Map<String, dynamic>.from(d);
            }
          } else {
            mappedData = Map<String, dynamic>.from(message);
          }
        } else if (response['status'] == 'error') {
          errorMessage = response['message']?.toString();
        } else if (response['status'] == 'success') {
          final d = response['data'];
          if (d is Map) {
            mappedData = Map<String, dynamic>.from(d);
          }
        } else if (response['data'] is Map) {
          mappedData = Map<String, dynamic>.from(response['data']);
        }
      }
      
      if (errorMessage != null) {
        throw errorMessage;
      }
      if (mappedData == null) {
        throw 'Failed to map sales invoice to payment entry';
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentEntryFormScreen(
              initialData: mappedData,
            ),
          ),
        );
        if (result == true) {
          _fetchDetails();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mapping document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitInvoice() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.sales_invoice.submit_sales_invoice',
        {'name': _salesInvoice.name ?? ''},
      );
      final message = response['message'] ?? response;
      final bool isSuccess = response['status'] == 'success' ||
          message['status'] == 'success' ||
          message['docstatus'] == 1 ||
          (message is Map && message['status'] != 'error' && message['message']?.toString().toLowerCase().contains('submitted') == true) ||
          response['data'] != null;

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice submitted successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        _fetchDetails();
      } else {
        throw Exception(message['message'] ?? 'Submission failed.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Submit Error'),
            content: Text(_cleanHtml(e.toString().replaceAll('Exception: ', ''))),
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

  Future<void> _cancelInvoice() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.sales_invoice.cancel_sales_invoice',
        {'name': _salesInvoice.name ?? ''},
      );
      final message = response['message'] ?? response;
      if (response['status'] == 'success' || message['status'] == 'success' || response['data'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cancelled successfully!'), backgroundColor: Colors.amber),
        );
        _fetchDetails();
      } else {
        throw Exception(message['message'] ?? 'Cancellation failed.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Error'),
            content: Text(_cleanHtml(e.toString().replaceAll('Exception: ', ''))),
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
          _salesInvoice.name ?? 'SALES INVOICE DETAILS',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
        ),
        actions: [
          if (canEdit(docStatus: _salesInvoice.docstatus ?? 0, workflowActions: _workflowActions, workflowState: _salesInvoice.workflowState))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SalesInvoiceFormScreen(salesInvoice: _salesInvoice),
                  ),
                );
                if (result == true) {
                  _fetchDetails();
                }
              },
            ),
          if (_salesInvoice.docstatus == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteInvoice,
            ),
        ],
      ),
      body: _isLoading
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_salesInvoice.statusColor, _salesInvoice.statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _salesInvoice.statusColor.withOpacity(0.3),
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
                  _salesInvoice.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 28),
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
                '${_salesInvoice.currency} ',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                intl.NumberFormat("#,##0.00").format(_salesInvoice.grandTotal ?? 0.0),
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
          _buildInfoRow('Customer Code', _salesInvoice.customer),
          _buildInfoRow('Customer Name', _salesInvoice.customerName ?? ''),
          _buildInfoRow('Posting Date', _salesInvoice.postingDate),
          _buildInfoRow('Due Date', _salesInvoice.dueDate),
          _buildInfoRow('Outstanding Amount', '${_salesInvoice.currency} ${intl.NumberFormat("#,##0.00").format(_salesInvoice.outstandingAmount)}'),
          _buildInfoRow('Price List', _salesInvoice.sellingPriceList),
          _buildInfoRow('Quote Type', _salesInvoice.customQuoteType ?? 'Retail'),
          if (_salesInvoice.customQuoteType == 'Retail')
            _buildInfoRow('Retail Quote Type', _salesInvoice.customRetailQuoteType ?? ''),
          if (_salesInvoice.customPreparedBy != null && _salesInvoice.customPreparedBy!.isNotEmpty)
            _buildInfoRow('Prepared By', _salesInvoice.customPreparedBy!),
          if (_salesInvoice.customVerifiedBy != null && _salesInvoice.customVerifiedBy!.isNotEmpty)
            _buildInfoRow('Verified By', _salesInvoice.customVerifiedBy!),
          if (_salesInvoice.customApprovedBy != null && _salesInvoice.customApprovedBy!.isNotEmpty)
            _buildInfoRow('Approved By', _salesInvoice.customApprovedBy!),
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
            itemCount: _salesInvoice.items.length,
            itemBuilder: (context, index) {
              final item = _salesInvoice.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.widgets_outlined, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName ?? item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${item.qty.toStringAsFixed(0)} ${item.uom} x ${_salesInvoice.currency} ${intl.NumberFormat("#,##0.00").format(item.rate)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text('${_salesInvoice.currency} ${intl.NumberFormat("#,##0.00").format(item.amount ?? (item.qty * item.rate))}',
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
    List<Widget> buttons = [];
    final docstatus = _salesInvoice.docstatus ?? 0;
    final bool isCompleted = _mappingStatus?['is_completed'] ?? false;

    if (isCompleted) {
      buttons.add(
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              _mappingStatus?['message'] ?? 'Sales Invoice Fully Processed',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    } else if (_availableActions.isNotEmpty) {
      // Render strictly based on available_actions returned by the API
      for (var action in _availableActions) {
        if (action == 'Submit') {
          buttons.add(
            _buildActionButton('SUBMIT', const Color(0xFF8B5CF6), _submitInvoice),
          );
        } else if (action == 'Cancel') {
          buttons.add(
            _buildActionButton('CANCEL', Colors.redAccent, _cancelInvoice),
          );
        } else if (action == 'Make Payment Entry') {
          if ((_salesInvoice.outstandingAmount ?? 0) > 0) {
            buttons.add(
              _buildActionButton(
                'MAKE PAYMENT ENTRY',
                const Color(0xFF10B981),
                _makePaymentEntry,
              ),
            );
          }
        } else {
          Color btnColor = const Color(0xFF8B5CF6);
          if (action.toLowerCase().contains('reject') || action.toLowerCase().contains('cancel')) {
            btnColor = Colors.redAccent;
          }
          buttons.add(_buildActionButton(action, btnColor, () => _applyAction(action)));
        }
      }
    } else {
      // Fallback: standard static docstatus mode
      if (docstatus == 1) {
        // Fully submitted — show MAKE PAYMENT ENTRY if outstanding, always show CANCEL
        if ((_salesInvoice.outstandingAmount ?? 0) > 0) {
          buttons.add(
            _buildActionButton(
              'MAKE PAYMENT ENTRY',
              const Color(0xFF10B981),
              _makePaymentEntry,
            ),
          );
        }
        if (!_hasWorkflow) {
          // Standard docstatus mode: show CANCEL
          buttons.add(
            _buildActionButton('CANCEL', Colors.redAccent, _cancelInvoice),
          );
        } else {
          // Workflow mode: show remaining non-approval workflow actions (e.g. Cancel, Amend)
          for (var action in _workflowActions) {
            final actLower = action.toLowerCase();
            if (actLower.contains('approve') || actLower.contains('verify') || actLower == 'verified' || actLower.contains('submit')) {
              continue; // skip redundant approval actions
            }
            Color btnColor = const Color(0xFF8B5CF6);
            if (actLower.contains('reject') || actLower.contains('cancel')) btnColor = Colors.redAccent;
            buttons.add(_buildActionButton(action, btnColor, () => _applyAction(action)));
          }
        }
      } else if (docstatus == 0) {
        if (_hasWorkflow) {
          // Draft in workflow — show all workflow actions
          for (var action in _workflowActions) {
            final actLower = action.toLowerCase();
            Color btnColor = const Color(0xFF8B5CF6);
            if (actLower.contains('reject') || actLower.contains('cancel')) btnColor = Colors.redAccent;
            if (actLower.contains('verify') || actLower.contains('approve') || actLower == 'verified') btnColor = const Color(0xFF10B981);
            buttons.add(_buildActionButton(action, btnColor, () => _applyAction(action)));
          }
        } else {
          // Standard docstatus mode: show SUBMIT
          buttons.add(
            _buildActionButton('SUBMIT', const Color(0xFF8B5CF6), _submitInvoice),
          );
        }
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  String _cleanHtml(String html) {
    String clean = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<li>'), '\n• ')
        .replaceAll(RegExp(r'</li>'), '')
        .replaceAll(RegExp(r'<ul>|</ul>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '')
        .trim();
    while (clean.contains('  ')) {
      clean = clean.replaceAll('  ', ' ');
    }
    return clean;
  }
}
