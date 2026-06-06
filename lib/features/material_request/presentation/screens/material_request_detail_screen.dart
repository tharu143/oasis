import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/core/widgets/workflow_action_bar.dart';
import 'package:oasis/core/services/role_helper.dart';
import 'package:oasis/features/delivery_note/presentation/screens/delivery_note_form_screen.dart';
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
  List<String> _workflowActions = [];
  List<String> _availableActions = [];
  String? _userActionState;
  Map<String, dynamic>? _mappingStatus;

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
    final docState = (workflowState == null || workflowState.isEmpty) ? 'Draft' : workflowState;
    if (docState.toLowerCase() == 'draft') return true;
    if (workflowActions.isEmpty) return false;
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

  Future<void> _fetchMappingStatus() async {
    try {
      final res = await _apiClient.post(
        'oasis_mobile.api.mapping.check_mapping_status',
        {
          'doctype': 'Material Request',
          'docname': widget.materialRequest.name ?? '',
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
      final res = await _apiClient.get(
        'oasis_mobile.api.material_request.get_material_request',
        params: {'name': widget.materialRequest.name ?? ''},
      );

      if (res['status'] == 'success' || res['message'] != null) {
        final message = res['message'] ?? res;
        setState(() {
          final docData = Map<String, dynamic>.from(message['data'] ?? {});
          final List<dynamic> actions = message['workflow_actions'] ?? [];
          final List<dynamic> avActions = message['available_actions'] ?? [];
          _details = MaterialRequestModel.fromJson(docData);
          _workflowActions = actions.map((e) => e.toString()).toList();
          _availableActions = avActions.map((e) => e.toString()).toList();
          _isLoading = false;
        });
        _fetchMappingStatus();
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
        if (canEdit(docStatus: doc.docstatus, workflowActions: _workflowActions, workflowState: doc.workflowState))
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
        if (doc.docstatus == 0)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deleteRequest,
          ),
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
    final bool isCompleted = _mappingStatus?['is_completed'] ?? false;
    final bool showMakeDeliveryNote = (doc.workflowState?.toLowerCase() == 'approved by md') ||
                                      (doc.docstatus == 1 && _availableActions.contains('Make Delivery Note'));

    if (showMakeDeliveryNote) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: isCompleted
                  ? Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          _mappingStatus?['message'] ?? 'Material Request Fully Processed',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: _isLoading ? null : () => _makeDeliveryNote(doc),
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'MAKE DELIVERY NOTE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return WorkflowActionBar(
      workflowActions: _workflowActions,
      currentState: doc.workflowState ?? 'Draft',
      docStatus: doc.docstatus,
      isLoading: _isLoading,
      onAction: (action) => _applyWorkflowAction(action),
    );
  }

  Future<void> _makeDeliveryNote(MaterialRequestModel doc) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.mapping.map_material_request_to_delivery_note',
        {'source_name': doc.name ?? ''},
      );
      setState(() => _isLoading = false);

      Map<String, dynamic> mappedData;
      String? status;
      dynamic extractedData;
      
      if (response is Map) {
        status = response['status']?.toString();
        extractedData = response['data'];
        
        final message = response['message'];
        if (message is Map) {
          status ??= message['status']?.toString();
          extractedData ??= message['data'] ?? message;
        }
      }
      
      if (status == 'success' && extractedData is Map) {
        mappedData = Map<String, dynamic>.from(extractedData);
      } else {
        throw 'API mapping returned failure';
      }

      // If backend succeeds, but items list is empty, fall back to mapping items from doc
      final itemsList = mappedData['items'] as List?;
      if (itemsList == null || itemsList.isEmpty) {
        mappedData['items'] = doc.items.map((item) {
          return {
            'item_code': item.itemCode,
            'item_name': item.itemName ?? item.itemCode,
            'qty': item.qty,
            'rate': 0.0,
            'amount': 0.0,
            'price_list_rate': 0.0,
            'base_price_list_rate': 0.0,
            'base_rate': 0.0,
            'base_amount': 0.0,
            'net_rate': 0.0,
            'net_amount': 0.0,
            'stock_qty': item.stockQty,
            'conversion_factor': item.conversionFactor,
            'uom': item.uom,
            'stock_uom': item.stockUom,
            'material_request': doc.name,
          };
        }).toList();
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryNoteFormScreen(
              initialData: mappedData,
            ),
          ),
        );
        if (result == true) {
          _fetchDetails();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Backend mapper failed, using local client mapping: $e');
      final Map<String, dynamic> localMappedData = {
        'company': doc.company,
        'customer': doc.customCustomer ?? '',
        'custom_quote_type': 'Retail',
        'custom_retail_quote_type': 'Supply Only',
        'material_request': doc.name,
        'items': doc.items.map((item) {
          return {
            'item_code': item.itemCode,
            'item_name': item.itemName ?? item.itemCode,
            'qty': item.qty,
            'rate': 0.0,
            'amount': 0.0,
            'price_list_rate': 0.0,
            'base_price_list_rate': 0.0,
            'base_rate': 0.0,
            'base_amount': 0.0,
            'net_rate': 0.0,
            'net_amount': 0.0,
            'stock_qty': item.stockQty,
            'conversion_factor': item.conversionFactor,
            'uom': item.uom,
            'stock_uom': item.stockUom,
            'material_request': doc.name,
          };
        }).toList(),
      };

      setState(() => _isLoading = false);
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryNoteFormScreen(
              initialData: localMappedData,
            ),
          ),
        );
        if (result == true) {
          _fetchDetails();
        }
      }
    }
  }
}
