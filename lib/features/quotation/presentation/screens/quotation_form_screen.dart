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

class _QuotationFormScreenState extends State<QuotationFormScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  
  Map<String, dynamic> _meta = {};
  Map<String, dynamic> _doc = {};
  List<dynamic> _fields = [];
  Map<String, List<dynamic>> _tabs = {};
  List<String> _tabNames = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    try {
      final metaResponse = await _apiClient.get('oasis_mobile.api.quotation.get_quotation_meta');
      final data = metaResponse['message'];
      
      if (data != null && data['status'] == 'success') {
        _fields = data['fields'] as List<dynamic>;
        _meta = data;
        
        // Initialize doc with default values
        for (var field in _fields) {
          if (field['fieldtype'] == 'Table') {
            _doc[field['fieldname']] = [];
          } else if (field['fieldtype'] == 'Check') {
            _doc[field['fieldname']] = 0;
          } else {
            _doc[field['fieldname']] = null;
          }
        }

        // Set defaults
        _doc['transaction_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _doc['naming_series'] = 'SAL-QTN-.YYYY.-';
        _doc['currency'] = 'QAR';
        _doc['company'] = 'Oasis';

        if (widget.quotation != null) {
          _loadExistingData();
        }
        
        _groupFields();
      }
    } catch (e) {
      debugPrint('Error loading meta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load form metadata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadExistingData() {
    // Basic mapping for now, can be expanded to full doc
    final q = widget.quotation!;
    _doc['quotation_to'] = q.quotationTo;
    _doc['party_name'] = q.partyName;
    _doc['transaction_date'] = q.transactionDate;
    _doc['currency'] = q.currency;
    _doc['company'] = q.company;
    _doc['custom_quote_type'] = q.customQuoteType;
    _doc['items'] = q.items.map((e) => e.toJson()).toList();
  }

  void _groupFields() {
    _tabs.clear();
    _tabNames.clear();
    
    String currentTab = "General";
    _tabs[currentTab] = [];
    _tabNames.add(currentTab);

    for (var field in _fields) {
      if (field['fieldtype'] == 'Tab Break') {
        currentTab = field['label'] ?? "More";
        _tabs[currentTab] = [];
        if (!_tabNames.contains(currentTab)) _tabNames.add(currentTab);
      } else {
        _tabs[currentTab]!.add(field);
      }
    }

    // Re-initialize TabController with dynamic length
    _tabController = TabController(length: _tabNames.length, vsync: this);
  }

  bool _isFieldVisible(dynamic field) {
    final dependsOn = field['depends_on'] as String?;
    if (dependsOn == null || dependsOn.isEmpty) return true;

    // Simple parser for ErpNext style depends_on
    // e.g., "eval:doc.custom_quote_type ==\"Retail\""
    try {
      if (dependsOn.startsWith('eval:')) {
        final expression = dependsOn.substring(5);
        if (expression.contains('doc.custom_quote_type')) {
          final value = _doc['custom_quote_type'];
          if (expression.contains('=="Retail"')) return value == 'Retail';
          if (expression.contains('=="AMC"')) return value == 'AMC';
          if (expression.contains('=="Project"')) return value == 'Project';
          if (expression.contains('!="AMC"')) return value != 'AMC';
        }
        if (expression.contains('doc.auto_repeat')) return (_doc['auto_repeat'] ?? '').isNotEmpty;
        if (expression.contains('doc.status==\'Lost\'')) return _doc['status'] == 'Lost';
      }
    } catch (e) {
      return true;
    }
    return true;
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _apiClient.post('oasis_mobile.api.quotation.save_quotation', {'doc': _doc});
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation saved successfully')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          widget.quotation != null ? 'Edit Quotation' : 'Create Quotation',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        bottom: _tabNames.isEmpty ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: _tabNames.map((name) => Tab(text: name.toUpperCase())).toList(),
        ),
      ),
      body: _isLoading || _tabNames.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: _tabNames.map((name) => _buildFieldsTab(_tabs[name] ?? [])).toList(),
              ),
            ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildFieldsTab(List<dynamic> fields) {
    // Group fields by Section Break
    List<List<dynamic>> sections = [];
    List<dynamic> currentSection = [];
    
    for (var field in fields) {
      if (field['fieldtype'] == 'Section Break' && currentSection.isNotEmpty) {
        sections.add(List.from(currentSection));
        currentSection = [field];
      } else {
        currentSection.add(field);
      }
    }
    if (currentSection.isNotEmpty) sections.add(currentSection);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final sectionFields = sections[index];
        final sectionMeta = sectionFields.firstWhere((f) => f['fieldtype'] == 'Section Break', orElse: () => {});
        final sectionLabel = sectionMeta['label'] ?? "General Info";
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              title: Text(
                sectionLabel.toString().toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, 
                  fontWeight: FontWeight.w800, 
                  color: AppColors.primary, 
                  letterSpacing: 1.2
                ),
              ),
              leading: Icon(_getSectionIcon(sectionLabel), size: 18, color: AppColors.primary),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: sectionFields.map((field) {
                if (field['fieldtype'] == 'Section Break') return const SizedBox.shrink();
                if (!_isFieldVisible(field)) return const SizedBox.shrink();
                return _buildDynamicField(field);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  IconData _getSectionIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('customer') || l.contains('party')) return Icons.person_outline_rounded;
    if (l.contains('item') || l.contains('product')) return Icons.inventory_2_outlined;
    if (l.contains('date') || l.contains('time')) return Icons.calendar_today_rounded;
    if (l.contains('tax') || l.contains('amount')) return Icons.receipt_long_rounded;
    if (l.contains('term') || l.contains('condition')) return Icons.gavel_rounded;
    if (l.contains('more') || l.contains('other')) return Icons.more_horiz_rounded;
    return Icons.segment_rounded;
  }

  Widget _buildDynamicField(dynamic field) {
    switch (field['fieldtype']) {
      case 'Table':
        return _buildTableField(field);
      case 'Select':
        return _buildSearchableSelect(field);
      case 'Link':
      case 'Dynamic Link':
        return _buildLinkField(field);
      case 'Date':
        return _buildDateField(field);
      case 'Check':
        return _buildCheckField(field);
      case 'Small Text':
      case 'Text Editor':
        return _buildTextField(field, maxLines: 3);
      case 'Column Break':
        return const Divider(height: 32, color: AppColors.border);
      default:
        return _buildTextField(field);
    }
  }

  Widget _buildSectionHeader(String title) {
    if (title.isEmpty) return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, 
          fontWeight: FontWeight.w800, 
          color: AppColors.textLight, 
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(dynamic field, {int maxLines = 1}) {
    final isArabic = field['fieldname'].toString().contains('arabic');
    
    return _buildFieldContainer(
      label: field['label'] ?? field['fieldname'],
      isMandatory: field['reqd'] == 1,
      child: TextFormField(
        initialValue: _doc[field['fieldname']]?.toString(),
        maxLines: maxLines,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: _getInputDecoration(field),
        onChanged: (v) => _doc[field['fieldname']] = v,
      ),
    );
  }

  Widget _buildSearchableSelect(dynamic field) {
    final options = (field['options'] as String? ?? '').split('\n').where((e) => e.trim().isNotEmpty).toList();
    return _buildFieldContainer(
      label: field['label'] ?? field['fieldname'],
      isMandatory: field['reqd'] == 1,
      child: _buildSelectorTrigger(
        value: _doc[field['fieldname']],
        onTap: () => _showSearchableBottomSheet(
          title: field['label'] ?? field['fieldname'],
          items: options,
          onSelected: (val) => setState(() => _doc[field['fieldname']] = val),
        ),
      ),
    );
  }

  Widget _buildLinkField(dynamic field) {
    return _buildFieldContainer(
      label: field['label'] ?? field['fieldname'],
      isMandatory: field['reqd'] == 1,
      child: _buildSelectorTrigger(
        value: _doc[field['fieldname']],
        onTap: () => _showSearchDialog(field),
      ),
    );
  }

  Widget _buildSelectorTrigger({String? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? 'Select...',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: value != null ? AppColors.textPrimary : AppColors.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(dynamic field) {
    return _buildFieldContainer(
      label: field['label'] ?? field['fieldname'],
      isMandatory: field['reqd'] == 1,
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context, 
            initialDate: DateTime.now(), 
            firstDate: DateTime(2000), 
            lastDate: DateTime(2100),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: AppColors.primary, onSurface: AppColors.textPrimary),
              ),
              child: child!,
            ),
          );
          if (date != null) {
            setState(() => _doc[field['fieldname']] = DateFormat('yyyy-MM-dd').format(date));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _doc[field['fieldname']] ?? 'Pick Date',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: _doc[field['fieldname']] != null ? AppColors.textPrimary : AppColors.textLight,
                ),
              ),
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckField(dynamic field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () => setState(() => _doc[field['fieldname']] = _doc[field['fieldname']] == 1 ? 0 : 1),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _doc[field['fieldname']] == 1 ? AppColors.primary : AppColors.textLight, width: 1.5),
                color: _doc[field['fieldname']] == 1 ? AppColors.primary : Colors.transparent,
              ),
              width: 22,
              height: 22,
              child: _doc[field['fieldname']] == 1 ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Text(field['label'] ?? field['fieldname'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableField(dynamic field) {
    final List<dynamic> tableData = _doc[field['fieldname']] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(field['label'] ?? field['fieldname']),
        ...tableData.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['item_code'] ?? 'Item', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text('Qty: ${item['qty']} | Rate: ${item['rate']}', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() => tableData.removeAt(index)),
                ),
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: () => _showTableItemDialog(field),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.primary, width: 1.5)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add Row', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 24),
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
              Text(label, style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              if (isMandatory) const Text(' *', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  InputDecoration _getInputDecoration(dynamic field) {
    return InputDecoration(
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  void _showSearchDialog(dynamic field) {
    String? doctype = field['target_doctype'] ?? field['options'];
    if (field['fieldtype'] == 'Dynamic Link' && field['fieldname'] == 'party_name') {
      doctype = _doc['quotation_to'];
    }

    if (doctype == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not determine target DocType')));
      return;
    }

    _showSearchableBottomSheet(
      title: field['label'] ?? field['fieldname'],
      doctype: doctype,
      onSelected: (val) => setState(() => _doc[field['fieldname']] = val),
    );
  }

  void _showSearchableBottomSheet({required String title, List<String>? items, String? doctype, required Function(String) onSelected}) {
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
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              Expanded(
                child: SearchableList(
                  items: items,
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

  void _showTableItemDialog(dynamic field) {
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController();
    String? selectedItem;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Item', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFieldContainer(
                  label: 'Item Code',
                  isMandatory: true,
                  child: _buildSelectorTrigger(
                    value: selectedItem,
                    onTap: () => _showSearchableBottomSheet(
                      title: 'Search Item',
                      doctype: 'Item',
                      onSelected: (val) async {
                        setDialogState(() => selectedItem = val);
                        try {
                          final details = await _apiClient.get('oasis_mobile.api.quotation.get_item_details', params: {
                            'item_code': val,
                            'price_list': _doc['selling_price_list'] ?? 'Standard Selling',
                            'currency': _doc['currency'] ?? 'QAR',
                          });
                          if (details['message'] != null) {
                            final d = details['message'];
                            setDialogState(() {
                              rateController.text = (d['price_list_rate'] ?? 0).toString();
                            });
                          }
                        } catch (e) {
                          debugPrint('Error fetching item details: $e');
                        }
                      },
                    ),
                  ),
                ),
                _buildFieldContainer(label: 'Qty', isMandatory: true, child: TextFormField(controller: qtyController, keyboardType: TextInputType.number, decoration: _getInputDecoration({}))),
                _buildFieldContainer(label: 'Rate', isMandatory: true, child: TextFormField(controller: rateController, keyboardType: TextInputType.number, decoration: _getInputDecoration({}))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () {
                if (selectedItem != null) {
                  setState(() {
                    (_doc[field['fieldname']] as List).add({
                      'item_code': selectedItem,
                      'qty': double.tryParse(qtyController.text) ?? 0,
                      'rate': double.tryParse(rateController.text) ?? 0,
                      'amount': (double.tryParse(qtyController.text) ?? 0) * (double.tryParse(rateController.text) ?? 0),
                    });
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Add Item', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    double total = 0;
    if (_doc['items'] != null) {
      for (var item in (_doc['items'] as List)) {
        total += (item['amount'] ?? 0).toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRAND TOTAL', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('QAR ${total.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('${(_doc['items'] as List?)?.length ?? 0} ITEMS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveQuotation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('SAVE QUOTATION', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

class SearchableList extends StatefulWidget {
  final List<String>? items;
  final String? doctype;
  final Function(String) onSelected;
  final ScrollController scrollController;

  const SearchableList({super.key, this.items, this.doctype, required this.onSelected, required this.scrollController});

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
    if (widget.items != null) {
      _filteredItems = widget.items!.map((e) => {'value': e}).toList();
    }
  }

  void _onSearch(String query) async {
    if (widget.items != null) {
      setState(() {
        _filteredItems = widget.items!
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .map((e) => {'value': e})
            .toList();
      });
    } else if (widget.doctype != null && query.length > 1) {
      setState(() => _isSearching = true);
      try {
        final res = await _apiClient.get('oasis_mobile.api.common.search_link', params: {
          'doctype': widget.doctype!,
          'txt': query,
        });
        setState(() {
          _filteredItems = res['results'] ?? [];
          _isSearching = false;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_isSearching) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(item['value']?.toString() ?? 'N/A', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  subtitle: item['description'] != null ? Text(item['description'], style: GoogleFonts.plusJakartaSans(fontSize: 12)) : null,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                  onTap: () {
                    widget.onSelected(item['value']?.toString() ?? '');
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
