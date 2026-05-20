import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/quotation/models/quotation_model.dart';

class QuotationFormScreen extends StatefulWidget {
  final Quotation? quotation;
  const QuotationFormScreen({super.key, this.quotation});

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  Map<String, dynamic> _doc = {};

  // Form Field Controllers (for smooth reactive updating during API auto-fills)
  late TextEditingController _customerNameController;
  late TextEditingController _arabicCustomerNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _contactDisplayController;
  late TextEditingController _contactMobileController;
  late TextEditingController _contactEmailController;
  
  // Project-specific Controllers
  late TextEditingController _subjectController;
  late TextEditingController _refController;
  late TextEditingController _arabicSubjectController;
  late TextEditingController _brandNameController;
  late TextEditingController _brandNameArabicController;
  late TextEditingController _countryOfOriginController;
  late TextEditingController _countryOfOriginArabicController;
  
  // AMC-specific Controllers
  late TextEditingController _noOfVisitsController;
  late TextEditingController _contractPeriodController;
  late TextEditingController _contractPeriodArabicController;
  
  // Terms & Conditions Controllers
  late TextEditingController _warrantyEngController;
  late TextEditingController _warrantyArabicController;
  late TextEditingController _completionPeriodEngController;
  late TextEditingController _completionPeriodArabicController;
  
  // Scope of Work & Exclusions Controllers
  late TextEditingController _scopeOfWorkController;
  late TextEditingController _scopeOfWorkArabicController;
  late TextEditingController _exclusionsEngController;
  late TextEditingController _exclusionsArabicController;
  
  // Payment Terms Controllers
  late TextEditingController _paymentTermsEngController;
  late TextEditingController _paymentTermsArabicController;

  // Animation Controllers for UI polish
  late AnimationController _totalsAnimController;
  late Animation<double> _totalsScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set up standard scale-bounce animation for recalculated totals
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
    String nextMonthStr = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
    // Populate default document structures
    if (widget.quotation != null) {
      final q = widget.quotation!;
      _doc = {
        'name': q.name,
        'company': q.company,
        'transaction_date': q.transactionDate.isNotEmpty ? q.transactionDate : todayStr,
        'valid_till': q.validTill.isNotEmpty ? q.validTill : nextMonthStr,
        'quotation_to': q.quotationTo.isNotEmpty ? q.quotationTo : 'Customer',
        'party_name': q.partyName,
        'customer_name': q.customerName,
        'custom_customer_name_in_arabic': q.customCustomerNameInArabic,
        'currency': q.currency.isNotEmpty ? q.currency : 'QAR',
        'selling_price_list': q.sellingPriceList.isNotEmpty ? q.sellingPriceList : 'Standard Selling',
        'disable_rounded_total': q.disableRoundedTotal,
        'payment_terms_template': q.paymentTermsTemplate,
        'contact_person': '',
        'contact_display': q.customContactNameArabic,
        'contact_mobile': q.customContactMobileNoArabic,
        'contact_email': '', 
        'custom_quote_type': q.customQuoteType.isNotEmpty ? q.customQuoteType : 'Retail',
        'custom_retail_quote_type': q.orderType == 'Sales' ? 'Supply Only' : 'Supply with Installation',
        'custom_subject': q.customSubject,
        'custom_ref': q.customRef,
        'custom_subject_in_arabic': q.customSubjectInArabic,
        'custom_material_brand': q.customMaterialBrand.map((x) => x.toJson()).toList(),
        'custom_brand_name': q.customBrandName,
        'custom_brand_name_in_arabic': q.customBrandNameInArabic,
        'custom_country_of_origin': q.customCountryOfOrigin,
        'custom_country_of_origin_in_arabic': q.customCountryOfOriginInArabic,
        'custom_amc_period': q.customAmcPeriod,
        'custom_no_of_visits': int.tryParse(q.customNoOfVisits) ?? 0,
        'custom_contract_period': q.customContractPeriod,
        'custom_contract_period_in_arabic': q.customContractPeriodInArabic,
        'custom_warranty_eng': q.customWarrantyEng,
        'custom_warranty_arabic': q.customWarrantyArabic,
        'custom_completion_period_eng': q.customCompletionPeriodEng,
        'custom_completion_period_arabic': q.customCompletionPeriodArabic,
        'custom_scope_of_work': q.customScopeOfWork,
        'custom_scope_of_work_in_arabic': q.customScopeOfWorkInArabic,
        'custom_exclusions_eng': q.customExclusionsEng,
        'custom_exclusions_in_arabic': q.customExclusionsInArabic,
        'custom_payment_terms_eng': q.customPaymentTermsEng,
        'custom_payment_terms_arabic': q.customPaymentTermsArabic,
        'items': q.items.map((e) => e.toJson()).toList(),
        'custom_project_item': q.customProjectItem.map((x) => x.toJson()).toList(),
        'payment_schedule': q.paymentSchedule.map((x) => x.toJson()).toList(),
      };
    } else {
      // Setup pristine fresh creation defaults
      _doc = {
        'company': 'Oasis Trading and Importing HVAC',
        'transaction_date': todayStr,
        'valid_till': nextMonthStr,
        'quotation_to': 'Customer',
        'party_name': null,
        'customer_name': '',
        'custom_customer_name_in_arabic': '',
        'currency': 'QAR',
        'naming_series': 'SAL-QTN-.YYYY.-',
        'custom_quote_type': 'Retail',
        'custom_retail_quote_type': 'Supply Only',
        'custom_subject': '',
        'custom_ref': '',
        'custom_subject_in_arabic': '',
        'custom_material_brand': <Map<String, dynamic>>[],
        'custom_brand_name': '',
        'custom_brand_name_in_arabic': '',
        'custom_country_of_origin': '',
        'custom_country_of_origin_in_arabic': '',
        'custom_amc_period': '1 Year',
        'custom_no_of_visits': 4,
        'custom_contract_period': '',
        'custom_contract_period_in_arabic': '',
        'custom_warranty_eng': '',
        'custom_warranty_arabic': '',
        'custom_completion_period_eng': '',
        'custom_completion_period_arabic': '',
        'custom_scope_of_work': '',
        'custom_scope_of_work_in_arabic': '',
        'custom_exclusions_eng': '',
        'custom_exclusions_in_arabic': '',
        'custom_payment_terms_eng': '',
        'custom_payment_terms_arabic': '',
        'items': <Map<String, dynamic>>[],
        'custom_project_item': <Map<String, dynamic>>[],
        'payment_terms_template': '',
        'payment_schedule': <Map<String, dynamic>>[],
        'total_qty': 0.0,
        'total': 0.0,
        'base_total': 0.0,
        'grand_total': 0.0,
        'rounded_total': 0.0,
        'rounding_adjustment': 0.0,
        'total_taxes_and_charges': 0.0,
      };
    }

    _setupControllers();
  }

  void _setupControllers() {
    _customerNameController = TextEditingController(text: _doc['customer_name']);
    _arabicCustomerNameController = TextEditingController(text: _doc['custom_customer_name_in_arabic']);
    _contactPersonController = TextEditingController(text: _doc['contact_person']);
    _contactDisplayController = TextEditingController(text: _doc['contact_display']);
    _contactMobileController = TextEditingController(text: _doc['contact_mobile']);
    _contactEmailController = TextEditingController(text: _doc['contact_email']);
    
    _subjectController = TextEditingController(text: _doc['custom_subject']);
    _refController = TextEditingController(text: _doc['custom_ref']);
    _arabicSubjectController = TextEditingController(text: _doc['custom_subject_in_arabic']);
    _brandNameController = TextEditingController(text: _doc['custom_brand_name']);
    _brandNameArabicController = TextEditingController(text: _doc['custom_brand_name_in_arabic']);
    _countryOfOriginController = TextEditingController(text: _doc['custom_country_of_origin']);
    _countryOfOriginArabicController = TextEditingController(text: _doc['custom_country_of_origin_in_arabic']);
    
    _noOfVisitsController = TextEditingController(text: _doc['custom_no_of_visits']?.toString());
    _contractPeriodController = TextEditingController(text: _doc['custom_contract_period']);
    _contractPeriodArabicController = TextEditingController(text: _doc['custom_contract_period_in_arabic']);
    
    _warrantyEngController = TextEditingController(text: _doc['custom_warranty_eng']);
    _warrantyArabicController = TextEditingController(text: _doc['custom_warranty_arabic']);
    _completionPeriodEngController = TextEditingController(text: _doc['custom_completion_period_eng']);
    _completionPeriodArabicController = TextEditingController(text: _doc['custom_completion_period_arabic']);
    
    _scopeOfWorkController = TextEditingController(text: _doc['custom_scope_of_work']);
    _scopeOfWorkArabicController = TextEditingController(text: _doc['custom_scope_of_work_in_arabic']);
    _exclusionsEngController = TextEditingController(text: _doc['custom_exclusions_eng']);
    _exclusionsArabicController = TextEditingController(text: _doc['custom_exclusions_in_arabic']);
    _paymentTermsEngController = TextEditingController(text: _doc['custom_payment_terms_eng']);
    _paymentTermsArabicController = TextEditingController(text: _doc['custom_payment_terms_arabic']);
    
    // Standard event listeners to sync values instantly from Controllers into _doc Map
    _customerNameController.addListener(() => _doc['customer_name'] = _customerNameController.text);
    _arabicCustomerNameController.addListener(() => _doc['custom_customer_name_in_arabic'] = _arabicCustomerNameController.text);
    _contactPersonController.addListener(() => _doc['contact_person'] = _contactPersonController.text);
    _contactDisplayController.addListener(() => _doc['contact_display'] = _contactDisplayController.text);
    _contactMobileController.addListener(() => _doc['contact_mobile'] = _contactMobileController.text);
    _contactEmailController.addListener(() => _doc['contact_email'] = _contactEmailController.text);
    
    _subjectController.addListener(() => _doc['custom_subject'] = _subjectController.text);
    _refController.addListener(() => _doc['custom_ref'] = _refController.text);
    _arabicSubjectController.addListener(() => _doc['custom_subject_in_arabic'] = _arabicSubjectController.text);
    _brandNameController.addListener(() => _doc['custom_brand_name'] = _brandNameController.text);
    _brandNameArabicController.addListener(() => _doc['custom_brand_name_in_arabic'] = _brandNameArabicController.text);
    _countryOfOriginController.addListener(() => _doc['custom_country_of_origin'] = _countryOfOriginController.text);
    _countryOfOriginArabicController.addListener(() => _doc['custom_country_of_origin_in_arabic'] = _countryOfOriginArabicController.text);
    
    _noOfVisitsController.addListener(() {
      _doc['custom_no_of_visits'] = int.tryParse(_noOfVisitsController.text) ?? 0;
    });
    _contractPeriodController.addListener(() => _doc['custom_contract_period'] = _contractPeriodController.text);
    _contractPeriodArabicController.addListener(() => _doc['custom_contract_period_in_arabic'] = _contractPeriodArabicController.text);
    
    _warrantyEngController.addListener(() => _doc['custom_warranty_eng'] = _warrantyEngController.text);
    _warrantyArabicController.addListener(() => _doc['custom_warranty_arabic'] = _warrantyArabicController.text);
    _completionPeriodEngController.addListener(() => _doc['custom_completion_period_eng'] = _completionPeriodEngController.text);
    _completionPeriodArabicController.addListener(() => _doc['custom_completion_period_arabic'] = _completionPeriodArabicController.text);
    
    _scopeOfWorkController.addListener(() => _doc['custom_scope_of_work'] = _scopeOfWorkController.text);
    _scopeOfWorkArabicController.addListener(() => _doc['custom_scope_of_work_in_arabic'] = _scopeOfWorkArabicController.text);
    _exclusionsEngController.addListener(() => _doc['custom_exclusions_eng'] = _exclusionsEngController.text);
    _exclusionsArabicController.addListener(() => _doc['custom_exclusions_in_arabic'] = _exclusionsArabicController.text);
    _paymentTermsEngController.addListener(() => _doc['custom_payment_terms_eng'] = _paymentTermsEngController.text);
    _paymentTermsArabicController.addListener(() => _doc['custom_payment_terms_arabic'] = _paymentTermsArabicController.text);
  }

  @override
  void dispose() {
    _disposeControllers();
    _totalsAnimController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    _customerNameController.dispose();
    _arabicCustomerNameController.dispose();
    _contactPersonController.dispose();
    _contactDisplayController.dispose();
    _contactMobileController.dispose();
    _contactEmailController.dispose();
    
    _subjectController.dispose();
    _refController.dispose();
    _arabicSubjectController.dispose();
    _brandNameController.dispose();
    _brandNameArabicController.dispose();
    _countryOfOriginController.dispose();
    _countryOfOriginArabicController.dispose();
    
    _noOfVisitsController.dispose();
    _contractPeriodController.dispose();
    _contractPeriodArabicController.dispose();
    
    _warrantyEngController.dispose();
    _warrantyArabicController.dispose();
    _completionPeriodEngController.dispose();
    _completionPeriodArabicController.dispose();
    
    _scopeOfWorkController.dispose();
    _scopeOfWorkArabicController.dispose();
    _exclusionsEngController.dispose();
    _exclusionsArabicController.dispose();
    _paymentTermsEngController.dispose();
    _paymentTermsArabicController.dispose();
  }

  // --- Real-time Calculation Engine ---
  void _recalculateTotals() {
    double totalQty = 0;
    double totalNet = 0;

    // Summing standard items table rows
    final itemsList = _doc['items'] as List<dynamic>? ?? [];
    for (var item in itemsList) {
      final qty = (item['qty'] ?? 0.0) as double;
      final rate = (item['rate'] ?? 0.0) as double;
      totalQty += qty;
      totalNet += qty * rate;
    }

    setState(() {
      _doc['total_qty'] = totalQty;
      _doc['total'] = totalNet;
      _doc['base_total'] = totalNet;
      
      final taxes = (_doc['total_taxes_and_charges'] ?? 0.0) as double;
      final grandTotal = totalNet + taxes;
      _doc['grand_total'] = grandTotal;
      
      final int disableRounded = (_doc['disable_rounded_total'] ?? 0) as int;
      if (disableRounded == 1) {
        _doc['rounded_total'] = grandTotal;
        _doc['rounding_adjustment'] = 0.0;
      } else {
        final roundedTotal = grandTotal.roundToDouble();
        _doc['rounded_total'] = roundedTotal;
        _doc['rounding_adjustment'] = roundedTotal - grandTotal;
      }
    });

    // Run the beautiful scale bounce animation
    _totalsAnimController.forward(from: 0.0);

    // Auto-trigger payment schedule splits if a template is active
    if (_doc['payment_terms_template'] != null && _doc['payment_terms_template'].toString().isNotEmpty) {
      _fetchPaymentTermsDetails(_doc['payment_terms_template'].toString(), _doc['grand_total']);
    }
  }

  // --- Fetch Payment Milestones & Auto-Fill ---
  Future<void> _fetchPaymentTermsDetails(String template, double grandTotal) async {
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.quotation.get_payment_terms_details',
        params: {
          'template': template,
          'grand_total': grandTotal.toString(),
        },
      );
      if (res['status'] == 'success' && res['terms'] != null) {
        setState(() {
          _doc['payment_schedule'] = List<Map<String, dynamic>>.from(res['terms']);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch payment terms: $e");
    }
  }

  // --- Auto-Fill & Customer APIs Integration ---
  Future<void> _fetchAndAutoFillCustomer(String customerCode) async {
    setState(() => _isLoading = true);
    dynamic data;
    try {
      // Primary attempt: Use the custom API endpoint
      final res = await _apiClient.get(
        'oasis_mobile.api.quotation.get_customer_details',
        params: {'customer': customerCode},
      );
      data = res['status'] == 'success' ? res : (res['message'] ?? res);
    } catch (e) {
      debugPrint('Primary customer details API failed, attempting resource fallback: $e');
      try {
        // Fallback: Fetch standard Customer document directly using Frappe REST API
        final encodedCode = Uri.encodeComponent(customerCode);
        final res = await _apiClient.get(
          '../resource/Customer/$encodedCode',
        );
        final doc = res['data'];
        if (doc != null) {
          data = {
            'customer_name': doc['customer_name'] ?? doc['name'] ?? customerCode,
            'custom_customer_name_in_arabic': doc['custom_customer_name_in_arabic'] ?? '',
            'contact_person': doc['customer_primary_contact'] ?? '',
            'contact_display': '',
            'contact_mobile': '',
            'contact_email': '',
          };
        }
      } catch (fallbackError) {
        debugPrint('Fallback customer resource API failed: $fallbackError');
      }
    }

    if (data != null && data['status'] != 'error') {
      setState(() {
        _doc['customer_name'] = data['customer_name'] ?? '';
        _doc['custom_customer_name_in_arabic'] = data['custom_customer_name_in_arabic'] ?? '';
        _doc['contact_person'] = data['contact_person'] ?? '';
        _doc['contact_display'] = data['contact_display'] ?? '';
        _doc['contact_mobile'] = data['contact_mobile'] ?? '';
        _doc['contact_email'] = data['contact_email'] ?? '';
        
        // Re-populate text controllers
        _customerNameController.text = _doc['customer_name'];
        _arabicCustomerNameController.text = _doc['custom_customer_name_in_arabic'];
        _contactPersonController.text = _doc['contact_person'];
        _contactDisplayController.text = _doc['contact_display'];
        _contactMobileController.text = _doc['contact_mobile'];
        _contactEmailController.text = _doc['contact_email'];
      });
    } else {
      // If both failed, we can still pre-fill the customer code as customer name to save user time
      setState(() {
        _doc['customer_name'] = customerCode;
        _customerNameController.text = customerCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text(
            'Unable to auto-fill details due to server issue. You can type them manually.',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  // --- Save / Create Quotation POST Trigger ---
  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please fill out all required fields.', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_doc['items'].isEmpty && _doc['custom_project_item'].isEmpty) {
        throw Exception('Quotation must contain at least one item.');
      }

      // Final dynamic adjustments based on Mode rules
      final mode = _doc['custom_quote_type'];
      if (mode == 'AMC') {
        _doc['custom_warranty_eng'] = '';
        _doc['custom_warranty_arabic'] = '';
        _doc['custom_completion_period_eng'] = '';
        _doc['custom_completion_period_arabic'] = '';
      }

      // ERPNext expects integer formats for checks and dropdown matches
      final response = await _apiClient.post(
        'oasis_mobile.api.quotation.create_quotation',
        {'data': _doc},
      );

      final status = response['status'] ?? response['message']?['status'];
      if (status == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.approvedMD,
              content: Text('Quotation created successfully!', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
          Navigator.pop(context, true);
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
  @override
  Widget build(BuildContext context) {
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
            widget.quotation != null ? 'EDIT QUOTATION' : 'NEW QUOTATION',
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

  Widget _buildClientTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('CUSTOMER INFORMATION', Icons.person_rounded),
              const SizedBox(height: 16),
              // Company selector
              _buildFieldContainer(
                label: 'COMPANY',
                isMandatory: true,
                child: _buildSelectorTrigger(
                  value: _doc['company'],
                  hint: 'Select Company...',
                  onTap: () => _showSearchDialog(
                    title: 'Select Company',
                    doctype: 'Company',
                    onSelected: (selectedCompany) => setState(() => _doc['company'] = selectedCompany),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildDropdownField(
                label: 'QUOTATION TO',
                value: _doc['quotation_to'],
                options: const ['Customer', 'Lead'],
                onChanged: (val) {
                  setState(() {
                    _doc['quotation_to'] = val;
                    _doc['party_name'] = null;
                    _doc['customer_name'] = '';
                    _doc['custom_customer_name_in_arabic'] = '';
                    _customerNameController.clear();
                    _arabicCustomerNameController.clear();
                  });
                },
              ),
              _buildFieldContainer(
                label: 'PARTY CODE',
                isMandatory: true,
                child: _buildSelectorTrigger(
                  value: _doc['party_name'],
                  hint: 'Search code...',
                  onTap: () => _showSearchDialog(
                    title: 'Search ${_doc['quotation_to']}',
                    doctype: _doc['quotation_to'] == 'Customer' ? 'Customer' : 'Lead',
                    onSelected: (selectedParty) {
                      setState(() => _doc['party_name'] = selectedParty);
                      _fetchAndAutoFillCustomer(selectedParty);
                    },
                  ),
                ),
              ),
              _buildTextField(label: 'CUSTOMER NAME', controller: _customerNameController, isMandatory: true, hintText: 'Enter customer name...'),
              _buildArabicField(label: 'CUSTOMER NAME (ARABIC)', controller: _arabicCustomerNameController, isMandatory: true, hintText: 'الاسم بالكامل باللغة العربية...'),
              Row(
                children: [
                  Expanded(child: _buildDateField(label: 'DATE', value: _doc['transaction_date'], onSelected: (val) => setState(() => _doc['transaction_date'] = val))),
                  const SizedBox(width: 14),
                  Expanded(child: _buildDateField(label: 'VALID TILL', value: _doc['valid_till'], onSelected: (val) => setState(() => _doc['valid_till'] = val))),
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
              _buildCardHeader('CONTACT & CORRESPONDENCE', Icons.contact_phone_rounded),
              const SizedBox(height: 16),
              _buildTextField(label: 'CONTACT PERSON ID', controller: _contactPersonController, isMandatory: false, hintText: 'Auto-filled...'),
              _buildTextField(label: 'DISPLAY NAME', controller: _contactDisplayController, isMandatory: false, hintText: 'Auto-filled...'),
              _buildTextField(label: 'MOBILE NUMBER', controller: _contactMobileController, isMandatory: false, keyboardType: TextInputType.phone, hintText: 'Auto-filled...'),
              _buildTextField(label: 'EMAIL ADDRESS', controller: _contactEmailController, isMandatory: false, keyboardType: TextInputType.emailAddress, hintText: 'Auto-filled...'),
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
        SlidingSegmentedControl(
          activeValue: _doc['custom_quote_type'] ?? 'Retail',
          options: const ['Retail', 'Project', 'AMC'],
          onChanged: (newMode) {
            setState(() {
              _doc['custom_quote_type'] = newMode;
              _recalculateTotals();
            });
          },
        ),
        const SizedBox(height: 20),
        if (_doc['custom_quote_type'] == 'Retail') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('RETAIL QUOTATION SETTINGS', Icons.shopping_bag_rounded),
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
        if (_doc['custom_quote_type'] == 'Project' || _doc['custom_quote_type'] == 'AMC') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('TECHNICAL SPECS & BRANDING', Icons.business_center_rounded),
                const SizedBox(height: 16),
                _buildTextField(label: 'SUBJECT / OBJECTIVE', controller: _subjectController, isMandatory: true, hintText: 'Subject in English...'),
                _buildArabicField(label: 'SUBJECT (ARABIC)', controller: _arabicSubjectController, isMandatory: true, hintText: 'الموضوع باللغة العربية...'),
                _buildTextField(label: 'REFERENCE NUMBER', controller: _refController, isMandatory: false, hintText: 'e.g. QTN-REF-2026-X'),
                _buildTextField(label: 'BRAND NAME', controller: _brandNameController, isMandatory: false, hintText: 'e.g. Mitsubishi'),
                _buildArabicField(label: 'BRAND NAME (ARABIC)', controller: _brandNameArabicController, isMandatory: false, hintText: 'اسم العلامة التجارية باللغة العربية...'),
                _buildTextField(label: 'COUNTRY OF ORIGIN', controller: _countryOfOriginController, isMandatory: false, hintText: 'e.g. Japan / Thailand'),
                _buildArabicField(label: 'COUNTRY OF ORIGIN (ARABIC)', controller: _countryOfOriginArabicController, isMandatory: false, hintText: 'بلد المنشأ باللغة العربية...'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_doc['custom_quote_type'] == 'AMC') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('ANNUAL MAINTENANCE TERMS', Icons.handyman_rounded),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'AMC PERIOD DURATION',
                  value: _doc['custom_amc_period'],
                  options: const ['30 Days', '3 Months', '6 Months', '1 Year'],
                  onChanged: (val) => setState(() => _doc['custom_amc_period'] = val),
                ),
                _buildTextField(label: 'NUMBER OF SCHEDULED VISITS', controller: _noOfVisitsController, isMandatory: true, keyboardType: TextInputType.number, hintText: 'e.g. 4'),
                _buildTextField(label: 'CONTRACT PERIOD', controller: _contractPeriodController, isMandatory: true, hintText: 'e.g. 01-10-2025 TO 30-09-2026'),
                _buildArabicField(label: 'CONTRACT PERIOD (ARABIC)', controller: _contractPeriodArabicController, isMandatory: true, hintText: 'الفترة باللغة العربية...'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildItemsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildStandardItemsTable(),
        if (_doc['custom_quote_type'] == 'Project') ...[
          const SizedBox(height: 16),
          _buildMaterialBrandTable(),
          const SizedBox(height: 16),
          _buildProjectItemsTable(),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_doc['custom_quote_type'] == 'Project' || _doc['custom_quote_type'] == 'AMC') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('SCOPE OF WORK & EXCLUSIONS', Icons.description_rounded),
                const SizedBox(height: 16),
                _buildTextField(label: 'SCOPE OF WORK (ENGLISH)', controller: _scopeOfWorkController, isMandatory: false, maxLines: 3, hintText: 'Scope...'),
                _buildArabicField(label: 'SCOPE OF WORK (ARABIC)', controller: _scopeOfWorkArabicController, isMandatory: false, maxLines: 3, hintText: 'نطاق العمل...'),
                _buildTextField(label: 'EXCLUSIONS (ENGLISH)', controller: _exclusionsEngController, isMandatory: false, maxLines: 3, hintText: 'Exclusions...'),
                _buildArabicField(label: 'EXCLUSIONS (ARABIC)', controller: _exclusionsArabicController, isMandatory: false, maxLines: 3, hintText: 'الاستثناءات...'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_doc['custom_quote_type'] != 'AMC') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('WARRANTY & COMPLETION CLAUSES', Icons.verified_user_rounded),
                const SizedBox(height: 16),
                _buildTextField(label: 'WARRANTY TERMS (ENGLISH)', controller: _warrantyEngController, isMandatory: false, maxLines: 2, hintText: 'Warranty details...'),
                _buildArabicField(label: 'WARRANTY TERMS (ARABIC)', controller: _warrantyArabicController, isMandatory: false, maxLines: 2, hintText: 'شروط الضمان...'),
                _buildTextField(label: 'COMPLETION CLAUSE (ENGLISH)', controller: _completionPeriodEngController, isMandatory: false, maxLines: 2, hintText: 'Completion terms...'),
                _buildArabicField(label: 'COMPLETION CLAUSE (ARABIC)', controller: _completionPeriodArabicController, isMandatory: false, maxLines: 2, hintText: 'فترة الإنجاز...'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_doc['custom_quote_type'] == 'Project' || _doc['custom_quote_type'] == 'AMC') ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('COMMERCIAL & PAYMENT TERMS', Icons.payments_rounded),
                const SizedBox(height: 16),
                _buildFieldContainer(
                  label: 'PAYMENT TERMS TEMPLATE',
                  isMandatory: false,
                  child: _buildSelectorTrigger(
                    value: _doc['payment_terms_template']?.toString().isNotEmpty == true
                        ? _doc['payment_terms_template']
                        : null,
                    hint: 'Select Payment Terms Template...',
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
                _buildTextField(label: 'PAYMENT TERMS (ENGLISH)', controller: _paymentTermsEngController, isMandatory: false, maxLines: 3, hintText: 'Terms in English...'),
                _buildArabicField(label: 'PAYMENT TERMS (ARABIC)', controller: _paymentTermsArabicController, isMandatory: false, maxLines: 3, hintText: 'شروط الدفع...'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentScheduleTable(),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  // --- Widget Builders for Sleek Glassmorphism UI ---

  Widget _buildCardHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 1.2,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? 'Pick Date',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: value != null ? AppColors.textPrimary : AppColors.textLight,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textLight),
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

  // --- Autocomplete Bottom Sheet Search Dialog Builder ---
  void _showSearchDialog({
    required String title,
    required String doctype,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
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
                  onSelected: onSelected,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Standard Items Table Custom UI ---
  Widget _buildStandardItemsTable() {
    final List<dynamic> itemsList = _doc['items'] ?? [];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('STANDARD ITEMS CHILD TABLE', Icons.inventory_2_outlined),
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
                      'No Standard Items Added Yet.',
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
                                onPressed: () => _showStandardItemEditorSheet(index),
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
                          _buildMiniTextLabel('RATE', 'QAR ${double.parse((item['price_list_rate'] ?? 0.0).toString()).toStringAsFixed(2)}'),
                          _buildMiniTextLabel('MARGIN', item['margin_type'] == 'Percentage' ? '${item['margin_rate_or_amount']}%' : 'QAR ${item['margin_rate_or_amount']}'),
                          _buildMiniTextLabel('NET UNIT', 'QAR ${double.parse((item['rate'] ?? 0.0).toString()).toStringAsFixed(2)}'),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL AMOUNT',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                          ),
                          Text(
                            'QAR ${double.parse((item['amount'] ?? 0.0).toString()).toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          ScaleButton(
            onTap: () => _showStandardItemEditorSheet(-1),
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

  // --- Add/Edit Standard Item Details Interactive Sheet with Real-Time Math ---
  void _showStandardItemEditorSheet(final int editIndex) {
    final Map<String, dynamic> localItem = editIndex >= 0
        ? Map<String, dynamic>.from((_doc['items'] as List)[editIndex])
        : {
            'item_code': null,
            'qty': 1.0,
            'price_list_rate': 0.0,
            'margin_type': 'Amount',
            'margin_rate_or_amount': 0.0,
            'rate_with_margin': 0.0,
            'discount_percentage': 0.0,
            'discount_amount': 0.0,
            'rate': 0.0,
            'amount': 0.0,
            'brand': '',
            'description': '',
            'uom': 'Nos',
          };

    final qtyController = TextEditingController(text: localItem['qty']?.toString());
    final priceListRateController = TextEditingController(text: localItem['price_list_rate']?.toString());
    final marginRateController = TextEditingController(text: localItem['margin_rate_or_amount']?.toString());
    final discountPercentController = TextEditingController(text: localItem['discount_percentage']?.toString());
    final discountAmountController = TextEditingController(text: localItem['discount_amount']?.toString());
    final discountPercentFocusNode = FocusNode();
    final discountAmountFocusNode = FocusNode();
    
    String marginType = localItem['margin_type'] ?? 'Amount';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Dynamic internal calculation logic that refreshes on typing
          void calculateOutputs() {
            final double basePrice = double.tryParse(priceListRateController.text) ?? 0.0;
            final double marginVal = double.tryParse(marginRateController.text) ?? 0.0;
            final double qty = double.tryParse(qtyController.text) ?? 1.0;

            double rateWithMargin = basePrice;
            if (marginType == 'Amount') {
              rateWithMargin = basePrice + marginVal;
            } else if (marginType == 'Percentage') {
              rateWithMargin = basePrice * (1 + marginVal / 100);
            }

            double discPct = 0.0;
            double discountAmount = 0.0;

            if (discountAmountFocusNode.hasFocus) {
              discountAmount = double.tryParse(discountAmountController.text) ?? 0.0;
              if (rateWithMargin > 0) {
                discPct = (discountAmount / rateWithMargin) * 100;
                discountPercentController.text = discPct.toStringAsFixed(2);
              }
            } else {
              discPct = double.tryParse(discountPercentController.text) ?? 0.0;
              discountAmount = rateWithMargin * (discPct / 100);
              if (discountPercentFocusNode.hasFocus || priceListRateController.text.isNotEmpty || marginRateController.text.isNotEmpty) {
                discountAmountController.text = discountAmount.toStringAsFixed(2);
              }
            }

            final double finalRate = rateWithMargin - discountAmount;
            final double amount = finalRate * qty;

            setSheetState(() {
              localItem['margin_type'] = marginType;
              localItem['rate_with_margin'] = rateWithMargin;
              localItem['discount_amount'] = discountAmount;
              localItem['rate'] = finalRate;
              localItem['amount'] = amount;
              localItem['qty'] = qty;
              localItem['price_list_rate'] = basePrice;
              localItem['margin_rate_or_amount'] = marginVal;
              localItem['discount_percentage'] = discPct;
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.6,
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
                    editIndex >= 0 ? 'EDIT STANDARD ITEM' : 'ADD STANDARD ITEM',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 20),

                  // Item Link Search Field
                  _buildFieldContainer(
                    label: 'ITEM CODE',
                    isMandatory: true,
                    child: _buildSelectorTrigger(
                      value: localItem['item_code'],
                      hint: 'Tap to select standard item...',
                      onTap: () => _showSearchDialog(
                        title: 'Search Item',
                        doctype: 'Item',
                        onSelected: (val) async {
                          setSheetState(() => localItem['item_code'] = val);
                          try {
                            final res = await _apiClient.get(
                              'oasis_mobile.api.quotation.get_item_details',
                              params: {
                                'item_code': val,
                                if (_doc['party_name'] != null) 'customer': _doc['party_name'].toString(),
                              },
                            );
                            final d = res['status'] == 'success' ? res : (res['message'] ?? res);
                            if (d != null && d['status'] != 'error') {
                              setSheetState(() {
                                priceListRateController.text = (d['rate'] ?? 0.0).toString();
                                localItem['item_name'] = d['item_name'] ?? '';
                                localItem['description'] = d['description'] ?? '';
                                localItem['uom'] = d['uom'] ?? 'Nos';
                                localItem['brand'] = d['brand'] ?? '';
                              });
                              calculateOutputs();
                            }
                          } catch (e) {
                            debugPrint('Error loading item rates: $e');
                          }
                        },
                      ),
                    ),
                  ),

                  // Quantity
                  _buildFieldContainer(
                    label: 'QUANTITY',
                    isMandatory: true,
                    child: TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 1.0'),
                      onChanged: (_) => calculateOutputs(),
                    ),
                  ),

                  // Price List Rate
                  _buildFieldContainer(
                    label: 'PRICE LIST RATE (QAR)',
                    isMandatory: true,
                    child: TextFormField(
                      controller: priceListRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 3000.00'),
                      onChanged: (_) => calculateOutputs(),
                    ),
                  ),

                  // Margin controls
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'MARGIN TYPE',
                          value: marginType,
                          options: const ['Amount', 'Percentage'],
                          onChanged: (val) {
                            marginType = val;
                            calculateOutputs();
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildFieldContainer(
                          label: 'MARGIN VALUE',
                          isMandatory: false,
                          child: TextFormField(
                            controller: marginRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                            decoration: _getInputDecoration(hintText: 'e.g. 10.0'),
                            onChanged: (_) => calculateOutputs(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Dual Discount Inputs
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
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                            decoration: _getInputDecoration(hintText: 'e.g. 5.0'),
                            onChanged: (_) => calculateOutputs(),
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
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                            decoration: _getInputDecoration(hintText: 'e.g. 150.00'),
                            onChanged: (_) => calculateOutputs(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Live Preview Computations Panel
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LIVE PRICING CALCULATION PREVIEW', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.accent, letterSpacing: 1.0)),
                        const SizedBox(height: 12),
                        _buildPreviewRow('Rate with Margin', 'QAR ${(localItem['rate_with_margin'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildPreviewRow('Discount Amount', 'QAR ${(localItem['discount_amount'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildPreviewRow('Net Unit Rate', 'QAR ${(localItem['rate'] ?? 0.0).toStringAsFixed(2)}'),
                        const Divider(color: AppColors.border, height: 16),
                        _buildPreviewRow('Computed Total', 'QAR ${(localItem['amount'] ?? 0.0).toStringAsFixed(2)}', highlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ScaleButton(
                    onTap: () {
                      if (localItem['item_code'] == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please select an item code first.', style: GoogleFonts.outfit())),
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
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                    child: Text(editIndex >= 0 ? 'UPDATE ITEM' : 'ADD ITEM', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 14),
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

  Widget _buildPreviewRow(String label, String val, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: highlight ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
          Text(val, style: GoogleFonts.outfit(color: highlight ? AppColors.primary : AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: highlight ? 15 : 13)),
        ],
      ),
    );
  }

  // --- Material Brand child table Widget ---
  Widget _buildMaterialBrandTable() {
    final List<dynamic> brands = _doc['custom_material_brand'] ?? [];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('MATERIAL BRANDS SPECIFIED', Icons.verified_rounded),
          const SizedBox(height: 16),
          if (brands.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.style_rounded, size: 42, color: AppColors.textLight),
                    const SizedBox(height: 10),
                    Text(
                      'No Material Brands Added.',
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
              itemCount: brands.length,
              itemBuilder: (context, index) {
                final row = brands[index];
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
                              'ROW #${index + 1}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 20),
                                onPressed: () => _showMaterialBrandEditorSheet(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 20),
                                onPressed: () {
                                  setState(() => brands.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (row['description'] != null && row['description'].toString().isNotEmpty) ...[
                        Text(
                          'Description: ${row['description']}',
                          style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniTextLabel('BRAND', row['brand'] ?? 'N/A'),
                          _buildMiniTextLabel('MAKE', row['make'] ?? 'N/A'),
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
            onTap: () => _showMaterialBrandEditorSheet(-1),
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

  void _showMaterialBrandEditorSheet(final int editIndex) {
    final Map<String, dynamic> localItem = editIndex >= 0
        ? Map<String, dynamic>.from((_doc['custom_material_brand'] as List)[editIndex])
        : {
            'description': '',
            'brand': '',
            'make': '',
          };

    final descController = TextEditingController(text: localItem['description']);
    final makeController = TextEditingController(text: localItem['make']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, sheetScrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: sheetScrollController,
                physics: const BouncingScrollPhysics(),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    editIndex >= 0 ? 'EDIT MATERIAL BRAND' : 'ADD MATERIAL BRAND',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  _buildFieldContainer(
                    label: 'DESCRIPTION',
                    isMandatory: true,
                    child: TextFormField(
                      controller: descController,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. Copper pipes 3/4 inch'),
                    ),
                  ),

                  // Brand (search trigger)
                  _buildFieldContainer(
                    label: 'BRAND',
                    isMandatory: true,
                    child: _buildSelectorTrigger(
                      value: localItem['brand'].toString().isNotEmpty ? localItem['brand'] : null,
                      hint: 'Search Brand...',
                      onTap: () => _showSearchDialog(
                        title: 'Search Brand',
                        doctype: 'Brand',
                        onSelected: (val) {
                          setSheetState(() => localItem['brand'] = val);
                        },
                      ),
                    ),
                  ),

                  // Make
                  _buildFieldContainer(
                    label: 'MAKE',
                    isMandatory: false,
                    child: TextFormField(
                      controller: makeController,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. Daikin Japan'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  ScaleButton(
                    onTap: () {
                      if (descController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a description.', style: GoogleFonts.outfit())),
                        );
                        return;
                      }

                      localItem['description'] = descController.text.trim();
                      localItem['make'] = makeController.text.trim();

                      setState(() {
                        if (editIndex >= 0) {
                          (_doc['custom_material_brand'] as List)[editIndex] = localItem;
                        } else {
                          (_doc['custom_material_brand'] as List).add(localItem);
                        }
                      });
                      Navigator.pop(context);
                    },
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                    child: Text(editIndex >= 0 ? 'UPDATE ROW' : 'ADD ROW', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
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

  // --- Project Mode: Custom Project Items Table ---
  Widget _buildProjectItemsTable() {
    final List<dynamic> projItems = _doc['custom_project_item'] ?? [];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('CUSTOM PROJECT ITEMS TABLE', Icons.draw_rounded),
          const SizedBox(height: 16),
          if (projItems.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.architecture_rounded, size: 42, color: AppColors.textLight),
                    const SizedBox(height: 10),
                    Text(
                      'No Project Items Specified.',
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
              itemCount: projItems.length,
              itemBuilder: (context, index) {
                final item = projItems[index];
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
                              (item['item'] ?? item['project_item'] ?? 'Project Item').toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 20),
                            onPressed: () {
                              setState(() => projItems.removeAt(index));
                              _recalculateTotals();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        Text(
                          item['description'].toString(),
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniTextLabel('QTY', '${item['qty']} ${item['uom'] ?? 'Nos'}'),
                          _buildMiniTextLabel('UOM', item['uom'] ?? 'Nos'),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          ScaleButton(
            onTap: _showProjectItemSelectorSheet,
            color: Colors.transparent,
            border: Border.all(color: AppColors.accent, width: 1.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_chart_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('ADD PROJECT ITEM', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectItemSelectorSheet() {
    final Map<String, dynamic> localItem = {
      'item': null,
      'description': '',
      'uom': 'Nos',
      'qty': 1.0,
    };

    final qtyController = TextEditingController(text: '1.0');
    final descController = TextEditingController(text: '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, sheetScrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: sheetScrollController,
                physics: const BouncingScrollPhysics(),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ADD CUSTOM PROJECT ITEM',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 24),

                  // Project Item autocompleting link trigger
                  _buildFieldContainer(
                    label: 'PROJECT ITEM LINK',
                    isMandatory: true,
                    child: _buildSelectorTrigger(
                      value: localItem['item'],
                      hint: 'Search Project Items in ERP...',
                      onTap: () => _showSearchDialog(
                        title: 'Search Project Item',
                        doctype: 'Project Item',
                        onSelected: (val) async {
                          setSheetState(() => localItem['item'] = val);
                          try {
                            final res = await _apiClient.get(
                              'oasis_mobile.api.quotation.get_project_item_details',
                              params: {'project_item': val},
                            );
                            final d = res['status'] == 'success' ? res : (res['message'] ?? res);
                            if (d != null) {
                              setSheetState(() {
                                localItem['uom'] = d['uom'] ?? 'Nos';
                                localItem['description'] = d['description'] ?? '';
                                descController.text = localItem['description'];
                              });
                            }
                          } catch (e) {
                            debugPrint('Error getting project item: $e');
                          }
                        },
                      ),
                    ),
                  ),

                  // Description
                  _buildFieldContainer(
                    label: 'DESCRIPTION',
                    isMandatory: false,
                    child: TextFormField(
                      controller: descController,
                      maxLines: 2,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'Enter item description...'),
                    ),
                  ),

                  // Quantity
                  _buildFieldContainer(
                    label: 'QUANTITY',
                    isMandatory: true,
                    child: TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                      decoration: _getInputDecoration(hintText: 'e.g. 1.0'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  ScaleButton(
                    onTap: () {
                      if (localItem['item'] == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please select a project item code first.', style: GoogleFonts.outfit())),
                        );
                        return;
                      }

                      localItem['description'] = descController.text.trim();
                      localItem['qty'] = double.tryParse(qtyController.text) ?? 1.0;

                      setState(() {
                        (_doc['custom_project_item'] as List).add(localItem);
                      });
                      _recalculateTotals();
                      Navigator.pop(context);
                    },
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                    child: Text('ADD PROJECT ITEM', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
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

  // --- Payment Milestones Table Widget ---
  Widget _buildPaymentScheduleTable() {
    final List<dynamic> schedule = _doc['payment_schedule'] ?? [];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('PAYMENT MILESTONES / SCHEDULE', Icons.schedule_rounded),
          const SizedBox(height: 16),
          if (schedule.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.payment_outlined, size: 42, color: AppColors.textLight),
                    const SizedBox(height: 10),
                    Text(
                      'No Payment Milestones Computed.',
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
              itemCount: schedule.length,
              itemBuilder: (context, index) {
                final term = schedule[index];
                final portion = (term['invoice_portion'] ?? 0.0) as double;
                final amount = (term['payment_amount'] ?? 0.0) as double;
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
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${portion.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (term['description'] != null && term['description'].toString().isNotEmpty) ...[
                        Text(
                          term['description'].toString(),
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MILESTONE AMOUNT',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                          ),
                          Text(
                            'QAR ${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // --- Sticky Bottom Aggregation Panel (Scale bounce effect) ---
  Widget _buildStickyTotalsPanel() {
    final double totalQty = (_doc['total_qty'] ?? 0.0) as double;
    final double grandTotal = (_doc['grand_total'] ?? 0.0) as double;
    final int itemLength = ((_doc['items'] as List?)?.length ?? 0) + ((_doc['custom_project_item'] as List?)?.length ?? 0);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISABLE ROUNDED TOTAL',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              Switch.adaptive(
                value: (_doc['disable_rounded_total'] ?? 0) == 1,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  setState(() {
                    _doc['disable_rounded_total'] = val ? 1 : 0;
                    _recalculateTotals();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                          child: Text('$totalQty TOTAL QTY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
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
            onTap: _saveQuotation,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Text(
              widget.quotation != null ? 'UPDATE QUOTATION' : 'CREATE QUOTATION',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Dynamic Custom Sliding Segmented Control Widget ---
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

// --- Glassmorphic Container Wrapper (Thin semi-transparent glows) ---
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

// --- Autocompleting List implementation integrating Search Link ---
class SearchableList extends StatefulWidget {
  final String doctype;
  final Function(String) onSelected;
  final ScrollController scrollController;

  const SearchableList({
    super.key,
    required this.doctype,
    required this.onSelected,
    required this.scrollController,
  });

  @override
  State<SearchableList> createState() => _SearchableListState();
}

class _SearchableListState extends State<SearchableList> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _filteredItems = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.doctype == 'Company' || widget.doctype == 'Payment Terms Template') {
      _onSearch('');
    }
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty && widget.doctype != 'Company' && widget.doctype != 'Payment Terms Template') {
      setState(() => _filteredItems = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      dynamic results;
      if (widget.doctype == 'Company') {
        try {
          final res = await _apiClient.get('../resource/Company');
          results = res['data'];
        } catch (resourceErr) {
          debugPrint('Company resource fetch failed, trying search_link: $resourceErr');
        }
      } else if (widget.doctype == 'Payment Terms Template') {
        try {
          final res = await _apiClient.get('../resource/Payment Terms Template');
          results = res['data'];
        } catch (resourceErr) {
          debugPrint('Payment Terms Template resource fetch failed, trying search_link: $resourceErr');
        }
      }

      if (results == null) {
        final res = await _apiClient.get(
          'oasis_mobile.api.quotation.search_link',
          params: {
            'doctype': widget.doctype,
            'txt': query,
          },
        );
        
        if (res['status'] == 'success') {
          results = res['data'];
        } else if (res['message'] is List) {
          results = res['message'];
        } else if (res['message'] is Map) {
          results = res['message']['data'] ?? res['message']['results'];
        } else {
          results = res['results'];
        }
      }
      
      setState(() {
        _filteredItems = (results as List<dynamic>?) ?? [];
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Autocomplete search failed: $e');
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
            onChanged: _onSearch,
            autofocus: true,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Type keyword to search...',
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
                      _searchController.text.isEmpty ? 'Type to search.' : 'No records found.',
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
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
