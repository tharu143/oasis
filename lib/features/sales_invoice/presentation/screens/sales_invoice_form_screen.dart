import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/sales_invoice_model.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_detail_screen.dart';

class SalesInvoiceFormScreen extends StatefulWidget {
  final SalesInvoiceModel? salesInvoice;
  final Map<String, dynamic>? initialData;
  const SalesInvoiceFormScreen({super.key, this.salesInvoice, this.initialData});

  @override
  State<SalesInvoiceFormScreen> createState() => _SalesInvoiceFormScreenState();
}

class _SalesInvoiceFormScreenState extends State<SalesInvoiceFormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  Map<String, dynamic> _doc = {};

  // Form Field Controllers
  late TextEditingController _customerNameController;
  late TextEditingController _preparedByController;
  late TextEditingController _verifiedByController;
  late TextEditingController _approvedByController;
  late TextEditingController _specialDiscountController;

  // Animation Controllers for recalculation bounce
  late AnimationController _totalsAnimController;
  late Animation<double> _totalsScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _totalsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _totalsScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.06).chain(CurveTween(curve: Curves.easeOutBack)), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.06, end: 0.97).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.97, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 25),
    ]).animate(_totalsAnimController);

    _initializeForm();
  }

  void _initializeForm() {
    String todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String todayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    if (widget.salesInvoice != null) {
      final si = widget.salesInvoice!;
      _doc = {
        'name': si.name,
        'customer': si.customer,
        'customer_name': si.customerName ?? '',
        'posting_date': si.postingDate.isNotEmpty ? si.postingDate : todayDateStr,
        'due_date': si.dueDate.isNotEmpty ? si.dueDate : todayDateStr,
        'posting_time': si.postingTime.isNotEmpty ? si.postingTime : todayTimeStr,
        'currency': si.currency.isNotEmpty ? si.currency : 'QAR',
        'conversion_rate': si.conversionRate,
        'selling_price_list': si.sellingPriceList.isNotEmpty ? si.sellingPriceList : 'Standard Selling',
        'price_list_currency': si.priceListCurrency.isNotEmpty ? si.priceListCurrency : 'QAR',
        'plc_conversion_rate': si.plcConversionRate,
        'custom_quote_type': si.customQuoteType ?? 'Retail',
        'custom_retail_quote_type': si.customRetailQuoteType ?? 'Supply Only',
        'custom_prepared_by': si.customPreparedBy ?? '',
        'custom_verified_by': si.customVerifiedBy ?? '',
        'custom_approved_by': si.customApprovedBy ?? '',
        'grand_total': si.grandTotal ?? 0.0,
        'net_total': si.netTotal ?? 0.0,
        'items': si.items.map((e) => e.toJson()).toList(),
        'payment_terms_template': '',
        'payment_schedule': <Map<String, dynamic>>[],
        'company': 'Oasis Trading and Importing HVAC',
        'total_qty': si.items.fold<double>(0, (sum, item) => sum + item.qty),
      };
    } else if (widget.initialData != null) {
      final cleaned = Map<String, dynamic>.from(widget.initialData!);
      final systemKeys = [
        'name', 'creation', 'modified', 'modified_by', 'owner', 'docstatus',
        'idx', 'amended_from', 'workflow_state', 'workflow_actions', 'status',
        'custom_prepared_by', 'custom_prepared_by_name',
        'custom_verified_by', 'custom_verified_by_name',
        'custom_approved_by', 'custom_approved_by_name',
        'custom_prepared_by_role'
      ];
      for (var key in systemKeys) {
        cleaned.remove(key);
      }
      if (cleaned['items'] is List) {
        cleaned['items'] = (cleaned['items'] as List).map((item) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          final itemSystemKeys = [
            'name', 'parent', 'parentfield', 'parenttype',
            'creation', 'modified', 'modified_by', 'owner', 'docstatus', 'idx'
          ];
          for (var key in itemSystemKeys) {
            itemMap.remove(key);
          }
          // Safe numeric casting — prevents TypeError when backend sends int for double fields
          itemMap['qty'] = (itemMap['qty'] as num? ?? 0.0).toDouble();
          itemMap['rate'] = (itemMap['rate'] as num? ?? 0.0).toDouble();
          itemMap['amount'] = (itemMap['amount'] as num? ?? 0.0).toDouble();
          itemMap['price_list_rate'] = (itemMap['price_list_rate'] as num? ?? 0.0).toDouble();
          itemMap['base_price_list_rate'] = (itemMap['base_price_list_rate'] as num? ?? 0.0).toDouble();
          itemMap['base_rate'] = (itemMap['base_rate'] as num? ?? 0.0).toDouble();
          itemMap['base_amount'] = (itemMap['base_amount'] as num? ?? 0.0).toDouble();
          itemMap['discount_percentage'] = (itemMap['discount_percentage'] as num? ?? 0.0).toDouble();
          itemMap['discount_amount'] = (itemMap['discount_amount'] as num? ?? 0.0).toDouble();
          itemMap['net_rate'] = (itemMap['net_rate'] as num? ?? 0.0).toDouble();
          itemMap['net_amount'] = (itemMap['net_amount'] as num? ?? 0.0).toDouble();
          itemMap['delivered_qty'] = (itemMap['delivered_qty'] as num? ?? 0.0).toDouble();
          itemMap['billed_amt'] = (itemMap['billed_amt'] as num? ?? 0.0).toDouble();
          itemMap['stock_qty'] = (itemMap['stock_qty'] as num? ?? 0.0).toDouble();
          itemMap['conversion_factor'] = (itemMap['conversion_factor'] as num? ?? 1.0).toDouble();
          return itemMap;
        }).toList();
      }
      _doc = cleaned;
      _doc['company'] ??= 'Oasis Trading and Importing HVAC';
      _doc['customer'] ??= '';
      _doc['customer_name'] ??= '';
      _doc['posting_date'] ??= todayDateStr;
      _doc['due_date'] ??= todayDateStr;
      _doc['posting_time'] ??= todayTimeStr;
      _doc['currency'] ??= 'QAR';
      _doc['conversion_rate'] ??= 1.0;
      _doc['selling_price_list'] ??= 'Standard Selling';
      _doc['price_list_currency'] ??= 'QAR';
      _doc['plc_conversion_rate'] ??= 1.0;
      _doc['custom_quote_type'] ??= 'Retail';
      _doc['custom_retail_quote_type'] ??= 'Supply Only';
      _doc['custom_prepared_by'] ??= '';
      _doc['custom_verified_by'] ??= '';
      _doc['custom_approved_by'] ??= '';
      _doc['grand_total'] ??= 0.0;
      _doc['net_total'] ??= 0.0;
      _doc['items'] ??= <Map<String, dynamic>>[];
      _doc['payment_terms_template'] ??= '';
      _doc['payment_schedule'] ??= <Map<String, dynamic>>[];
      _doc['total_qty'] ??= 0.0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateTotals();
      });
    } else {
      _doc = {
        'company': 'Oasis Trading and Importing HVAC',
        'customer': '',
        'customer_name': '',
        'posting_date': todayDateStr,
        'due_date': todayDateStr,
        'posting_time': todayTimeStr,
        'currency': 'QAR',
        'conversion_rate': 1.0,
        'selling_price_list': 'Standard Selling',
        'price_list_currency': 'QAR',
        'plc_conversion_rate': 1.0,
        'custom_quote_type': 'Retail',
        'custom_retail_quote_type': 'Supply Only',
        'custom_prepared_by': '',
        'custom_verified_by': '',
        'custom_approved_by': '',
        'grand_total': 0.0,
        'net_total': 0.0,
        'items': <Map<String, dynamic>>[],
        'payment_terms_template': '',
        'payment_schedule': <Map<String, dynamic>>[],
        'total_qty': 0.0,
      };
    }

    _setupControllers();
  }

  void _setupControllers() {
    _customerNameController = TextEditingController(text: _doc['customer_name']);
    _preparedByController = TextEditingController(text: _doc['custom_prepared_by']);
    _verifiedByController = TextEditingController(text: _doc['custom_verified_by']);
    _approvedByController = TextEditingController(text: _doc['custom_approved_by']);
    _specialDiscountController = TextEditingController(text: (_doc['discount_amount'] ?? 0.0).toString());

    _customerNameController.addListener(() => _doc['customer_name'] = _customerNameController.text);
    _preparedByController.addListener(() => _doc['custom_prepared_by'] = _preparedByController.text);
    _verifiedByController.addListener(() => _doc['custom_verified_by'] = _verifiedByController.text);
    _approvedByController.addListener(() => _doc['custom_approved_by'] = _approvedByController.text);
    _specialDiscountController.addListener(_recalculateTotals);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _preparedByController.dispose();
    _verifiedByController.dispose();
    _approvedByController.dispose();
    _specialDiscountController.dispose();
    _totalsAnimController.dispose();
    super.dispose();
  }

  void _recalculateTotals() {
    double totalQty = 0;
    double netTotal = 0;

    final itemsList = _doc['items'] as List<dynamic>? ?? [];
    for (var item in itemsList) {
      final qty = (item['qty'] as num? ?? 0.0).toDouble();
      final rate = (item['rate'] as num? ?? 0.0).toDouble();
      final discountAmount = (item['discount_amount'] as num? ?? 0.0).toDouble();
      final netRate = rate - discountAmount;
      item['net_rate'] = netRate;
      item['amount'] = qty * netRate;
      totalQty += qty;
      netTotal += qty * netRate;
    }

    final discountAmount = double.tryParse(_specialDiscountController.text) ?? 0.0;

    setState(() {
      _doc['total_qty'] = totalQty;
      _doc['net_total'] = netTotal;
      _doc['discount_amount'] = discountAmount;
      _doc['apply_discount_on'] = 'Grand Total';
      _doc['grand_total'] = netTotal - discountAmount;
    });

    _totalsAnimController.forward(from: 0.0);

    if (_doc['payment_terms_template'] != null && _doc['payment_terms_template'].toString().isNotEmpty) {
      _fetchPaymentTermsDetails(_doc['payment_terms_template'].toString(), _doc['grand_total']);
    }
  }

  Future<void> _fetchPaymentTermsDetails(String template, double grandTotal) async {
    try {
      dynamic res;
      try {
        res = await _apiClient.get(
          'oasis_mobile.api.sales_invoice.get_payment_terms_details',
          params: {'template': template, 'grand_total': grandTotal.toString()},
        );
      } catch (_) {
        try {
          res = await _apiClient.get(
            'oasis_mobile.api.delivery_note.get_payment_terms_details',
            params: {'template': template, 'grand_total': grandTotal.toString()},
          );
        } catch (_) {
          res = await _apiClient.get(
            'oasis_mobile.api.sales_order.get_payment_terms_details',
            params: {'template': template, 'grand_total': grandTotal.toString()},
          );
        }
      }

      if (res['status'] == 'success' && res['terms'] != null) {
        setState(() {
          _doc['payment_schedule'] = List<Map<String, dynamic>>.from(res['terms']);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch payment milestones: $e");
    }
  }

  Future<void> _fetchAndAutoFillCustomer(String customerCode) async {
    setState(() => _isLoading = true);
    dynamic data;
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.sales_invoice.get_customer_details',
        params: {'customer': customerCode},
      );
      data = res['status'] == 'success' ? res : (res['message'] ?? res);
    } catch (_) {
      try {
        final res = await _apiClient.get(
          'oasis_mobile.api.delivery_note.get_customer_details',
          params: {'customer': customerCode},
        );
        data = res['status'] == 'success' ? res : (res['message'] ?? res);
      } catch (e) {
        debugPrint('Customer lookup failed, trying direct resource: $e');
        try {
          final res = await _apiClient.get('../resource/Customer/${Uri.encodeComponent(customerCode)}');
          final doc = res['data'];
          if (doc != null) {
            data = {
              'customer_name': doc['customer_name'] ?? doc['name'] ?? customerCode,
            };
          }
        } catch (_) {}
      }
    }

    if (data != null && data['status'] != 'error') {
      setState(() {
        _doc['customer_name'] = data['customer_name'] ?? '';
        _customerNameController.text = _doc['customer_name'];
      });
    } else {
      setState(() {
        _doc['customer_name'] = customerCode;
        _customerNameController.text = customerCode;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSalesInvoice() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please fill out all required fields.'),
        ),
      );
      return;
    }

    if ((_doc['items'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Sales Invoice must contain at least one item.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isEdit = widget.salesInvoice != null;
      dynamic response;
      try {
        final endpoint = isEdit 
            ? 'oasis_mobile.api.sales_invoice.update_sales_invoice'
            : 'oasis_mobile.api.sales_invoice.create_sales_invoice';
        final payload = isEdit 
            ? {'name': _doc['name'], 'data': _doc}
            : {'data': _doc};
        response = await _apiClient.post(endpoint, payload);
      } catch (e) {
        // Fallback: standard REST API resource endpoints via POST frappe.client.save
        debugPrint('Custom save endpoint failed, falling back to standard REST API: $e');
        final payload = {
          'doc': {
            'doctype': 'Sales Invoice',
            ..._doc,
          }
        };
        response = await _apiClient.post('frappe.client.save', payload);
      }

      String? _extractDocName(Map<String, dynamic> res) {
        final msg = res['message'];
        if (msg is Map) {
          if (msg['data'] is Map && msg['data']['name'] != null) {
            return msg['data']['name'].toString();
          }
          if (msg['name'] != null) {
            return msg['name'].toString();
          }
        }
        if (res['data'] is Map && res['data']['name'] != null) {
          return res['data']['name'].toString();
        }
        if (res['name'] != null) {
          return res['name'].toString();
        }
        // Fallback for frappe.client.save return structure: it puts document dict directly in response['docs'][0] or response['docs'] or response['data']
        if (res['docs'] is List && (res['docs'] as List).isNotEmpty && res['docs'][0] is Map) {
          return res['docs'][0]['name']?.toString();
        }
        return null;
      }

      final status = response['status'] ?? response['message']?['status'] ?? response['message'];
      if (status == 'success' || response['message'] == 'success' || response['data'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.approvedMD,
              content: Text(isEdit ? 'Sales Invoice updated successfully!' : 'Sales Invoice created successfully!'),
            ),
          );
          
          final createdName = _extractDocName(response);
          if (createdName != null && !isEdit) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SalesInvoiceDetailScreen(
                  salesInvoice: SalesInvoiceModel.fromJson({'name': createdName}),
                ),
              ),
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      } else {
        throw Exception(response['message']?['error'] ?? 'API response validation failed.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.border)),
            title: Text('Submission Error', style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.salesInvoice != null;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEdit ? 'EDIT SALES INVOICE' : 'NEW SALES INVOICE',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.2),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF8B5CF6),
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: const Color(0xFF8B5CF6),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
            tabs: const [
              Tab(icon: Icon(Icons.person_outline_rounded), text: 'CLIENT'),
              Tab(icon: Icon(Icons.description_outlined), text: 'DETAILS'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'ITEMS'),
              Tab(icon: Icon(Icons.gavel_rounded), text: 'TERMS'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'SUMMARY'),
            ],
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
            : Form(
                key: _formKey,
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildClientTab(),
                    _buildDetailsTab(),
                    _buildItemsTab(),
                    _buildTermsTab(),
                    _buildSummaryTab(),
                  ],
                ),
              ),
        bottomNavigationBar: _buildStickyTotalsPanel(),
      ),
    );
  }

  Widget _buildClientTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('CUSTOMER & REQUISITIONS', Icons.person_rounded),
              const SizedBox(height: 16),
              
              _buildFieldContainer(
                label: 'CUSTOMER CODE',
                isMandatory: true,
                child: _buildSelectorTrigger(
                  value: _doc['customer']?.toString().isNotEmpty == true ? _doc['customer'] : null,
                  hint: 'Search Customer...',
                  onTap: () => _showSearchDialog(
                    title: 'Search Customer',
                    doctype: 'Customer',
                    onSelected: (customerCode) {
                      setState(() => _doc['customer'] = customerCode);
                      _fetchAndAutoFillCustomer(customerCode);
                    },
                  ),
                ),
              ),

              _buildTextField(label: 'CUSTOMER NAME', controller: _customerNameController, isMandatory: true, hintText: 'Enter customer name...'),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSlidingSegmentedControl(
          activeValue: _doc['custom_quote_type'] ?? 'Retail',
          options: const ['Retail', 'Project', 'AMC'],
          onChanged: (newMode) {
            setState(() {
              _doc['custom_quote_type'] = newMode;
            });
          },
        ),
        const SizedBox(height: 20),

        if (_doc['custom_quote_type'] == 'Retail') ...[
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('RETAIL DETAILS', Icons.shopping_bag_rounded),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'RETAIL QUOTE TYPE',
                  value: _doc['custom_retail_quote_type'],
                  options: const ['Supply Only', 'Supply with Installation'],
                  onChanged: (val) => setState(() => _doc['custom_retail_quote_type'] = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('TRANSACTION SETTINGS', Icons.calendar_month_rounded),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'POSTING DATE',
                      value: _doc['posting_date'],
                      onSelected: (val) => setState(() => _doc['posting_date'] = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDateField(
                      label: 'DUE DATE',
                      value: _doc['due_date'],
                      onSelected: (val) => setState(() => _doc['due_date'] = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      label: 'POSTING TIME',
                      value: _doc['posting_time'],
                      onSelected: (val) => setState(() => _doc['posting_time'] = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'CURRENCY',
                      value: _doc['currency'],
                      options: const ['QAR', 'USD'],
                      onChanged: (val) => setState(() => _doc['currency'] = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildFieldContainer(
                label: 'COMPANY',
                isMandatory: true,
                child: _buildSelectorTrigger(
                  value: _doc['company']?.toString().isNotEmpty == true ? _doc['company'] : null,
                  hint: 'Select Company...',
                  onTap: () => _showSearchDialog(
                    title: 'Search Company',
                    doctype: 'Company',
                    onSelected: (val) {
                      setState(() {
                        _doc['company'] = val;
                        if (_doc['items'] is List) {
                          for (var item in _doc['items']) {
                            item['warehouse'] = null;
                          }
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildDropdownField(
                label: 'PRICE LIST',
                value: _doc['selling_price_list'],
                options: const ['Standard Selling'],
                onChanged: (val) => setState(() => _doc['selling_price_list'] = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildItemsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildItemsTable(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildItemsTable() {
    final List<dynamic> itemsList = _doc['items'] ?? [];
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('ITEMS BREAKDOWN', Icons.inventory_2_outlined),
          const SizedBox(height: 16),
          if (itemsList.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.playlist_add_rounded, size: 42, color: AppColors.textLight),
                    const SizedBox(height: 10),
                    Text(
                      'No Items Added Yet.',
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemsList.length,
              itemBuilder: (context, index) {
                final item = itemsList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (item['item_code'] ?? 'Unknown Item').toString().toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF8B5CF6), size: 20),
                                  onPressed: () => _showItemEditorSheet(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 20),
                                onPressed: () {
                                  setState(() => itemsList.removeAt(index));
                                  _recalculateTotals();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        Text(
                          item['description'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildMiniTextLabel('QTY', '${item['qty']} ${item['uom'] ?? 'Nos'}')),
                          Expanded(child: _buildMiniTextLabel('STOCK QTY', '${item['stock_qty']} ${item['stock_uom'] ?? 'Nos'}')),
                          Expanded(child: _buildMiniTextLabel('RATE', 'QAR ${double.parse((item['rate'] ?? 0.0).toString()).toStringAsFixed(2)}')),
                          Expanded(child: _buildMiniTextLabel('TOTAL', 'QAR ${double.parse((item['amount'] ?? 0.0).toString()).toStringAsFixed(2)}')),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showItemEditorSheet(-1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  Text('ADD ROW', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6), fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemEditorSheet(final int editIndex) {
    final Map<String, dynamic> localItem = editIndex >= 0
        ? Map<String, dynamic>.from((_doc['items'] as List)[editIndex])
        : {
            'item_code': null,
            'qty': 1.0,
            'rate': 0.0,
            'amount': 0.0,
            'warehouse': null,
            'description': '',
            'uom': 'Nos',
            'conversion_factor': 1.0,
            'stock_uom': 'Nos',
            'stock_qty': 1.0,
            'discount_percentage': 0.0,
            'discount_amount': 0.0,
            'net_rate': 0.0,
            'net_amount': 0.0,
          };

    final qtyController = TextEditingController(text: localItem['qty']?.toString());
    final rateController = TextEditingController(text: localItem['rate']?.toString());
    final conversionController = TextEditingController(text: localItem['conversion_factor']?.toString());
    final discountPercentController = TextEditingController(text: localItem['discount_percentage']?.toString());
    final discountAmountController = TextEditingController(text: localItem['discount_amount']?.toString());
    final discountPercentFocusNode = FocusNode();
    final discountAmountFocusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void calculateAmount() {
            final double rate = double.tryParse(rateController.text) ?? 0.0;
            final double qty = double.tryParse(qtyController.text) ?? 1.0;
            final double conversion = double.tryParse(conversionController.text) ?? 1.0;

            double discountPercent = 0.0;
            double discountAmount = 0.0;

            if (discountAmountFocusNode.hasFocus) {
              discountAmount = double.tryParse(discountAmountController.text) ?? 0.0;
              if (rate > 0) {
                discountPercent = (discountAmount / rate) * 100;
                discountPercentController.text = discountPercent.toStringAsFixed(2);
              }
            } else {
              discountPercent = double.tryParse(discountPercentController.text) ?? 0.0;
              discountAmount = rate * (discountPercent / 100);
              if (discountPercentFocusNode.hasFocus || rateController.text.isNotEmpty) {
                discountAmountController.text = discountAmount.toStringAsFixed(2);
              }
            }

            final double netRate = rate - discountAmount;
            final double amount = qty * netRate;

            setSheetState(() {
              localItem['rate'] = rate;
              localItem['qty'] = qty;
              localItem['conversion_factor'] = conversion;
              localItem['discount_percentage'] = discountPercent;
              localItem['discount_amount'] = discountAmount;
              localItem['net_rate'] = netRate;
              localItem['amount'] = amount;
              localItem['stock_qty'] = qty * conversion;
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, sheetScrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ListView(
                controller: sheetScrollController,
                physics: const BouncingScrollPhysics(),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Text(
                    editIndex >= 0 ? 'EDIT ITEM' : 'ADD ITEM',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 20),

                  _buildFieldContainer(
                    label: 'ITEM CODE',
                    isMandatory: true,
                    child: _buildSelectorTrigger(
                      value: localItem['item_code'],
                      hint: 'Select Item...',
                      onTap: () => _showSearchDialog(
                        title: 'Search Item',
                        doctype: 'Item',
                        onSelected: (val) async {
                          setSheetState(() => localItem['item_code'] = val);
                          try {
                            dynamic d;
                            try {
                              final res = await _apiClient.get(
                                'oasis_mobile.api.sales_invoice.get_item_details',
                                params: {'item_code': val},
                              );
                              d = res['status'] == 'success' ? res : (res['message'] ?? res);
                            } catch (_) {
                              try {
                                final res = await _apiClient.get(
                                  'oasis_mobile.api.delivery_note.get_item_details',
                                  params: {'item_code': val},
                                );
                                d = res['status'] == 'success' ? res : (res['message'] ?? res);
                              } catch (_) {
                                final res = await _apiClient.get(
                                  'oasis_mobile.api.sales_order.get_item_details',
                                  params: {'item_code': val},
                                );
                                d = res['status'] == 'success' ? res : (res['message'] ?? res);
                              }
                            }

                            if (d != null && d['status'] != 'error') {
                              setSheetState(() {
                                rateController.text = (d['rate'] ?? 0.0).toString();
                                localItem['item_name'] = d['item_name'] ?? '';
                                localItem['description'] = d['description'] ?? '';
                                localItem['uom'] = d['uom'] ?? 'Nos';
                                localItem['stock_uom'] = d['uom'] ?? 'Nos';
                              });
                              calculateAmount();
                            }
                          } catch (e) {
                            debugPrint('Error fetching item details: $e');
                          }
                        },
                      ),
                    ),
                  ),

                  _buildFieldContainer(
                    label: 'WAREHOUSE',
                    isMandatory: true,
                    child: _buildSelectorTrigger(
                      value: localItem['warehouse'],
                      hint: 'Select Warehouse...',
                      onTap: () => _showSearchDialog(
                        title: 'Search Warehouse',
                        doctype: 'Warehouse',
                        onSelected: (val) {
                          setSheetState(() => localItem['warehouse'] = val);
                        },
                      ),
                    ),
                  ),

                  _buildFieldContainer(
                    label: 'QUANTITY',
                    isMandatory: true,
                    child: TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 1.0'),
                      onChanged: (_) => calculateAmount(),
                    ),
                  ),

                  _buildFieldContainer(
                    label: 'CONVERSION FACTOR',
                    isMandatory: true,
                    child: TextFormField(
                      controller: conversionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 1.0'),
                      onChanged: (_) => calculateAmount(),
                    ),
                  ),

                  _buildFieldContainer(
                    label: 'UNIT RATE (QAR)',
                    isMandatory: true,
                    child: TextFormField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 120.00'),
                      onChanged: (_) => calculateAmount(),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldContainer(
                          label: 'DISCOUNT (%)',
                          isMandatory: false,
                          child: TextFormField(
                            controller: discountPercentController,
                            focusNode: discountPercentFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                            decoration: _getInputDecoration(hintText: 'e.g. 10.00'),
                            onChanged: (_) => calculateAmount(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildFieldContainer(
                          label: 'DISCOUNT AMOUNT',
                          isMandatory: false,
                          child: TextFormField(
                            controller: discountAmountController,
                            focusNode: discountAmountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                            decoration: _getInputDecoration(hintText: 'e.g. 12.00'),
                            onChanged: (_) => calculateAmount(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('STOCK QUANTITY', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            Text('${localItem['stock_qty']} ${localItem['stock_uom']}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('COMPUTED TOTAL', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            Text('QAR ${(localItem['amount'] ?? 0.0).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF8B5CF6))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () {
                      if (localItem['item_code'] == null) return;
                      setState(() {
                        final List<dynamic> currentList = _doc['items'] ?? [];
                        if (editIndex >= 0) {
                          currentList[editIndex] = localItem;
                        } else {
                          currentList.add(localItem);
                        }
                        _doc['items'] = currentList;
                      });
                      _recalculateTotals();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('CONFIRM ITEM', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTermsTab() {
    final List<dynamic> schedule = _doc['payment_schedule'] ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('PAYMENT TERMS TEMPLATE', Icons.schedule_rounded),
              const SizedBox(height: 16),
              _buildFieldContainer(
                label: 'PAYMENT TEMPLATE ID',
                isMandatory: false,
                child: _buildSelectorTrigger(
                  value: _doc['payment_terms_template']?.toString().isNotEmpty == true
                      ? _doc['payment_terms_template']
                      : null,
                  hint: 'Select Template...',
                  onTap: () => _showSearchDialog(
                    title: 'Payment Templates',
                    doctype: 'Payment Terms Template',
                    onSelected: (template) {
                      setState(() => _doc['payment_terms_template'] = template);
                      _recalculateTotals();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (schedule.isNotEmpty) ...[
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('PAYMENT SCHEDULE / MILESTONES', Icons.payments_rounded),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    final term = schedule[index];
                    final portion = (term['invoice_portion'] as num? ?? 0.0).toDouble();
                    final amount = (term['payment_amount'] as num? ?? 0.0).toDouble();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  (term['payment_term'] ?? 'Milestone').toString().toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${portion.toStringAsFixed(1)}%',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (term['description'] != null && term['description'].toString().isNotEmpty) ...[
                            Text(
                              term['description'].toString(),
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'AMOUNT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                              ),
                              Text(
                                'QAR ${amount.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF8B5CF6)),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DUE DATE',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                              ),
                              InkWell(
                                onTap: () async {
                                  final initialDate = DateTime.tryParse(term['due_date']?.toString() ?? '') ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      term['due_date'] = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        term['due_date'] != null && term['due_date'].toString().isNotEmpty
                                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(term['due_date']))
                                            : 'Select Date',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('INTERNAL CONTROL SIGN-OFF', Icons.shield_rounded),
              const SizedBox(height: 16),
              _buildTextField(label: 'PREPARED BY', controller: _preparedByController, isMandatory: false, hintText: 'Enter name...'),
              _buildTextField(label: 'VERIFIED BY', controller: _verifiedByController, isMandatory: false, hintText: 'Enter name...'),
              _buildTextField(label: 'APPROVED BY', controller: _approvedByController, isMandatory: false, hintText: 'Enter name...'),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('AGGREGATE REVENUE SUMMARY', Icons.price_check_rounded),
              const SizedBox(height: 16),
              _buildSummaryRow('NET TOTAL (Excl. Tax)', 'QAR ${(_doc['net_total'] ?? 0.0).toStringAsFixed(2)}'),
              const Divider(height: 24),
              _buildSummaryRow('GRAND TOTAL AMOUNT', 'QAR ${(_doc['grand_total'] ?? 0.0).toStringAsFixed(2)}', isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('SPECIAL DISCOUNT', Icons.percent_rounded),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'ADDITIONAL DISCOUNT AMOUNT (QAR)',
                controller: _specialDiscountController,
                isMandatory: false,
                hintText: 'Enter discount amount...',
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildStickyTotalsPanel() {
    // LayoutBuilder provides finite width constraints so that ScaleTransition
    // does not pass unbounded (Infinity) width down to the ElevatedButton.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double panelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        return ScaleTransition(
          scale: _totalsScaleAnimation,
          child: SizedBox(
            width: panelWidth,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NET SUM TOTAL',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'QAR ${(_doc['grand_total'] ?? 0.0).toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: _saveSalesInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.salesInvoice != null ? 'UPDATE' : 'SUBMIT',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildCardHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldContainer({required String label, required bool isMandatory, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              if (isMandatory)
                const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildSelectorTrigger({required String? value, required String hint, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: value != null ? FontWeight.w700 : FontWeight.w500,
                  color: value != null ? AppColors.textPrimary : AppColors.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required bool isMandatory, String? hintText, TextInputType? keyboardType}) {
    return _buildFieldContainer(
      label: label,
      isMandatory: isMandatory,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: isMandatory ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        decoration: _getInputDecoration(hintText: hintText),
      ),
    );
  }

  Widget _buildDropdownField({required String label, required String? value, required List<String> options, required ValueChanged<String?> onChanged}) {
    return _buildFieldContainer(
      label: label,
      isMandatory: true,
      child: DropdownButtonFormField<String>(
        value: value,
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        decoration: _getInputDecoration(),
      ),
    );
  }

  Widget _buildDateField({required String label, required String value, required ValueChanged<String> onSelected}) {
    return _buildFieldContainer(
      label: label,
      isMandatory: true,
      child: InkWell(
        onTap: () async {
          final initialDate = DateTime.tryParse(value) ?? DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onSelected(DateFormat('yyyy-MM-dd').format(picked));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value.isNotEmpty ? DateFormat('dd MMM yyyy').format(DateTime.parse(value)) : 'Select Date',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField({required String label, required String value, required ValueChanged<String> onSelected}) {
    return _buildFieldContainer(
      label: label,
      isMandatory: true,
      child: InkWell(
        onTap: () async {
          TimeOfDay initialTime = TimeOfDay.now();
          if (value.isNotEmpty) {
            final parts = value.split(':');
            if (parts.length >= 2) {
              initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          }
          final picked = await showTimePicker(
            context: context,
            initialTime: initialTime,
          );
          if (picked != null) {
            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
            onSelected(DateFormat('HH:mm:ss').format(dt));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value.isNotEmpty ? value.substring(0, 5) : 'Select Time',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingSegmentedControl({required String activeValue, required List<String> options, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = activeValue == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Text(
                    opt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? const Color(0xFF8B5CF6) : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isBold ? const Color(0xFF8B5CF6) : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTextLabel(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
    );
  }

  void _showSearchDialog({
    required String title,
    required String doctype,
    Map<String, dynamic>? filters,
    required ValueChanged<String> onSelected,
  }) {
    if (doctype == 'Warehouse') {
      filters = {
        'company': _doc['company'] ?? '',
        'is_group': 0,
        ...?filters,
      };
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchLinkSheet(
        title: title,
        doctype: doctype,
        filters: filters,
        onSelected: (val) {
          Navigator.pop(context);
          onSelected(val);
        },
      ),
    );
  }
}

class _SearchLinkSheet extends StatefulWidget {
  final String title;
  final String doctype;
  final ValueChanged<String> onSelected;
  final Map<String, dynamic>? filters;

  const _SearchLinkSheet({
    required this.title,
    required this.doctype,
    required this.onSelected,
    this.filters,
  });

  @override
  State<_SearchLinkSheet> createState() => _SearchLinkSheetState();
}

class _SearchLinkSheetState extends State<_SearchLinkSheet> {
  final ApiClient _apiClient = ApiClient();
  final List<String> _results = [];
  bool _isLoading = false;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _query = val;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchList();
    });
  }

  Future<void> _fetchList() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, String> params = {
        'doctype': widget.doctype,
        'txt': _query,
        'query': _query,
        if (widget.filters != null) 'filters': jsonEncode(widget.filters),
      };
      dynamic res;
      try {
        res = await _apiClient.get('oasis_mobile.api.sales_invoice.search_link', params: params);
      } catch (_) {
        res = await _apiClient.get('oasis_mobile.api.sales_order.get_search_link_list', params: params);
      }
      final List<dynamic> data = res['results'] ?? res['message'] ?? res['data'] ?? [];
      setState(() {
        _results.clear();
        for (var item in data) {
          if (item is Map) {
            _results.add((item['value'] ?? item['name'] ?? '').toString());
          } else {
            _results.add(item.toString());
          }
        }
        _isLoading = false;
      });
    } catch (_) {
      // Fallback: Fetch directly from resource REST API
      try {
        final Map<String, String> params = {
          'limit_page_length': '30',
        };
        if (_query.isNotEmpty) {
          if (widget.doctype == 'Customer') {
            params['or_filters'] = '[["name","like","%$_query%"],["customer_name","like","%$_query%"]]';
          } else if (widget.doctype == 'Supplier') {
            params['or_filters'] = '[["name","like","%$_query%"],["supplier_name","like","%$_query%"]]';
          } else {
            params['filters'] = '[["name","like","%$_query%"]]';
          }
        }
        final res = await _apiClient.get('../resource/${widget.doctype}', params: params);
        final List<dynamic> data = res['data'] ?? [];
        setState(() {
          _results.clear();
          for (var item in data) {
            if (item['name'] != null) {
              _results.add(item['name'].toString());
            }
          }
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        debugPrint('Search failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Text(widget.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 20),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : _results.isEmpty
                    ? Center(child: Text('No results found', style: GoogleFonts.plusJakartaSans(color: AppColors.textLight)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final val = _results[index];
                          return ListTile(
                            title: Text(val, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                            onTap: () => widget.onSelected(val),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
