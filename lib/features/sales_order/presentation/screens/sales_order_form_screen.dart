import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/sales_order/models/sales_order_model.dart';
import 'package:oasis/features/sales_order/presentation/screens/sales_order_detail_screen.dart';

class SalesOrderFormScreen extends StatefulWidget {
  final SalesOrderModel? salesOrder;
  final Map<String, dynamic>? initialData;
  const SalesOrderFormScreen({super.key, this.salesOrder, this.initialData});

  @override
  State<SalesOrderFormScreen> createState() => _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState extends State<SalesOrderFormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  Map<String, dynamic> _doc = {};

  // Form Field Controllers
  late TextEditingController _customerNameController;
  late TextEditingController _arabicCustomerNameController;
  
  // Details/Subject/Ref Controllers
  late TextEditingController _subjectController;
  late TextEditingController _refController;
  
  // Terms & Conditions Controllers
  late TextEditingController _termsArabicController;

  // Audit Trails/Roles Controllers
  late TextEditingController _preparedByController;
  late TextEditingController _verifiedByController;
  late TextEditingController _approvedByController;

  // Animation Controllers for recalculation bounce
  late AnimationController _totalsAnimController;
  late Animation<double> _totalsScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scale bounce animation for aggregated totals
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
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String deliveryStr = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7)));

    if (widget.salesOrder != null) {
      final so = widget.salesOrder!;
      _doc = {
        'name': so.name,
        'customer': so.customer,
        'customer_name': so.customerName ?? '',
        'custom_customer_name_in_arabic': so.customerNameInArabic ?? '',
        'transaction_date': so.transactionDate.isNotEmpty ? so.transactionDate : todayStr,
        'delivery_date': so.deliveryDate.isNotEmpty ? so.deliveryDate : deliveryStr,
        'order_type': so.orderType.isNotEmpty ? so.orderType : 'Sales',
        'currency': so.currency.isNotEmpty ? so.currency : 'QAR',
        'conversion_rate': so.conversionRate,
        'selling_price_list': so.sellingPriceList.isNotEmpty ? so.sellingPriceList : 'Standard Selling',
        'price_list_currency': so.priceListCurrency.isNotEmpty ? so.priceListCurrency : 'QAR',
        'plc_conversion_rate': so.plcConversionRate,
        'custom_quote_type': so.customQuoteType ?? 'Retail',
        'custom_retail_quote_type': so.customRetailQuoteType ?? 'Supply Only',
        'custom_subject': so.customSubject ?? '',
        'custom_ref': so.customRef ?? '',
        'custom_prepared_by': so.customPreparedBy ?? '',
        'custom_verified_by': so.customVerifiedBy ?? '',
        'custom_approved_by': so.customApprovedBy ?? '',
        'custom_terms_details_arabic': so.customTermsDetailsArabic ?? '',
        'grand_total': so.grandTotal ?? 0.0,
        'net_total': so.netTotal ?? 0.0,
        'items': so.items.map((e) => e.toJson()).toList(),
        'payment_terms_template': '',
        'payment_schedule': <Map<String, dynamic>>[],
        'quotation_link': '',
        'company': 'Oasis Trading and Importing HVAC',
        'disable_rounded_total': 0,
        'total_qty': so.items.fold<double>(0, (sum, item) => sum + item.qty),
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
      _doc['custom_customer_name_in_arabic'] ??= '';
      _doc['transaction_date'] ??= todayStr;
      _doc['delivery_date'] ??= deliveryStr;
      _doc['order_type'] ??= 'Sales';
      _doc['currency'] ??= 'QAR';
      _doc['conversion_rate'] ??= 1.0;
      _doc['selling_price_list'] ??= 'Standard Selling';
      _doc['price_list_currency'] ??= 'QAR';
      _doc['plc_conversion_rate'] ??= 1.0;
      _doc['custom_quote_type'] ??= 'Retail';
      _doc['custom_retail_quote_type'] ??= 'Supply Only';
      _doc['custom_subject'] ??= '';
      _doc['custom_ref'] ??= '';
      _doc['custom_prepared_by'] ??= '';
      _doc['custom_verified_by'] ??= '';
      _doc['custom_approved_by'] ??= '';
      _doc['custom_terms_details_arabic'] ??= '';
      _doc['grand_total'] ??= 0.0;
      _doc['net_total'] ??= 0.0;
      _doc['items'] ??= <Map<String, dynamic>>[];
      _doc['payment_terms_template'] ??= '';
      _doc['payment_schedule'] ??= <Map<String, dynamic>>[];
      _doc['quotation_link'] ??= '';
      _doc['disable_rounded_total'] ??= 0;
      _doc['total_qty'] ??= 0.0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateTotals();
      });
    } else {
      _doc = {
        'company': 'Oasis Trading and Importing HVAC',
        'customer': '',
        'customer_name': '',
        'custom_customer_name_in_arabic': '',
        'transaction_date': todayStr,
        'delivery_date': deliveryStr,
        'order_type': 'Sales',
        'currency': 'QAR',
        'conversion_rate': 1.0,
        'selling_price_list': 'Standard Selling',
        'price_list_currency': 'QAR',
        'plc_conversion_rate': 1.0,
        'custom_quote_type': 'Retail',
        'custom_retail_quote_type': 'Supply Only',
        'custom_subject': '',
        'custom_ref': '',
        'custom_prepared_by': '',
        'custom_verified_by': '',
        'custom_approved_by': '',
        'custom_terms_details_arabic': '',
        'grand_total': 0.0,
        'net_total': 0.0,
        'items': <Map<String, dynamic>>[],
        'payment_terms_template': '',
        'payment_schedule': <Map<String, dynamic>>[],
        'quotation_link': '',
        'disable_rounded_total': 0,
        'total_qty': 0.0,
      };
    }

    _setupControllers();
  }

  void _setupControllers() {
    _customerNameController = TextEditingController(text: _doc['customer_name']);
    _arabicCustomerNameController = TextEditingController(text: _doc['custom_customer_name_in_arabic']);
    _subjectController = TextEditingController(text: _doc['custom_subject']);
    _refController = TextEditingController(text: _doc['custom_ref']);
    _termsArabicController = TextEditingController(text: _doc['custom_terms_details_arabic']);
    _preparedByController = TextEditingController(text: _doc['custom_prepared_by']);
    _verifiedByController = TextEditingController(text: _doc['custom_verified_by']);
    _approvedByController = TextEditingController(text: _doc['custom_approved_by']);

    // Auto-update values back into document map as user types
    _customerNameController.addListener(() => _doc['customer_name'] = _customerNameController.text);
    _arabicCustomerNameController.addListener(() => _doc['custom_customer_name_in_arabic'] = _arabicCustomerNameController.text);
    _subjectController.addListener(() => _doc['custom_subject'] = _subjectController.text);
    _refController.addListener(() => _doc['custom_ref'] = _refController.text);
    _termsArabicController.addListener(() => _doc['custom_terms_details_arabic'] = _termsArabicController.text);
    _preparedByController.addListener(() => _doc['custom_prepared_by'] = _preparedByController.text);
    _verifiedByController.addListener(() => _doc['custom_verified_by'] = _verifiedByController.text);
    _approvedByController.addListener(() => _doc['custom_approved_by'] = _approvedByController.text);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _arabicCustomerNameController.dispose();
    _subjectController.dispose();
    _refController.dispose();
    _termsArabicController.dispose();
    _preparedByController.dispose();
    _verifiedByController.dispose();
    _approvedByController.dispose();
    _totalsAnimController.dispose();
    super.dispose();
  }

  // --- Real-time Calculations ---
  void _recalculateTotals() {
    double totalQty = 0;
    double netTotal = 0;

    final itemsList = _doc['items'] as List<dynamic>? ?? [];
    for (var item in itemsList) {
      final qty = (item['qty'] as num? ?? 0.0).toDouble();
      final rate = (item['rate'] as num? ?? 0.0).toDouble();
      totalQty += qty;
      netTotal += qty * rate;
    }

    setState(() {
      _doc['total_qty'] = totalQty;
      _doc['net_total'] = netTotal;
      
      final grandTotal = netTotal;
      _doc['grand_total'] = grandTotal;
    });

    _totalsAnimController.forward(from: 0.0);

    // If template selected, update milestones
    if (_doc['payment_terms_template'] != null && _doc['payment_terms_template'].toString().isNotEmpty) {
      _fetchPaymentTermsDetails(_doc['payment_terms_template'].toString(), _doc['grand_total']);
    }
  }

  // --- Auto-fill Payment Terms ---
  Future<void> _fetchPaymentTermsDetails(String template, double grandTotal) async {
    try {
      // Gracefully try standard sales_order endpoint, fall back to quotation endpoint if not found
      dynamic res;
      try {
        res = await _apiClient.get(
          'oasis_mobile.api.sales_order.get_payment_terms_details',
          params: {
            'template': template,
            'grand_total': grandTotal.toString(),
          },
        );
      } catch (_) {
        res = await _apiClient.get(
          'oasis_mobile.api.quotation.get_payment_terms_details',
          params: {
            'template': template,
            'grand_total': grandTotal.toString(),
          },
        );
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

  // --- Auto-fill Customer details ---
  Future<void> _fetchAndAutoFillCustomer(String customerCode) async {
    setState(() => _isLoading = true);
    dynamic data;
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.sales_order.get_customer_details',
        params: {'customer': customerCode},
      );
      data = res['status'] == 'success' ? res : (res['message'] ?? res);
    } catch (_) {
      try {
        final res = await _apiClient.get(
          'oasis_mobile.api.quotation.get_customer_details',
          params: {'customer': customerCode},
        );
        data = res['status'] == 'success' ? res : (res['message'] ?? res);
      } catch (e) {
        debugPrint('Customer detail fetching failed, attempting resource fallback: $e');
        try {
          final res = await _apiClient.get('../resource/Customer/${Uri.encodeComponent(customerCode)}');
          final doc = res['data'];
          if (doc != null) {
            data = {
              'customer_name': doc['customer_name'] ?? doc['name'] ?? customerCode,
              'custom_customer_name_in_arabic': doc['custom_customer_name_in_arabic'] ?? '',
            };
          }
        } catch (fallbackError) {
          debugPrint('Fallback resource customer fetching failed: $fallbackError');
        }
      }
    }

    if (data != null && data['status'] != 'error') {
      setState(() {
        _doc['customer_name'] = data['customer_name'] ?? '';
        _doc['custom_customer_name_in_arabic'] = data['custom_customer_name_in_arabic'] ?? '';
        
        _customerNameController.text = _doc['customer_name'];
        _arabicCustomerNameController.text = _doc['custom_customer_name_in_arabic'];
      });
    } else {
      setState(() {
        _doc['customer_name'] = customerCode;
        _customerNameController.text = customerCode;
      });
    }
    setState(() => _isLoading = false);
  }

  // --- Auto-fill from Quotation Link ---
  Future<void> _fetchQuotationDetails(String quotationName) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.quotation.get_quotation',
        params: {'name': quotationName},
      );
      if (res['status'] == 'success' && res['data'] != null) {
        final q = res['data'];
        setState(() {
          _doc['customer'] = q['party_name'] ?? q['customer'] ?? '';
          _doc['customer_name'] = q['customer_name'] ?? '';
          _doc['custom_customer_name_in_arabic'] = q['custom_customer_name_in_arabic'] ?? q['custom_customer_name_in_arabic'] ?? '';
          _doc['custom_subject'] = q['custom_subject'] ?? '';
          _doc['custom_ref'] = q['custom_ref'] ?? '';
          _doc['custom_quote_type'] = q['custom_quote_type'] ?? 'Retail';
          _doc['custom_retail_quote_type'] = q['custom_retail_quote_type'] ?? 'Supply Only';
          _doc['currency'] = q['currency'] ?? 'QAR';
          
          if (q['items'] != null) {
            _doc['items'] = List<Map<String, dynamic>>.from(q['items']);
          }

          // Update controllers
          _customerNameController.text = _doc['customer_name'];
          _arabicCustomerNameController.text = _doc['custom_customer_name_in_arabic'];
          _subjectController.text = _doc['custom_subject'];
          _refController.text = _doc['custom_ref'];
        });
        _recalculateTotals();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.approvedMD,
            content: Text('Auto-filled information from Quotation: $quotationName', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error pulling quotation details: $e');
    }
    setState(() => _isLoading = false);
  }

  void _removeAuditFields(Map<String, dynamic> data) {
    const auditFields = [
      'custom_prepared_by', 'custom_prepared_by_name',
      'custom_verified_by',  'custom_verified_by_name',
      'custom_approved_by',  'custom_approved_by_name',
      'custom_prepared_by_role',
    ];
    for (final f in auditFields) {
      // Explicitly set to empty string so backend receives a clear blank value
      data[f] = '';
    }
  }

  Map<String, dynamic> _sanitizeForUpdate(Map<String, dynamic> raw) {
    const List<String> readOnlyFields = [
      'name',
      'owner',
      'creation',
      'modified',
      'modified_by',
      'docstatus',
      'idx',
      'workflow_state',
      'amended_from',
      'company',
      'custom_prepared_by',
      'custom_prepared_by_name',
      'custom_verified_by',
      'custom_verified_by_name',
      'custom_approved_by',
      'custom_approved_by_name',
      'custom_prepared_by_role',
    ];
    final data = Map<String, dynamic>.from(raw);

    // Strip read-only fields
    for (final f in readOnlyFields) {
      data.remove(f);
    }

    // Strip empty payment_terms_template
    if ((data['payment_terms_template'] ?? '').toString().isEmpty) {
      data.remove('payment_terms_template');
      data['payment_schedule'] = [];
    }

    // Strip payment_schedule rows without due_date
    if (data['payment_schedule'] is List) {
      data['payment_schedule'] = (data['payment_schedule'] as List)
          .where((row) =>
              row is Map &&
              (row['due_date'] ?? '').toString().isNotEmpty)
          .toList();
    }

    return data;
  }

  // --- Save / POST Sales Order ---
  Future<void> _saveSalesOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please fill out all required fields.', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    if ((_doc['items'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Sales Order must contain at least one item.', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isEdit = widget.salesOrder != null;
      Map<String, dynamic> response;
      if (isEdit) {
        final cleanData = _sanitizeForUpdate(_doc);
        response = await _apiClient.post(
          'oasis_mobile.api.sales_order.update_sales_order',
          {
            'name': widget.salesOrder!.name,
            'data': jsonEncode(cleanData),
          },
        );
      } else {
        final cleanData = Map<String, dynamic>.from(_doc);
        _removeAuditFields(cleanData);
        // DEBUG: confirm audit fields are cleared before POST
        debugPrint('🔍 [CREATE SO] custom_approved_by="${cleanData['custom_approved_by']}" custom_verified_by="${cleanData['custom_verified_by']}" custom_prepared_by="${cleanData['custom_prepared_by']}"');
        response = await _apiClient.post(
          'oasis_mobile.api.sales_order.create_sales_order',
          {'data': cleanData},
        );
      }

      final message = response['message'];
      bool isSuccess = false;
      String? errMsg;
      if (message is Map) {
        isSuccess = message['status'] == 'success';
        errMsg = message['message'] ?? message['error'];
      } else {
        isSuccess = response['status'] == 'success';
        errMsg = response['message']?['error'] ?? response['message']?['message'];
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
        return null;
      }

      if (isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.approvedMD,
              content: Text(isEdit ? 'Sales Order updated successfully!' : 'Sales Order created successfully!', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
          
          final createdName = _extractDocName(response);
          if (createdName != null && !isEdit) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SalesOrderDetailScreen(
                  salesOrder: SalesOrderModel.fromJson({'name': createdName}),
                ),
              ),
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      } else {
        throw Exception(errMsg ?? 'API response validation failed.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.border)),
            title: Text('Submission Error', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.salesOrder != null;
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
            isEdit ? 'EDIT SALES ORDER' : 'NEW SALES ORDER',
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1.2),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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

  // --- CLIENT TAB ---
  Widget _buildClientTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('CUSTOMER & REQUISITIONS', Icons.person_rounded),
              const SizedBox(height: 16),
              
              // Customer Link
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
              _buildArabicField(label: 'CUSTOMER NAME (ARABIC)', controller: _arabicCustomerNameController, isMandatory: true, hintText: 'اسم العميل باللغة العربية...'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('OPTIONAL DIRECT LINKS', Icons.link_rounded),
              const SizedBox(height: 16),
              
              // Quotation Link
              _buildFieldContainer(
                label: 'QUOTATION LINK',
                isMandatory: false,
                child: _buildSelectorTrigger(
                  value: _doc['quotation_link']?.toString().isNotEmpty == true ? _doc['quotation_link'] : null,
                  hint: 'Link a Quotation...',
                  onTap: () => _showSearchDialog(
                    title: 'Link Quotation',
                    doctype: 'Quotation',
                    onSelected: (qName) {
                      setState(() => _doc['quotation_link'] = qName);
                      _fetchQuotationDetails(qName);
                    },
                  ),
                ),
              ),

              _buildTextField(label: 'SUBJECT / SUMMARY', controller: _subjectController, isMandatory: false, hintText: 'English subject...'),
              _buildTextField(label: 'REFERENCE / PO ID', controller: _refController, isMandatory: false, hintText: 'e.g. PO-74932'),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // --- DETAILS TAB ---
  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        SlidingSegmentedControl(
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
          GlassCard(
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

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('TRANSACTION SETTINGS', Icons.calendar_month_rounded),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'ORDER DATE',
                      value: _doc['transaction_date'],
                      onSelected: (val) => setState(() => _doc['transaction_date'] = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDateField(
                      label: 'DELIVERY DATE',
                      value: _doc['delivery_date'],
                      onSelected: (val) => setState(() => _doc['delivery_date'] = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDropdownField(
                label: 'ORDER TYPE',
                value: _doc['order_type'],
                options: const ['Sales', 'Maintenance', 'Shopping Cart'],
                onChanged: (val) => setState(() => _doc['order_type'] = val),
              ),
              const SizedBox(height: 14),
              _buildDropdownField(
                label: 'PRICE LIST',
                value: _doc['selling_price_list'],
                options: const ['Standard Selling'],
                onChanged: (val) => setState(() => _doc['selling_price_list'] = val),
              ),
              const SizedBox(height: 14),
              _buildDropdownField(
                label: 'CURRENCY',
                value: _doc['currency'],
                options: const ['QAR', 'USD'],
                onChanged: (val) => setState(() => _doc['currency'] = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // --- ITEMS TAB ---
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
    return GlassCard(
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
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
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
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 20),
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
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniTextLabel('QTY', '${item['qty']} ${item['uom'] ?? 'Nos'}'),
                          _buildMiniTextLabel('RATE', 'QAR ${double.parse((item['rate'] ?? 0.0).toString()).toStringAsFixed(2)}'),
                          _buildMiniTextLabel('TOTAL', 'QAR ${double.parse((item['amount'] ?? 0.0).toString()).toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          ScaleButton(
            onTap: () => _showItemEditorSheet(-1),
            color: Colors.transparent,
            border: Border.all(color: AppColors.accent, width: 1.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('ADD ROW', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 14)),
              ],
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
            'description': '',
            'uom': 'Nos',
          };

    final qtyController = TextEditingController(text: localItem['qty']?.toString());
    final rateController = TextEditingController(text: localItem['rate']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void calculateAmount() {
            final double rate = double.tryParse(rateController.text) ?? 0.0;
            final double qty = double.tryParse(qtyController.text) ?? 1.0;
            setSheetState(() {
              localItem['rate'] = rate;
              localItem['qty'] = qty;
              localItem['amount'] = qty * rate;
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
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 20),

                  // Item link
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
                                'oasis_mobile.api.sales_order.get_item_details',
                                params: {
                                  'item_code': val,
                                },
                              );
                              d = res['status'] == 'success' ? res : (res['message'] ?? res);
                            } catch (_) {
                              final res = await _apiClient.get(
                                'oasis_mobile.api.quotation.get_item_details',
                                params: {
                                  'item_code': val,
                                },
                              );
                              d = res['status'] == 'success' ? res : (res['message'] ?? res);
                            }

                            if (d != null && d['status'] != 'error') {
                              setSheetState(() {
                                rateController.text = (d['rate'] ?? 0.0).toString();
                                localItem['item_name'] = d['item_name'] ?? '';
                                localItem['description'] = d['description'] ?? '';
                                localItem['uom'] = d['uom'] ?? 'Nos';
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
                    label: 'QUANTITY',
                    isMandatory: true,
                    child: TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
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
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 1500.00'),
                      onChanged: (_) => calculateAmount(),
                    ),
                  ),

                  // Computed total rate row
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('COMPUTED TOTAL', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                        Text('QAR ${(localItem['amount'] ?? 0.0).toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ScaleButton(
                    onTap: () {
                      if (localItem['item_code'] == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please select an item code.', style: GoogleFonts.outfit())),
                        );
                        return;
                      }

                      setState(() {
                        if (editIndex >= 0) {
                          (_doc['items'] as List)[editIndex] = localItem;
                        } else {
                          (_doc['items'] as List).add(localItem);
                        }
                      });
                      _recalculateTotals();
                      Navigator.pop(context);
                    },
                    gradient: const LinearGradient(colors: [Color(0xFF214392), Color(0xFF3B82F6)]),
                    child: Text(editIndex >= 0 ? 'UPDATE ITEM' : 'ADD ITEM', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 12),
                  ScaleButton(
                    onTap: () => Navigator.pop(context),
                    color: Colors.transparent,
                    border: Border.all(color: AppColors.border, width: 1.0),
                    child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- TERMS TAB ---
  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('ARABIC TERMS & MILESTONES', Icons.gavel_rounded),
              const SizedBox(height: 16),
              
              _buildFieldContainer(
                label: 'PAYMENT TERMS TEMPLATE',
                isMandatory: false,
                child: _buildSelectorTrigger(
                  value: _doc['payment_terms_template']?.toString().isNotEmpty == true
                      ? _doc['payment_terms_template']
                      : null,
                  hint: 'Select Template...',
                  onTap: () => _showSearchDialog(
                    title: 'Search Payment Terms Template',
                    doctype: 'Payment Terms Template',
                    onSelected: (val) {
                      setState(() => _doc['payment_terms_template'] = val);
                      _fetchPaymentTermsDetails(val, _doc['grand_total'] ?? 0.0);
                    },
                  ),
                ),
              ),

              _buildArabicField(label: 'TERMS DETAILS (ARABIC)', controller: _termsArabicController, isMandatory: false, maxLines: 4, hintText: 'الشروط والأحكام الخاصة بالشركة...'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPaymentScheduleTable(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildPaymentScheduleTable() {
    final List<dynamic> schedule = _doc['payment_schedule'] ?? [];
    if (schedule.isEmpty) return const SizedBox.shrink();
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('MILESTONES BREAKUP', Icons.payments_rounded),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((term['payment_term'] ?? 'Milestone').toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                          if (term['description'] != null && term['description'].toString().isNotEmpty)
                            Text(term['description'], style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text('QAR ${amount.toStringAsFixed(2)} (${portion.toStringAsFixed(0)}%)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SUMMARY TAB ---
  Widget _buildSummaryTab() {
    final grandTotal = double.tryParse(_doc['grand_total']?.toString() ?? '0') ?? 0.0;
    final totalQty = (_doc['items'] as List?)
        ?.fold<double>(0.0, (sum, item) => sum + (double.tryParse((item as Map)['qty']?.toString() ?? '0') ?? 0.0)) ?? 0.0;
    final itemCount = (_doc['items'] as List?)?.length ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('SALES ORDER SUMMARY', Icons.price_check_rounded),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GRAND TOTAL',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'QAR ${grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$itemCount ITEMS',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${totalQty.toStringAsFixed(1)} TOTAL QTY',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('PREPARED & AUTHORIZED SIGNATURES', Icons.draw_rounded),
              const SizedBox(height: 16),
              _buildTextField(label: 'PREPARED BY', controller: _preparedByController, isMandatory: false, hintText: 'Enter name...'),
              _buildTextField(label: 'VERIFIED BY', controller: _verifiedByController, isMandatory: false, hintText: 'Enter name...'),
              _buildTextField(label: 'APPROVED BY', controller: _approvedByController, isMandatory: false, hintText: 'Enter name...'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildValidationChecklist(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildValidationChecklist() {
    final hasCustomer = _doc['customer'] != null && _doc['customer'].toString().isNotEmpty;
    final hasCustomerName = _customerNameController.text.trim().isNotEmpty;
    final hasArabicCustomerName = _arabicCustomerNameController.text.trim().isNotEmpty;
    final hasItems = (_doc['items'] as List).isNotEmpty;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('ORDER COMPLIANCE VALIDATION', Icons.verified_user_rounded),
          const SizedBox(height: 16),
          _buildChecklistRow('Customer Code Specified', hasCustomer),
          _buildChecklistRow('Customer Name (English) Filled', hasCustomerName),
          _buildChecklistRow('Customer Name (Arabic) Filled', hasArabicCustomerName),
          _buildChecklistRow('At least one item added', hasItems),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: isDone ? AppColors.approvedMD : AppColors.error, size: 20),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  // --- Sticky Bottom Aggregation Panel ---
  Widget _buildStickyTotalsPanel() {
    final double totalQty = (_doc['total_qty'] as num? ?? 0.0).toDouble();
    final double grandTotal = (_doc['grand_total'] as num? ?? 0.0).toDouble();
    final int itemLength = (_doc['items'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: AppColors.border, width: 1.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _totalsScaleAnimation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRAND TOTAL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Row(
                      textBaseline: TextBaseline.alphabetic,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      children: [
                        Text('QAR ', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        Text(
                          grandTotal.toStringAsFixed(2),
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('AGGREGATE STATISTICS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Text('$itemLength ITEMS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Text('${totalQty.toStringAsFixed(0)} TOTAL QTY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          ScaleButton(
            onTap: _saveSalesOrder,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Text(
              widget.salesOrder != null ? 'UPDATE SALES ORDER' : 'CREATE SALES ORDER',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTextLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textLight, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildCardHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldContainer({required String label, required bool isMandatory, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              if (isMandatory) const Text(' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _getInputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      suffixIcon: suffixIcon,
      errorStyle: GoogleFonts.outfit(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.error, width: 1.0)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isMandatory,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return _buildFieldContainer(
      label: label,
      isMandatory: isMandatory,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
        decoration: _getInputDecoration(hintText: hintText),
        validator: (value) {
          if (isMandatory && (value == null || value.trim().isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildArabicField({
    required String label,
    required TextEditingController controller,
    required bool isMandatory,
    int maxLines = 1,
    String? hintText,
  }) {
    return _buildFieldContainer(
      label: label,
      isMandatory: isMandatory,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
        decoration: _getInputDecoration(hintText: hintText ?? 'أدخل التفاصيل باللغة العربية...'),
        validator: (value) {
          if (isMandatory && (value == null || value.trim().isEmpty)) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return _buildFieldContainer(
      label: label,
      isMandatory: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            value: options.contains(value) ? value : options.first,
            dropdownColor: Colors.white,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14), border: InputBorder.none),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textLight),
            items: options.map((String opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(opt),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String? value,
    required ValueChanged<String> onSelected,
  }) {
    return _buildFieldContainer(
      label: label,
      isMandatory: true,
      child: InkWell(
        onTap: () async {
          final current = value != null ? DateTime.tryParse(value) : DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            ),
          );
          if (date != null) {
            onSelected(DateFormat('yyyy-MM-dd').format(date));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value ?? 'Pick Date',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: value != null ? AppColors.textPrimary : AppColors.textLight,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorTrigger({required String? value, required String hint, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: value != null ? AppColors.textPrimary : AppColors.textLight,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog({
    required String title,
    required String doctype,
    Map<String, dynamic>? filters,
    required Function(String) onSelected,
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        child: Column(
          children: [
            Container(
              width: 45,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.0),
              ),
            ),
            const Divider(color: AppColors.border),
            Expanded(
              child: SearchableList(
                doctype: doctype,
                filters: filters,
                onSelected: onSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dynamic Sliding Segmented Control Widget ---
class SlidingSegmentedControl extends StatelessWidget {
  final String activeValue;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const SlidingSegmentedControl({
    super.key,
    required this.activeValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeIndex = options.indexOf(activeValue);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                left: activeIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: options.map((opt) {
                  final isActive = opt == activeValue;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(opt),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isActive ? AppColors.primary : AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                          child: Text(opt.toUpperCase()),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Glassmorphic Container Wrapper ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color border;
  final Color fill;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 10.0,
    this.border = AppColors.border,
    this.fill = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

// --- Reusable Press-Scale Animation Button ---
class ScaleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final double height;
  final double borderRadius;
  final Border? border;

  const ScaleButton({
    super.key,
    required this.onTap,
    required this.child,
    this.gradient,
    this.color,
    this.height = 56,
    this.borderRadius = 16,
    this.border,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTap != null ? _controller.forward() : null,
      onTapUp: (_) => widget.onTap != null ? _controller.reverse() : null,
      onTapCancel: () => widget.onTap != null ? _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.gradient == null ? (widget.color ?? AppColors.primary) : null,
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border,
            boxShadow: [
              if (widget.onTap != null && widget.color != Colors.transparent)
                BoxShadow(
                  color: (widget.color ?? AppColors.primary).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// --- Searchable Auto-Completer linking sales_order namespace ---
class SearchableList extends StatefulWidget {
  final String doctype;
  final Function(String) onSelected;
  final Map<String, dynamic>? filters;

  const SearchableList({
    super.key,
    required this.doctype,
    required this.onSelected,
    this.filters,
  });

  @override
  State<SearchableList> createState() => _SearchableListState();
}

class _SearchableListState extends State<SearchableList> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _filteredItems = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _onSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _onSearch(query);
    });
  }

  void _onSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      dynamic results;
      
      // Standard Frappe resource fallbacks
      if (widget.doctype == 'Company') {
        try {
          final res = await _apiClient.get('../resource/Company');
          results = res['data'];
        } catch (_) {}
      } else if (widget.doctype == 'Payment Terms Template') {
        try {
          final res = await _apiClient.get('../resource/Payment Terms Template');
          results = res['data'];
        } catch (_) {}
      }

      if (results == null) {
        // Query correct sales_order endpoints as primary
        dynamic res;
        try {
          res = await _apiClient.get(
            'oasis_mobile.api.sales_order.search_link',
            params: {
              'doctype': widget.doctype,
              'txt': query,
              if (widget.filters != null) 'filters': jsonEncode(widget.filters),
            },
          );
        } catch (_) {
          // Graceful fallback to quotation endpoint if sales_order lookup doesn't exist yet
          res = await _apiClient.get(
            'oasis_mobile.api.quotation.search_link',
            params: {
              'doctype': widget.doctype,
              'txt': query,
              if (widget.filters != null) 'filters': jsonEncode(widget.filters),
            },
          );
        }
        
        if (res['status'] == 'success') {
          results = res['data'];
        } else if (res['message'] is List) {
          results = res['message'];
        } else if (res['message'] is Map) {
          results = res['message']['data'] ?? res['message']['results'];
        } else {
          results = res['results'];
        }
      } else if (query.isNotEmpty) {
        results = (results as List).where((item) {
          final String name = (item['name'] ?? '').toString().toLowerCase();
          final String val = (item['value'] ?? '').toString().toLowerCase();
          final String label = (item['label'] ?? '').toString().toLowerCase();
          final String companyName = (item['company_name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              val.contains(query.toLowerCase()) ||
              label.contains(query.toLowerCase()) ||
              companyName.contains(query.toLowerCase());
        }).toList();
      }
      
      setState(() {
        _filteredItems = (results as List<dynamic>?) ?? [];
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search failed: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            autofocus: true,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Type to search...',
              hintStyle: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
              fillColor: const Color(0xFFF1F5F9),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.0)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 1.0)),
            ),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No matches found.',
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final String val = (item['value'] ?? item['name'] ?? 'N/A').toString();
                    final String label = (item['label'] ?? item['customer_name'] ?? item['item_name'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        title: Text(
                          val,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                        ),
                        subtitle: label.isNotEmpty
                            ? Text(
                                label,
                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              )
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textLight),
                        onTap: () {
                          widget.onSelected(val);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
