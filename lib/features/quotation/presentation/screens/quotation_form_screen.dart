import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
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
  bool _isLoading = false;

  // General Tab Controllers
  final _quotationToController = TextEditingController();
  final _partyNameController = TextEditingController();
  final _transactionDateController = TextEditingController();
  final _companyController = TextEditingController();
  final _currencyController = TextEditingController(text: 'QAR');
  final _validTillController = TextEditingController();

  // Oasis Custom Tab Controllers
  final _customQuoteTypeController = TextEditingController();
  final _customRefController = TextEditingController();
  final _customSubjectController = TextEditingController();
  final _customAmcPeriodController = TextEditingController();
  final _customCustomerNameArabicController = TextEditingController();
  final _customSubjectArabicController = TextEditingController();

  // Items Tab
  List<QuotationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.quotation != null) {
      _loadQuotationData();
    } else {
      _transactionDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void _loadQuotationData() {
    final q = widget.quotation!;
    _quotationToController.text = q.quotationTo;
    _partyNameController.text = q.partyName;
    _transactionDateController.text = q.transactionDate;
    _companyController.text = q.company;
    _currencyController.text = q.currency;
    _validTillController.text = q.validTill;
    _customQuoteTypeController.text = q.customQuoteType;
    _customRefController.text = q.customRef;
    _customSubjectController.text = q.customSubject;
    _customAmcPeriodController.text = q.customAmcPeriod;
    _customCustomerNameArabicController.text = q.customCustomerNameInArabic;
    _customSubjectArabicController.text = q.customSubjectInArabic;
    _items = List.from(q.items);
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all mandatory fields')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quotationData = {
        'quotation_to': _quotationToController.text,
        'party_name': _partyNameController.text,
        'transaction_date': _transactionDateController.text,
        'company': _companyController.text,
        'currency': _currencyController.text,
        'valid_till': _validTillController.text,
        'custom_quote_type': _customQuoteTypeController.text,
        'custom_ref': _customRefController.text,
        'custom_subject': _customSubjectController.text,
        'custom_amc_period': _customAmcPeriodController.text,
        'custom_customer_name_in_arabic': _customCustomerNameArabicController.text,
        'custom_subject_in_arabic': _customSubjectArabicController.text,
        'items': _items.map((i) => i.toJson()).toList(),
      };

      // Assuming saving as draft for now
      await _apiClient.post('oasis_mobile.api.quotation.save_quotation', {'doc': quotationData});
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation saved successfully')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving quotation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.quotation != null ? 'Edit Quotation' : 'New Quotation',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FBFF),
          labelColor: const Color(0xFF00FBFF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Oasis Custom'),
            Tab(text: 'Items'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FBFF)))
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildCustomTab(),
                  _buildItemsTab(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField('Quotation To', _quotationToController, isMandatory: true),
          _buildTextField('Party Name (Customer/Lead)', _partyNameController, isMandatory: true),
          _buildTextField('Transaction Date', _transactionDateController, isMandatory: true, isDate: true),
          _buildTextField('Company', _companyController, isMandatory: true),
          _buildTextField('Currency', _currencyController, isMandatory: true),
          _buildTextField('Valid Till', _validTillController, isDate: true),
        ],
      ),
    );
  }

  Widget _buildCustomTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField('Quote Type', _customQuoteTypeController),
          _buildTextField('Reference', _customRefController),
          _buildTextField('Subject', _customSubjectController, maxLines: 3),
          _buildTextField('AMC Period', _customAmcPeriodController),
          _buildTextField('Customer Name (Arabic)', _customCustomerNameArabicController, isArabic: true),
          _buildTextField('Subject (Arabic)', _customSubjectArabicController, isArabic: true, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ListTile(
                  title: Text(item.itemCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Qty: ${item.qty} | Rate: ${item.rate}', style: const TextStyle(color: Colors.white54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: const Color(0xFF00FBFF),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isMandatory = false, bool isDate = false, bool isArabic = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (isMandatory) const Text(' *', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            readOnly: isDate,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            onTap: isDate ? () => _selectDate(controller) : null,
            decoration: InputDecoration(
              fillColor: Colors.white.withOpacity(0.05),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 18, color: Colors.white54) : null,
            ),
            validator: (value) => isMandatory && (value == null || value.isEmpty) ? '$label is required' : null,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _showAddItemDialog() {
    final itemCodeController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Item', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('Item Code', itemCodeController, isMandatory: true),
              _buildTextField('Quantity', qtyController, isMandatory: true),
              _buildTextField('Rate', rateController, isMandatory: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (itemCodeController.text.isNotEmpty && qtyController.text.isNotEmpty && rateController.text.isNotEmpty) {
                setState(() {
                  _items.add(QuotationItem(
                    itemCode: itemCodeController.text,
                    description: itemCodeController.text,
                    qty: double.parse(qtyController.text),
                    rate: double.parse(rateController.text),
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveQuotation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FBFF),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
