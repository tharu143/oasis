import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/widgets/workflow_action_bar.dart';
import 'package:oasis/features/delivery_note/models/delivery_note_model.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_form_screen.dart';
import 'package:oasis/core/services/role_helper.dart';
import 'delivery_note_form_screen.dart';

class DeliveryNoteDetailScreen extends StatefulWidget {
  final DeliveryNoteModel deliveryNote;

  const DeliveryNoteDetailScreen({super.key, required this.deliveryNote});

  @override
  State<DeliveryNoteDetailScreen> createState() => _DeliveryNoteDetailScreenState();
}

class _DeliveryNoteDetailScreenState extends State<DeliveryNoteDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late DeliveryNoteModel _deliveryNote;
  List<String> _workflowActions = [];
  List<String> _availableActions = [];
  bool _isLoading = false;
  String? _userActionState;

  @override
  void initState() {
    super.initState();
    _deliveryNote = widget.deliveryNote;
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
        'oasis_mobile.api.delivery_note.get_delivery_note',
        params: {'name': _deliveryNote.name ?? ''},
      );
      
      final dynamic body = response['message'] ?? response['data'] ?? response;
      if (response['status'] == 'success' || body['status'] == 'success' || body['data'] != null) {
        setState(() {
          final data = Map<String, dynamic>.from(body['data'] ?? {});
          _workflowActions = List<String>.from(body['workflow_actions'] ?? []);
          _availableActions = List<String>.from(body['available_actions'] ?? []);
          _deliveryNote = DeliveryNoteModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching delivery note details: $e');
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
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.delivery_note.apply_workflow_action',
        {
          'name': _deliveryNote.name ?? '',
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

  Future<void> _deleteNote() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Document', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to permanently delete this Delivery Note?', style: GoogleFonts.plusJakartaSans()),
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
        'oasis_mobile.api.delivery_note.delete_delivery_note',
        {'name': _deliveryNote.name ?? ''},
      );

      final status = response['status'] ?? response['message']?['status'];
      if (status == 'success' || response['message'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery Note deleted successfully'), backgroundColor: Colors.redAccent),
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
          SnackBar(content: Text('Error deleting note: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _makeSalesInvoice() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.mapping.map_delivery_note_to_sales_invoice',
        {'source_name': _deliveryNote.name ?? ''},
      );
      setState(() => _isLoading = false);
      if (response['message'] != null) {
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SalesInvoiceFormScreen(
                initialData: Map<String, dynamic>.from(response['message']),
              ),
            ),
          );
          if (result == true) {
            _fetchDetails();
          }
        }
      } else {
        throw 'Failed to map delivery note to sales invoice';
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
          _deliveryNote.name ?? 'DELIVERY NOTE DETAILS',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
        ),
        actions: [
          if (canEdit(docStatus: _deliveryNote.docstatus, workflowActions: _workflowActions, workflowState: _deliveryNote.workflowState))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeliveryNoteFormScreen(deliveryNote: _deliveryNote),
                  ),
                );
                if (result == true) {
                  _fetchDetails();
                }
              },
            ),
          if (_deliveryNote.docstatus == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteNote,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
    final stateColor = workflowStateColor(_deliveryNote.workflowState ?? 'Draft');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [stateColor, stateColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: stateColor.withOpacity(0.3),
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
                  _deliveryNote.workflowState ?? 'Draft',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
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
                '${_deliveryNote.currency} ',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                intl.NumberFormat("#,##0.00").format(_deliveryNote.grandTotal ?? 0.0),
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
          _buildInfoRow('Customer Code', _deliveryNote.customer),
          _buildInfoRow('Customer Name', _deliveryNote.customerName ?? ''),
          _buildInfoRow('Posting Date', _deliveryNote.postingDate),
          _buildInfoRow('Posting Time', _deliveryNote.postingTime),
          _buildInfoRow('Price List', _deliveryNote.sellingPriceList),
          _buildInfoRow('Quote Type', _deliveryNote.customQuoteType ?? 'Retail'),
          if (_deliveryNote.customQuoteType == 'Retail')
            _buildInfoRow('Retail Quote Type', _deliveryNote.customRetailQuoteType ?? ''),
          if (_deliveryNote.customPreparedBy != null && _deliveryNote.customPreparedBy!.isNotEmpty)
            _buildInfoRow('Prepared By', _deliveryNote.customPreparedBy!),
          if (_deliveryNote.customVerifiedBy != null && _deliveryNote.customVerifiedBy!.isNotEmpty)
            _buildInfoRow('Verified By', _deliveryNote.customVerifiedBy!),
          if (_deliveryNote.customApprovedBy != null && _deliveryNote.customApprovedBy!.isNotEmpty)
            _buildInfoRow('Approved By', _deliveryNote.customApprovedBy!),
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
            itemCount: _deliveryNote.items.length,
            itemBuilder: (context, index) {
              final item = _deliveryNote.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.widgets_outlined, color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName ?? item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${item.qty.toStringAsFixed(0)} ${item.uom} x ${_deliveryNote.currency} ${intl.NumberFormat("#,##0.00").format(item.rate)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text('${_deliveryNote.currency} ${intl.NumberFormat("#,##0.00").format(item.amount ?? (item.qty * item.rate))}',
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
    if (_availableActions.contains('Make Sales Invoice')) {
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
            children: [
              Expanded(
                child: _buildActionButton(
                  'MAKE SALES INVOICE',
                  const Color(0xFF8B5CF6),
                  _makeSalesInvoice,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: WorkflowActionBar(
        workflowActions: _workflowActions,
        currentState: _deliveryNote.workflowState ?? 'Draft',
        docStatus: _deliveryNote.docstatus,
        isLoading: _isLoading,
        onAction: (action) => _applyAction(action),
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
