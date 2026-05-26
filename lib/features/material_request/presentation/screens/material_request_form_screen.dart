import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/material_request_model.dart';

class MaterialRequestFormScreen extends StatefulWidget {
  final MaterialRequestModel? materialRequest;
  final Map<String, dynamic>? initialData;
  const MaterialRequestFormScreen({super.key, this.materialRequest, this.initialData});

  @override
  State<MaterialRequestFormScreen> createState() => _MaterialRequestFormScreenState();
}

class _MaterialRequestFormScreenState extends State<MaterialRequestFormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  Map<String, dynamic> _doc = {};

  // Tab Navigation Controllers
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Form Field Controllers
  late TextEditingController _subjectController;
  late TextEditingController _remarksController;
  late TextEditingController _requestedByController;
  late TextEditingController _checkedByController;
  late TextEditingController _approvedByController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _initializeForm();
  }

  void _initializeForm() {
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (widget.materialRequest != null) {
      final mr = widget.materialRequest!;
      _doc = {
        'name': mr.name,
        'company': mr.company,
        'material_request_type': mr.materialRequestType,
        'transaction_date': mr.transactionDate.isNotEmpty ? mr.transactionDate : todayStr,
        'workflow_state': mr.workflowState ?? 'Draft',
        'custom_subject': mr.customSubject ?? '',
        'custom_customer': mr.customCustomer ?? '',
        'custom_sales_order': mr.customSalesOrder ?? '',
        'custom_requested_by': mr.customRequestedBy ?? '',
        'custom_requested_by_name': mr.customRequestedByName ?? '',
        'custom_remarks': mr.customRemarks ?? '',
        'custom_checked_by': mr.customCheckedBy ?? '',
        'custom_checked_by_name': mr.customCheckedByName ?? '',
        'custom_approved_by': mr.customApprovedBy ?? '',
        'custom_approved_by_name': mr.customApprovedByName ?? '',
        'items': mr.items.map((e) => e.toJson()).toList(),
      };
    } else if (widget.initialData != null) {
      final cleaned = Map<String, dynamic>.from(widget.initialData!);
      final systemKeys = [
        'name', 'creation', 'modified', 'modified_by', 'owner', 'docstatus',
        'idx', 'amended_from', 'workflow_state', 'workflow_actions', 'status'
      ];
      for (var key in systemKeys) {
        cleaned.remove(key);
      }
      if (cleaned['items'] is List) {
        cleaned['items'] = (cleaned['items'] as List).map((item) {
          final itemMap = Map<String, dynamic>.from(item);
          final itemSystemKeys = ['name', 'parent', 'parentfield', 'parenttype', 'creation', 'modified', 'modified_by', 'owner', 'docstatus', 'idx'];
          for (var key in itemSystemKeys) {
            itemMap.remove(key);
          }
          return itemMap;
        }).toList();
      }
      _doc = cleaned;
      _doc['company'] ??= 'Oasis Trading and Importing HVAC';
      _doc['material_request_type'] ??= 'Purchase';
      _doc['transaction_date'] ??= todayStr;
      _doc['workflow_state'] ??= 'Draft';
      _doc['custom_subject'] ??= '';
      _doc['custom_customer'] ??= '';
      _doc['custom_sales_order'] ??= '';
      _doc['custom_requested_by'] ??= '';
      _doc['custom_requested_by_name'] ??= '';
      _doc['custom_remarks'] ??= '';
      _doc['custom_checked_by'] ??= '';
      _doc['custom_checked_by_name'] ??= '';
      _doc['custom_approved_by'] ??= '';
      _doc['custom_approved_by_name'] ??= '';
      _doc['items'] ??= <Map<String, dynamic>>[];
    } else {
      _doc = {
        'company': 'Oasis Trading and Importing HVAC',
        'material_request_type': 'Purchase',
        'transaction_date': todayStr,
        'workflow_state': 'Draft',
        'custom_subject': '',
        'custom_customer': '',
        'custom_sales_order': '',
        'custom_requested_by': '',
        'custom_requested_by_name': '',
        'custom_remarks': '',
        'custom_checked_by': '',
        'custom_checked_by_name': '',
        'custom_approved_by': '',
        'custom_approved_by_name': '',
        'items': <Map<String, dynamic>>[],
      };
    }

    _setupControllers();
  }

  void _setupControllers() {
    _subjectController = TextEditingController(text: _doc['custom_subject']);
    _remarksController = TextEditingController(text: _doc['custom_remarks']);
    _requestedByController = TextEditingController(text: _doc['custom_requested_by']);
    _checkedByController = TextEditingController(text: _doc['custom_checked_by']);
    _approvedByController = TextEditingController(text: _doc['custom_approved_by']);

    _subjectController.addListener(() => _doc['custom_subject'] = _subjectController.text);
    _remarksController.addListener(() => _doc['custom_remarks'] = _remarksController.text);
    _requestedByController.addListener(() => _doc['custom_requested_by'] = _requestedByController.text);
    _checkedByController.addListener(() => _doc['custom_checked_by'] = _checkedByController.text);
    _approvedByController.addListener(() => _doc['custom_approved_by'] = _approvedByController.text);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _remarksController.dispose();
    _requestedByController.dispose();
    _checkedByController.dispose();
    _approvedByController.dispose();
    super.dispose();
  }

  // --- Search sheets autocomplete lookups ---
  void _openSearchSheet(String title, String doctype, Function(String, Map<String, dynamic>) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchLinkSheet(
        title: title,
        doctype: doctype,
        onSelected: (val, details) {
          Navigator.pop(context);
          setState(() {
            onSelected(val, details);
          });
        },
      ),
    );
  }

  // --- Auto-generate subject helper ---
  void _autoGenerateSubject() {
    final purpose = _doc['material_request_type'];
    final date = _doc['transaction_date'];
    setState(() {
      _subjectController.text = "Request for $purpose - $date";
    });
  }

  // --- Item metadata standard lookup ---
  Future<void> _fetchItemDetails(String itemCode) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.purchase_order.get_item_details',
        params: {'item_code': itemCode},
      );
      
      final data = res['data'] ?? res['message'] ?? {};
      final String uom = data['uom'] ?? 'Nos';
      final String itemName = data['item_name'] ?? itemCode;

      String defaultReqDate = DateFormat('yyyy-MM-dd').format(
        DateTime.parse(_doc['transaction_date']).add(const Duration(days: 3)),
      );

      final newItem = {
        'item_code': itemCode,
        'item_name': itemName,
        'qty': 1.0,
        'uom': uom,
        'conversion_factor': 1.0,
        'stock_uom': uom,
        'stock_qty': 1.0,
        'schedule_date': defaultReqDate,
      };

      setState(() {
        _doc['items'].add(newItem);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Fallback stub if API details endpoint fails
      String defaultReqDate = DateFormat('yyyy-MM-dd').format(
        DateTime.parse(_doc['transaction_date']).add(const Duration(days: 3)),
      );
      final newItem = {
        'item_code': itemCode,
        'item_name': itemCode,
        'qty': 1.0,
        'uom': 'Nos',
        'conversion_factor': 1.0,
        'stock_uom': 'Nos',
        'stock_qty': 1.0,
        'schedule_date': defaultReqDate,
      };
      setState(() {
        _doc['items'].add(newItem);
      });
    }
  }

  // --- Form submission handler ---
  Future<void> _saveOrSubmit() async {
    // Validate Tab-by-tab requirements
    final validationError = _checkValidation();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isNew = widget.materialRequest == null;
      final endpoint = isNew
          ? 'oasis_mobile.api.material_request.create_material_request'
          : 'oasis_mobile.api.material_request.update_material_request';

      final Map<String, dynamic> payload = {
        if (!isNew) 'name': _doc['name'],
        'data': _doc,
      };
      await _apiClient.post(endpoint, payload);

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? 'Material Request created successfully!'
                  : 'Material Request updated successfully!',
            ),
            backgroundColor: AppColors.approvedMD,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String? _checkValidation() {
    if (_doc['material_request_type'] == null || _doc['material_request_type'].toString().isEmpty) {
      return 'Please select a Purpose/Request Type on Tab 1.';
    }
    if (_subjectController.text.trim().isEmpty) {
      return 'Subject cannot be empty on Tab 1.';
    }
    if (_doc['company'] == null || _doc['company'].toString().isEmpty) {
      return 'Company is mandatory on Tab 2.';
    }
    if (_doc['material_request_type'] == 'Customer Provided' &&
        (_doc['custom_customer'] == null || _doc['custom_customer'].toString().isEmpty)) {
      return 'Customer lookup is mandatory for Customer Provided requests.';
    }
    final itemsList = _doc['items'] as List<dynamic>? ?? [];
    if (itemsList.isEmpty) {
      return 'You must add at least one item on Tab 3.';
    }
    for (var i = 0; i < itemsList.length; i++) {
      final item = itemsList[i];
      if ((item['qty'] ?? 0.0) <= 0.0) {
        return 'Item "${item['item_code']}" must have a quantity greater than 0.';
      }
      if (item['schedule_date'] == null || item['schedule_date'].toString().isEmpty) {
        return 'Please set a Required Date for item "${item['item_code']}".';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTypeAndSubjectTab(),
                      _buildDetailsTab(),
                      _buildItemsTab(),
                      _buildRemarksTab(),
                      _buildSummaryTab(),
                    ],
                  ),
                ),
                _buildBottomWizardActions(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        widget.materialRequest == null ? 'New Material Request' : 'Edit Request',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textLight,
        tabs: [
          Tab(text: '1. Purpose', icon: Icon(Icons.playlist_add_check_rounded, size: 20)),
          Tab(text: '2. Details', icon: Icon(Icons.assignment_rounded, size: 20)),
          Tab(text: '3. Items', icon: Icon(Icons.inventory_2_rounded, size: 20)),
          Tab(text: '4. Remarks', icon: Icon(Icons.rate_review_rounded, size: 20)),
          Tab(text: '5. Summary', icon: Icon(Icons.fact_check_rounded, size: 20)),
        ],
      ),
    );
  }

  Widget _buildTypeAndSubjectTab() {
    final List<String> purposes = [
      'Purchase',
      'Material Transfer',
      'Material Issue',
      'Manufacture',
      'Customer Provided',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        borderOnForeground: false,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request Purpose',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _doc['material_request_type'],
                items: purposes.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p, style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _doc['material_request_type'] = val;
                    if (val != 'Customer Provided') {
                      _doc['custom_customer'] = '';
                    }
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subject',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: _autoGenerateSubject,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    label: Text(
                      'Auto-Fill',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Enter brief request subject',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openSearchSheet('Select Company', 'Company', (val, details) {
                  _doc['company'] = val;
                }),
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
                        _doc['company'].toString().isNotEmpty ? _doc['company'] : 'Tap to search Company',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transaction Date',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final parsed = DateTime.parse(_doc['transaction_date']);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: parsed,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _doc['transaction_date'] = DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
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
                        _doc['transaction_date'],
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              if (_doc['material_request_type'] == 'Customer Provided') ...[
                const SizedBox(height: 24),
                Text(
                  'Customer',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _openSearchSheet('Select Customer', 'Customer', (val, details) {
                    _doc['custom_customer'] = val;
                  }),
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
                          _doc['custom_customer'].toString().isNotEmpty
                              ? _doc['custom_customer']
                              : 'Tap to look up Customer',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Sales Order Reference (Optional)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openSearchSheet('Select Sales Order', 'Sales Order', (val, details) {
                  _doc['custom_sales_order'] = val;
                }),
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
                        _doc['custom_sales_order'].toString().isNotEmpty
                            ? _doc['custom_sales_order']
                            : 'Link to a Sales Order',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTab() {
    final List<dynamic> itemsList = _doc['items'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Items (${itemsList.length})',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSearchSheet('Add Item', 'Item', (val, details) {
                  _fetchItemDetails(val);
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(80, 40),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Add',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: itemsList.isEmpty
                ? Center(
                    child: Text(
                      'No items added yet. Click "Add" above.',
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textLight, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: itemsList.length,
                    itemBuilder: (context, index) {
                      final item = itemsList[index];
                      final code = item['item_code'] ?? '';
                      final name = item['item_name'] ?? code;
                      final qty = (item['qty'] ?? 1.0) as double;
                      final uom = item['uom'] ?? 'Nos';
                      final reqDate = item['schedule_date'] ?? '';

                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            itemsList.removeAt(index);
                          });
                        },
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: AppColors.border, width: 1),
                          ),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Code: $code',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Quantity Selector
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primary),
                                          onPressed: () {
                                            if (qty > 1) {
                                              setState(() {
                                                item['qty'] = qty - 1.0;
                                                item['stock_qty'] = (qty - 1.0) * (item['conversion_factor'] ?? 1.0);
                                              });
                                            }
                                          },
                                        ),
                                        Text(
                                          qty.toStringAsFixed(0),
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                          onPressed: () {
                                            setState(() {
                                              item['qty'] = qty + 1.0;
                                              item['stock_qty'] = (qty + 1.0) * (item['conversion_factor'] ?? 1.0);
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          uom,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Required Date Picker
                                    InkWell(
                                      onTap: () async {
                                        final parsed = DateTime.parse(reqDate);
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: parsed,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            item['schedule_date'] = DateFormat('yyyy-MM-dd').format(picked);
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.textLight),
                                            const SizedBox(width: 6),
                                            Text(
                                              DateFormat('dd MMM').format(DateTime.parse(reqDate)),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksTab() {
    final presets = [
      'Restocking warehouse supply',
      'Immediate construction project demand',
      'Broken equipment replacement request',
      'Customer order replenishment',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remarks / Justification',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describe details or business reason...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preset Templates',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) {
                  return ActionChip(
                    label: Text(
                      preset,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textPrimary),
                    ),
                    onPressed: () {
                      setState(() {
                        _remarksController.text = preset;
                      });
                    },
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    final List<dynamic> itemsList = _doc['items'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signatures Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Signatures',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  _buildAuditTile('Requested By (Email)', _requestedByController, 'requester@oasisqatar.com'),
                  const SizedBox(height: 14),
                  _buildAuditTile('Checked By (Email)', _checkedByController, 'verifier@oasisqatar.com'),
                  const SizedBox(height: 14),
                  _buildAuditTile('Approved By (Email)', _approvedByController, 'manager@oasisqatar.com'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Items Summary Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items Breakdown (${itemsList.length})',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  if (itemsList.isEmpty)
                    Text('No items selected.', style: GoogleFonts.plusJakartaSans(color: AppColors.textLight))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itemsList.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = itemsList[index];
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
                                      item['item_name'] ?? item['item_code'],
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Code: ${item['item_code']}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item['qty']} ${item['uom']}',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTile(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBottomWizardActions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentTabIndex > 0)
            SizedBox(
              width: 56,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _tabController.animateTo(_currentTabIndex - 1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: const Icon(Icons.arrow_back_rounded),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentTabIndex < 4) {
                    _tabController.animateTo(_currentTabIndex + 1);
                  } else {
                    _saveOrSubmit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  _currentTabIndex < 4 ? 'Continue' : 'Submit Draft',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Autocomplete Modal Link Search Sheets ---
class _SearchLinkSheet extends StatefulWidget {
  final String title;
  final String doctype;
  final Function(String, Map<String, dynamic>) onSelected;

  const _SearchLinkSheet({
    required this.title,
    required this.doctype,
    required this.onSelected,
  });

  @override
  State<_SearchLinkSheet> createState() => _SearchLinkSheetState();
}

class _SearchLinkSheetState extends State<_SearchLinkSheet> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _queryController = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.purchase_order.search_link',
        params: {
          'txt': query,
          'doctype': widget.doctype,
        },
      );
      
      final dynamic rawList = response['message'] ?? response['results'] ?? response['data'];
      final List<dynamic> results = rawList is List ? rawList : [];

      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.textLight),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search active ${widget.doctype}s...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textLight, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No results found',
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textLight),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final res = _results[index];
                          final value = res['value'] ?? '';
                          final desc = res['description'] ?? '';

                          return ListTile(
                            onTap: () => widget.onSelected(value, res),
                            title: Text(
                              value,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: desc.toString().isNotEmpty
                                ? Text(desc.toString(), style: GoogleFonts.plusJakartaSans(fontSize: 12))
                                : null,
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
