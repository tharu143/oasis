import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/sales_order/models/sales_order_model.dart';
import 'package:oasis/features/sales_order/presentation/screens/sales_order_form_screen.dart';
import 'package:oasis/features/material_request/presentation/screens/material_request_form_screen.dart';
import 'package:oasis/features/delivery_note/presentation/screens/delivery_note_form_screen.dart';
import 'package:oasis/core/services/role_helper.dart';

class SalesOrderDetailScreen extends StatefulWidget {
  final SalesOrderModel salesOrder;

  const SalesOrderDetailScreen({super.key, required this.salesOrder});

  @override
  State<SalesOrderDetailScreen> createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late SalesOrderModel _salesOrder;
  List<dynamic> _paymentSchedule = [];
  List<String> _workflowActions = [];
  List<String> _availableActions = [];
  bool _isLoading = false;
  String? _userActionState;

  @override
  void initState() {
    super.initState();
    _salesOrder = widget.salesOrder;
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

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.sales_order.get_sales_order',
        params: {'name': _salesOrder.name ?? ''},
      );
      if (response['status'] == 'success' || response['message'] != null) {
        final message = response['message'] ?? response;
        setState(() {
          final data = Map<String, dynamic>.from(message['data'] ?? {});
          _workflowActions = List<String>.from(message['workflow_actions'] ?? []);
          _availableActions = List<String>.from(message['available_actions'] ?? []);
          _paymentSchedule = List<dynamic>.from(data['payment_schedule'] ?? []);
          _salesOrder = SalesOrderModel.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching sales order details: $e');
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
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.sales_order.apply_workflow_action',
        {
          'name': _salesOrder.name ?? '',
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
        throw message['message'] ?? 'Action application failed';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildModernHeader(context),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      height: 72,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          labelColor: const Color(0xFF10B981),
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12),
                          tabs: const [
                            Tab(text: 'General'),
                            Tab(text: 'Commercial'),
                            Tab(text: 'Audit Log'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildGeneralTab(),
                  _buildCommercialTab(),
                  _buildAuditTab(),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.white24,
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
              ),
            _buildFloatingBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [const Color(0xFF10B981), const Color(0xFF047857)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _salesOrder.statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      (_salesOrder.workflowState ?? 'Draft').toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_salesOrder.currency} ${intl.NumberFormat("#,##0.00").format(_salesOrder.grandTotal ?? 0.0)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _salesOrder.name ?? '',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (canEdit(docStatus: _salesOrder.docstatus, workflowActions: _workflowActions, workflowState: _salesOrder.workflowState))
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white, size: 22),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalesOrderFormScreen(salesOrder: _salesOrder),
                ),
              );
              if (result == true) {
                _fetchDetails();
              }
            },
          ),
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 22), onPressed: _fetchDetails),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        _buildSectionCard('Customer Details', [
          _buildInfoRow('Customer Name', _salesOrder.customerName ?? 'N/A'),
          if (_salesOrder.customerNameInArabic != null && _salesOrder.customerNameInArabic!.isNotEmpty)
            _buildInfoRow('Arabic Customer Name', _salesOrder.customerNameInArabic!),
          _buildInfoRow('Customer Code', _salesOrder.customer),
          _buildInfoRow('Quote Type', _salesOrder.customQuoteType ?? 'N/A'),
          if (_salesOrder.customQuoteType == 'Retail')
            _buildInfoRow('Retail Quote Type', _salesOrder.customRetailQuoteType ?? 'N/A'),
        ]),
        const SizedBox(height: 16),
        _buildSectionCard('Order Information', [
          _buildInfoRow('Subject', _salesOrder.customSubject ?? 'N/A'),
          _buildInfoRow('Reference', _salesOrder.customRef ?? 'N/A'),
          _buildInfoRow('Order Type', _salesOrder.orderType),
          _buildInfoRow('Transaction Date', _salesOrder.transactionDate),
          _buildInfoRow('Delivery Date', _salesOrder.deliveryDate),
          _buildInfoRow('Selling Price List', _salesOrder.sellingPriceList),
        ]),
        const SizedBox(height: 16),
        _buildItemsCard(),
      ],
    );
  }

  Widget _buildCommercialTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        if (_salesOrder.customTermsDetailsArabic != null && _salesOrder.customTermsDetailsArabic!.isNotEmpty)
          _buildSectionCard('Terms & Conditions (Arabic)', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _cleanHtml(_salesOrder.customTermsDetailsArabic!),
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ]),
        const SizedBox(height: 16),
        _buildPaymentScheduleCard(),
      ],
    );
  }

  Widget _buildAuditTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        _buildSectionCard('Audit Information', [
          _buildInfoRow('Prepared By', _salesOrder.customPreparedBy ?? 'N/A'),
          _buildInfoRow('Verified By', _salesOrder.customVerifiedBy ?? 'N/A'),
          _buildInfoRow('Approved By', _salesOrder.customApprovedBy ?? 'N/A'),
        ]),
        const SizedBox(height: 16),
        _buildSectionCard('Available Actions', _availableActions.isEmpty 
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No further document flows available in current state.', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                )
              ]
            : _availableActions.map((action) => ListTile(
                leading: const Icon(Icons.arrow_circle_right_outlined, color: Color(0xFF10B981)),
                title: Text(action, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              )).toList()),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
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
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          ...children,
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
            itemCount: _salesOrder.items.length,
            itemBuilder: (context, index) {
              final item = _salesOrder.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.widgets_outlined, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName ?? item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${item.qty.toStringAsFixed(0)} ${item.uom} x ${_salesOrder.currency} ${intl.NumberFormat("#,##0.00").format(item.rate)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text('${_salesOrder.currency} ${intl.NumberFormat("#,##0.00").format(item.amount ?? (item.qty * item.rate))}',
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

  Widget _buildPaymentScheduleCard() {
    if (_paymentSchedule.isEmpty) return const SizedBox.shrink();
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
            'Payment Schedule Breakdown',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          ..._paymentSchedule.map((milestone) {
            final double portion = (milestone['invoice_portion'] ?? 0.0).toDouble();
            final double amount = (milestone['payment_amount'] ?? 0.0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${portion.toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(milestone['payment_term'] ?? 'Milestone Portion', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        if (milestone['description'] != null && milestone['description'].toString().isNotEmpty)
                          Text(milestone['description'], style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    '${_salesOrder.currency} ${intl.NumberFormat("#,##0.00").format(amount)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _makeMaterialRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.mapping.map_sales_order_to_material_request',
        {'source_name': _salesOrder.name ?? ''},
      );
      setState(() => _isLoading = false);
      if (response['message'] != null) {
        if (mounted) {
          final mappedData = Map<String, dynamic>.from(response['message']);
          final itemsList = mappedData['items'] as List?;
          if (itemsList == null || itemsList.isEmpty) {
            mappedData['items'] = _salesOrder.items.map((soItem) {
              return {
                'item_code': soItem.itemCode,
                'item_name': soItem.itemName ?? soItem.itemCode,
                'qty': soItem.qty,
                'uom': soItem.uom,
                'rate': soItem.rate,
                'amount': soItem.amount ?? (soItem.qty * soItem.rate),
                'conversion_factor': 1.0,
                'stock_uom': soItem.uom,
                'stock_qty': soItem.qty,
              };
            }).toList();
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialRequestFormScreen(
                initialData: mappedData,
              ),
            ),
          );
          if (result == true) {
            _fetchDetails();
          }
        }
      } else {
        throw 'Failed to map sales order to material request';
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

  Future<void> _makeDeliveryNote() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.mapping.map_sales_order_to_delivery_note',
        {'source_name': _salesOrder.name ?? ''},
      );
      setState(() => _isLoading = false);
      if (response['message'] != null) {
        if (mounted) {
          final mappedData = Map<String, dynamic>.from(response['message']);
          final itemsList = mappedData['items'] as List?;
          if (itemsList == null || itemsList.isEmpty) {
            mappedData['items'] = _salesOrder.items.map((soItem) {
              return {
                'item_code': soItem.itemCode,
                'item_name': soItem.itemName ?? soItem.itemCode,
                'qty': soItem.qty,
                'rate': soItem.rate,
                'amount': soItem.amount ?? (soItem.qty * soItem.rate),
                'price_list_rate': soItem.rate,
                'base_price_list_rate': soItem.rate,
                'base_rate': soItem.rate,
                'base_amount': soItem.amount ?? (soItem.qty * soItem.rate),
                'discount_percentage': 0.0,
                'discount_amount': 0.0,
                'net_rate': soItem.rate,
                'net_amount': soItem.amount ?? (soItem.qty * soItem.rate),
                'stock_qty': soItem.qty,
                'conversion_factor': 1.0,
                'uom': soItem.uom,
                'stock_uom': soItem.uom,
              };
            }).toList();
          }

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
      } else {
        throw 'Failed to map sales order to delivery note';
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

  Widget _buildFloatingBottomActions() {
    final state = (_salesOrder.workflowState ?? '').toLowerCase();
    // docstatus == 1 means the document is fully submitted/approved (workflow complete)
    final bool isFullyApproved = _salesOrder.docstatus == 1;

    List<Widget> buttons = [];

    // If the document is fully approved (docstatus == 1), ALWAYS show transition buttons
    if (isFullyApproved) {
      buttons.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildActionButton(
              'MAKE MATERIAL REQUEST',
              const Color(0xFF06B6D4),
              Colors.white,
              onTap: _makeMaterialRequest,
            ),
          ),
        ),
      );
      if (_availableActions.contains('Make Delivery Note')) {
        buttons.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildActionButton(
                'MAKE DELIVERY NOTE',
                const Color(0xFF8B5CF6),
                Colors.white,
                onTap: _makeDeliveryNote,
              ),
            ),
          ),
        );
      }
    } else {
      // Document still in workflow - show the workflow action buttons
      if (state.contains('pending')) {
        // Pending state: show Reject (outlined red) + Verify (green)
        String? verifyAction;
        String? rejectAction;
        for (var action in _workflowActions) {
          final actLower = action.toLowerCase();
          if (actLower.contains('verify') || actLower.contains('approve') || actLower == 'verified') {
            verifyAction = action;
          } else if (actLower.contains('reject')) {
            rejectAction = action;
          }
        }
        verifyAction ??= _workflowActions.isNotEmpty ? _workflowActions.first : null;

        if (rejectAction != null) {
          buttons.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildActionButton(
                  rejectAction.toUpperCase(),
                  Colors.white,
                  Colors.red,
                  borderColor: Colors.red,
                  onTap: () => _applyAction(rejectAction!),
                ),
              ),
            ),
          );
        }
        if (verifyAction != null) {
          buttons.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildActionButton(
                  verifyAction.toUpperCase(),
                  const Color(0xFF10B981),
                  Colors.white,
                  onTap: () => _applyAction(verifyAction!),
                ),
              ),
            ),
          );
        }
      } else {
        // Other workflow states: map all available actions
        for (var action in _workflowActions) {
          final actLower = action.toLowerCase();
          bool isSuccess = actLower.contains('approve') || actLower.contains('verify') || actLower.contains('review') || actLower.contains('submit');
          bool isReject = actLower.contains('reject') || actLower.contains('cancel');
          Color bgColor = AppColors.primary;
          if (isSuccess) bgColor = const Color(0xFF10B981);
          if (isReject) bgColor = const Color(0xFFEF4444);

          buttons.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildActionButton(
                  action.toUpperCase(),
                  bgColor,
                  Colors.white,
                  onTap: () => _applyAction(action),
                ),
              ),
            ),
          );
        }
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: buttons,
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, Color bgColor, Color textColor, {Color? borderColor, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
            boxShadow: bgColor != Colors.transparent && bgColor != Colors.white
                ? [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: Text(title, style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  String _cleanHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').trim();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _SliverAppBarDelegate({required this.child, required this.height});
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
