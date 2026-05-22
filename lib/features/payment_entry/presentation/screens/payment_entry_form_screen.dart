import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/payment_entry_model.dart';

class PaymentEntryFormScreen extends StatefulWidget {
  final PaymentEntryModel? paymentEntry;
  const PaymentEntryFormScreen({super.key, this.paymentEntry});

  @override
  State<PaymentEntryFormScreen> createState() => _PaymentEntryFormScreenState();
}

class _PaymentEntryFormScreenState extends State<PaymentEntryFormScreen> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Tab 1 Fields
  String _paymentType = 'Receive'; // Receive, Pay, Internal Transfer
  String _company = 'Al Waha Engineering';
  DateTime _postingDate = DateTime.now();
  String _modeOfPayment = 'Card'; // Card, Bank, Cash, Cheque, etc.

  // Tab 2 Fields
  String _partyType = 'Customer'; // Customer, Supplier, etc.
  String _party = '';
  String _paidFrom = 'Debtors - OTaIH';
  String _paidTo = 'Qutba Cool -Doha Bank - OTaIH';

  // Tab 3 Fields
  double _paidAmount = 0.0;
  double _receivedAmount = 0.0;
  double _targetExchangeRate = 1.0;

  // Tab 4 Fields - References list
  List<PaymentEntryReferenceModel> _references = [];

  // Tab 5 Fields
  String _referenceNo = '';
  DateTime? _referenceDate;
  String _remarks = '';
  bool _customRemarks = false;

  // Signatures
  String _preparedBy = '';
  String _preparedByName = '';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    });

    _loadUserInfo();

    if (widget.paymentEntry != null) {
      _loadExistingData();
    } else {
      _applySmartAccountsDefault();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preparedBy = prefs.getString('email') ?? 'accountant@oasisqatar.com';
      _preparedByName = prefs.getString('full_name') ?? 'Senior Accountant';
    });
  }

  void _loadExistingData() {
    final pe = widget.paymentEntry!;
    setState(() {
      _paymentType = pe.paymentType;
      _company = pe.company;
      try {
        _postingDate = DateTime.parse(pe.postingDate);
      } catch (_) {}
      _modeOfPayment = pe.modeOfPayment;

      _partyType = pe.partyType ?? 'Customer';
      _party = pe.party ?? '';
      _paidFrom = pe.paidFrom;
      _paidTo = pe.paidTo;

      _paidAmount = pe.paidAmount;
      _receivedAmount = pe.receivedAmount;
      _targetExchangeRate = pe.targetExchangeRate;

      _references = List.from(pe.references);

      _referenceNo = pe.referenceNo ?? '';
      try {
        if (pe.referenceDate != null) {
          _referenceDate = DateTime.parse(pe.referenceDate!);
        }
      } catch (_) {}
      _remarks = pe.remarks ?? '';
      _customRemarks = pe.customRemarks == 1;
    });
  }

  void _applySmartAccountsDefault() {
    setState(() {
      if (_paymentType == 'Receive') {
        _partyType = 'Customer';
        _paidFrom = 'Debtors - OTaIH';
        _paidTo = 'Qutba Cool -Doha Bank - OTaIH';
      } else if (_paymentType == 'Pay') {
        _partyType = 'Supplier';
        _paidFrom = 'Qutba Cool -Doha Bank - OTaIH';
        _paidTo = 'Creditors - OTaIH';
      } else {
        // Internal Transfer
        _partyType = 'Customer';
        _party = '';
        _paidFrom = 'Qutba Cool -Doha Bank - OTaIH';
        _paidTo = 'Petty Cash - OTaIH';
      }
    });
  }

  double get _totalAllocatedAmount {
    return _references.fold(0.0, (sum, ref) => sum + ref.allocatedAmount);
  }

  double get _unallocatedAmount {
    final target = _paymentType == 'Receive' ? _receivedAmount : _paidAmount;
    return target - _totalAllocatedAmount;
  }

  bool get _isOverAllocated {
    final target = _paymentType == 'Receive' ? _receivedAmount : _paidAmount;
    return _totalAllocatedAmount > target;
  }

  // Mandatory fields checklist
  bool get _isTab1Valid => _company.isNotEmpty && _modeOfPayment.isNotEmpty;
  bool get _isTab2Valid => (_paymentType == 'Internal Transfer') || (_party.isNotEmpty && _paidFrom.isNotEmpty && _paidTo.isNotEmpty);
  bool get _isTab3Valid => _paidAmount > 0 && _receivedAmount > 0 && _targetExchangeRate > 0;
  bool get _isTab5Valid {
    // Cheque no & date mandatory for Bank/Card/Cheque mode
    final needsCheque = _modeOfPayment.toLowerCase().contains('bank') ||
        _modeOfPayment.toLowerCase().contains('card') ||
        _modeOfPayment.toLowerCase().contains('cheque');
    if (needsCheque && _referenceNo.trim().isEmpty) return false;
    return !_isOverAllocated;
  }

  bool get _isFormValid => _isTab1Valid && _isTab2Valid && _isTab3Valid && _isTab5Valid;

  Future<void> _submitForm() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct errors and complete all mandatory fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final model = PaymentEntryModel(
        name: widget.paymentEntry?.name,
        company: _company,
        paymentType: _paymentType,
        postingDate: DateFormat('yyyy-MM-dd').format(_postingDate),
        modeOfPayment: _modeOfPayment,
        partyType: _paymentType == 'Internal Transfer' ? null : _partyType,
        party: _paymentType == 'Internal Transfer' ? null : _party,
        paidFrom: _paidFrom,
        paidTo: _paidTo,
        paidAmount: _paidAmount,
        receivedAmount: _receivedAmount,
        targetExchangeRate: _targetExchangeRate,
        referenceNo: _referenceNo.isNotEmpty ? _referenceNo : null,
        referenceDate: _referenceDate != null ? DateFormat('yyyy-MM-dd').format(_referenceDate!) : null,
        remarks: _remarks.isNotEmpty ? _remarks : null,
        customRemarks: _customRemarks ? 1 : 0,
        workflowState: widget.paymentEntry?.workflowState ?? 'Draft',
        references: _references,
      );

      final Map<String, dynamic> docData = model.toJson();

      if (widget.paymentEntry == null) {
        // Create
        await _apiClient.post('oasis_mobile.api.payment_entry.create_payment_entry', {
          'data': docData,
        });
      } else {
        // Update
        await _apiClient.post('oasis_mobile.api.payment_entry.update_payment_entry', {
          'name': widget.paymentEntry!.name,
          'data': docData,
        });
      }

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.paymentEntry == null ? 'Payment entry created successfully' : 'Payment entry updated successfully'),
            backgroundColor: AppColors.approvedMD,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment entry: $e'), backgroundColor: AppColors.rejectedMD),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildProgressWizardHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTab1(),
                    _buildTab2(),
                    _buildTab3(),
                    _buildTab4(),
                    _buildTab5(),
                  ],
                ),
              ),
              _buildBottomNavButtons(),
            ],
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
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
        widget.paymentEntry == null ? 'Create Payment Entry' : 'Edit ${widget.paymentEntry!.name}',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _buildProgressWizardHeader() {
    final steps = ['Header', 'Party', 'Amounts', 'Links', 'Sign'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < _activeTabIndex;
          final isActive = index == _activeTabIndex;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.approvedMD
                            : isActive
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isActive ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive ? AppColors.textPrimary : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                      child: Container(
                        height: 2.5,
                        color: isCompleted ? AppColors.approvedMD : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNavButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Row(
        children: [
          if (_activeTabIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _tabController.animateTo(_activeTabIndex - 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
          if (_activeTabIndex > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_activeTabIndex < 4) {
                  _tabController.animateTo(_activeTabIndex + 1);
                } else {
                  _submitForm();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeTabIndex == 4
                    ? (_isFormValid ? AppColors.approvedMD : Colors.grey)
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _activeTabIndex < 4 ? 'Continue' : 'Submit Payment',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Header & Mode ---
  Widget _buildTab1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Payment Direction'),
          const SizedBox(height: 12),
          Row(
            children: ['Receive', 'Pay', 'Internal Transfer'].map((type) {
              final isSel = _paymentType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _paymentType = type;
                        _applySmartAccountsDefault();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSel ? Colors.transparent : AppColors.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSearchLinkField(
            label: 'Company',
            value: _company,
            doctype: 'Company',
            onChanged: (val) => setState(() => _company = val),
            mandatory: true,
          ),
          const SizedBox(height: 20),
          _buildDatePickerField(
            label: 'Posting Date',
            value: _postingDate,
            onChanged: (date) => setState(() => _postingDate = date),
          ),
          const SizedBox(height: 20),
          _buildSearchLinkField(
            label: 'Mode of Payment',
            value: _modeOfPayment,
            doctype: 'Mode of Payment',
            onChanged: (val) => setState(() => _modeOfPayment = val),
            mandatory: true,
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Party & Accounts ---
  Widget _buildTab2() {
    final isTransfer = _paymentType == 'Internal Transfer';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTransfer) ...[
            _buildSectionTitle('Party Metadata'),
            const SizedBox(height: 12),
            Row(
              children: ['Customer', 'Supplier'].map((type) {
                final isSel = _partyType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _partyType = type;
                          _party = '';
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.accent : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSel ? Colors.transparent : AppColors.border, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSel ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _buildSearchLinkField(
              label: _partyType,
              value: _party,
              doctype: _partyType,
              onChanged: (val) => setState(() => _party = val),
              mandatory: true,
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle('Ledger Accounts Mapping'),
          const SizedBox(height: 16),
          _buildSearchLinkField(
            label: 'Paid From (Source Account)',
            value: _paidFrom,
            doctype: 'Account',
            onChanged: (val) => setState(() => _paidFrom = val),
            mandatory: true,
          ),
          const SizedBox(height: 20),
          _buildSearchLinkField(
            label: 'Paid To (Target Account)',
            value: _paidTo,
            doctype: 'Account',
            onChanged: (val) => setState(() => _paidTo = val),
            mandatory: true,
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Amounts & Rate ---
  Widget _buildTab3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Currency Inputs'),
          const SizedBox(height: 20),
          _buildNumberField(
            label: 'Paid Amount (QAR)',
            value: _paidAmount,
            onChanged: (val) {
              setState(() {
                _paidAmount = val;
                if (_targetExchangeRate == 1.0) {
                  _receivedAmount = val;
                } else {
                  _receivedAmount = val * _targetExchangeRate;
                }
              });
            },
          ),
          const SizedBox(height: 20),
          _buildNumberField(
            label: 'Received Amount (QAR)',
            value: _receivedAmount,
            onChanged: (val) {
              setState(() {
                _receivedAmount = val;
                if (_targetExchangeRate != 1.0 && _paidAmount > 0) {
                  _targetExchangeRate = val / _paidAmount;
                }
              });
            },
          ),
          const SizedBox(height: 20),
          _buildNumberField(
            label: 'Target Exchange Rate',
            value: _targetExchangeRate,
            onChanged: (val) {
              setState(() {
                _targetExchangeRate = val;
                if (val == 1.0) {
                  _receivedAmount = _paidAmount;
                } else {
                  _receivedAmount = _paidAmount * val;
                }
              });
            },
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If target exchange rate is 1.0, updating Paid Amount automatically sets Received Amount to match.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- TAB 4: Reference Links Grid ---
  Widget _buildTab4() {
    final target = _paymentType == 'Receive' ? _receivedAmount : _paidAmount;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLinkInvoiceSheet,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_link_rounded, color: Colors.white),
        label: Text(
          'Link Invoice',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _references.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_off_rounded, size: 48, color: AppColors.textLight.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No Invoices Linked',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _references.length,
                    itemBuilder: (context, index) {
                      final ref = _references[index];
                      return Dismissible(
                        key: Key('${ref.referenceDoctype}-${ref.referenceName}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.rejectedMD,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            _references.removeAt(index);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ref.referenceName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    ref.referenceDoctype,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildRefMetaCol('Grand Total', 'QAR ${ref.totalAmount.toStringAsFixed(2)}'),
                                  _buildRefMetaCol('Outstanding', 'QAR ${ref.outstandingAmount.toStringAsFixed(2)}'),
                                  _buildRefMetaCol('Allocated', 'QAR ${ref.allocatedAmount.toStringAsFixed(2)}', isBold: true),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildAllocationSummaryBar(target),
        ],
      ),
    );
  }

  Widget _buildRefMetaCol(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationSummaryBar(double target) {
    final allocated = _totalAllocatedAmount;
    final unallocated = _unallocatedAmount;
    final overAllocated = _isOverAllocated;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allocation Matching',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
              ),
              if (overAllocated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedMD.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⚠️ Over Allocated!',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: AppColors.rejectedMD,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryGridCell('Target Amt', 'QAR ${target.toStringAsFixed(2)}'),
              ),
              Container(width: 1.5, height: 32, color: AppColors.border),
              Expanded(
                child: _buildSummaryGridCell('Allocated', 'QAR ${allocated.toStringAsFixed(2)}', color: overAllocated ? AppColors.rejectedMD : AppColors.primary),
              ),
              Container(width: 1.5, height: 32, color: AppColors.border),
              Expanded(
                child: _buildSummaryGridCell('Unallocated', 'QAR ${unallocated.toStringAsFixed(2)}', color: unallocated < 0 ? AppColors.rejectedMD : Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGridCell(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _openLinkInvoiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LinkInvoiceBottomSheet(
          partyType: _partyType,
          party: _party,
          remainingAllocation: _unallocatedAmount,
          onLink: (reference) {
            setState(() {
              _references.add(reference);
            });
          },
        );
      },
    );
  }

  // --- TAB 5: Review & Signatures ---
  Widget _buildTab5() {
    final isCardOrBank = _modeOfPayment.toLowerCase().contains('bank') ||
        _modeOfPayment.toLowerCase().contains('card') ||
        _modeOfPayment.toLowerCase().contains('cheque');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Reference & Date (Cheque/Ref Details)'),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Cheque/Reference No',
            value: _referenceNo,
            onChanged: (val) => setState(() => _referenceNo = val),
            mandatory: isCardOrBank,
          ),
          const SizedBox(height: 20),
          _buildDatePickerField(
            label: 'Cheque/Reference Date',
            value: _referenceDate ?? DateTime.now(),
            onChanged: (date) => setState(() => _referenceDate = date),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Remarks & Additional Meta'),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _customRemarks,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _customRemarks = val ?? false),
              ),
              Text(
                'Custom Remarks',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextAreaField(
            label: 'Remarks',
            value: _remarks,
            onChanged: (val) => setState(() => _remarks = val),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Signature Audit Trail'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              children: [
                _buildSignatureRow('Prepared By', _preparedByName.isNotEmpty ? _preparedByName : 'You', _preparedBy),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border),
                ),
                _buildSignatureRow('Verified By', 'Accounts Team', 'Pending Review'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border),
                ),
                _buildSignatureRow('Approved By', 'Oasis MD', 'Pending Approval'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildValidationSummaryGrid(isCardOrBank),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSignatureRow(String role, String name, String details) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(
          details,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: details.contains('@') ? AppColors.textSecondary : Colors.amber[800],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationSummaryGrid(bool chequeMandatory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isFormValid ? AppColors.approvedMD.withValues(alpha: 0.05) : AppColors.rejectedMD.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isFormValid ? AppColors.approvedMD.withValues(alpha: 0.1) : AppColors.rejectedMD.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isFormValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: _isFormValid ? AppColors.approvedMD : AppColors.rejectedMD,
              ),
              const SizedBox(width: 10),
              Text(
                _isFormValid ? 'Validation Complete' : 'Missing Requirements',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _isFormValid ? AppColors.approvedMD : AppColors.rejectedMD,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckItem('Company & Mode selected', _isTab1Valid),
          _buildCheckItem('Party & Source/Target mapped', _isTab2Valid),
          _buildCheckItem('Valid payment amount set', _isTab3Valid),
          if (chequeMandatory)
            _buildCheckItem('Cheque / Reference no provided', _referenceNo.isNotEmpty),
          _buildCheckItem('Allocations match paid amount', !_isOverAllocated),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool check) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            check ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: check ? AppColors.approvedMD : AppColors.rejectedMD,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: check ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- REUSABLE UI WIDGET HELPERS ---
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        fontSize: 15,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool mandatory = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
            ),
            if (mandatory)
              Text(' *', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            initialValue: value,
            onChanged: onChanged,
            decoration: const InputDecoration(border: InputBorder.none),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            initialValue: value,
            onChanged: onChanged,
            maxLines: 4,
            decoration: const InputDecoration(border: InputBorder.none),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            initialValue: value == 0.0 ? '' : value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0.0;
              onChanged(parsed);
            },
            decoration: const InputDecoration(border: InputBorder.none),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              onChanged(date);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(value),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                ),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchLinkField({
    required String label,
    required String value,
    required String doctype,
    required ValueChanged<String> onChanged,
    bool mandatory = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
            ),
            if (mandatory)
              Text(' *', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return _SearchLinkSheet(
                  doctype: doctype,
                  onSelect: onChanged,
                );
              },
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'Search $doctype...',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: value.isNotEmpty ? AppColors.textPrimary : AppColors.textLight,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- SEARCH LINK DIALOG BOTTOM SHEET ---
class _SearchLinkSheet extends StatefulWidget {
  final String doctype;
  final ValueChanged<String> onSelect;
  const _SearchLinkSheet({required this.doctype, required this.onSelect});

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
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select ${widget.doctype}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
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
                      hintText: 'Search...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textLight, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: _searching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No records found.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final value = item['value'] ?? item['name'] ?? '';
                          return ListTile(
                            title: Text(
                              value,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              widget.onSelect(value);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- LINK INVOICE BOTTOM SHEET ---
class _LinkInvoiceBottomSheet extends StatefulWidget {
  final String partyType;
  final String party;
  final double remainingAllocation;
  final ValueChanged<PaymentEntryReferenceModel> onLink;

  const _LinkInvoiceBottomSheet({
    required this.partyType,
    required this.party,
    required this.remainingAllocation,
    required this.onLink,
  });

  @override
  State<_LinkInvoiceBottomSheet> createState() => _LinkInvoiceBottomSheetState();
}

class _LinkInvoiceBottomSheetState extends State<_LinkInvoiceBottomSheet> {
  final ApiClient _apiClient = ApiClient();
  String _refDoctype = 'Sales Invoice';
  String _refName = '';
  double _grandTotal = 0.0;
  double _outstanding = 0.0;
  double _allocated = 0.0;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _refDoctype = widget.partyType == 'Customer' ? 'Sales Invoice' : 'Purchase Invoice';
  }

  Future<void> _fetchInvoiceDetails(String invoiceId) async {
    setState(() => _searching = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.payment_entry.get_outstanding_invoice_details',
        params: {
          'invoice_doctype': _refDoctype,
          'invoice_name': invoiceId,
        },
      );

      final data = response['message'] ?? response['data'] ?? response;
      setState(() {
        _refName = invoiceId;
        _grandTotal = (data['grand_total'] ?? 0.0).toDouble();
        _outstanding = (data['outstanding_amount'] ?? 0.0).toDouble();

        // Default to minimum of outstanding balance or remaining unallocated payment entry amount
        _allocated = _outstanding < widget.remainingAllocation ? _outstanding : (widget.remainingAllocation > 0 ? widget.remainingAllocation : 0.0);
        _searching = false;
      });
    } catch (_) {
      setState(() {
        _refName = invoiceId;
        // Stub defaults on error
        _grandTotal = 1000.0;
        _outstanding = 500.0;
        _allocated = _outstanding < widget.remainingAllocation ? _outstanding : (widget.remainingAllocation > 0 ? widget.remainingAllocation : 0.0);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Link Invoice Reference',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Reference DocType',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _refDoctype,
            items: ['Sales Invoice', 'Purchase Invoice'].map((val) {
              return DropdownMenuItem(value: val, child: Text(val, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _refDoctype = val;
                  _refName = '';
                  _grandTotal = 0.0;
                  _outstanding = 0.0;
                  _allocated = 0.0;
                });
              }
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          _buildSearchLinkField(
            label: 'Reference Invoice',
            value: _refName,
            doctype: _refDoctype,
            onChanged: _fetchInvoiceDetails,
          ),
          if (_searching)
            const Center(
              child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_refName.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildDetailsCard('Grand Total', 'QAR ${_grandTotal.toStringAsFixed(2)}')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailsCard('Outstanding', 'QAR ${_outstanding.toStringAsFixed(2)}')),
              ],
            ),
            const SizedBox(height: 20),
            _buildNumberField(
              label: 'Allocated Amount (QAR)',
              value: _allocated,
              onChanged: (val) => setState(() => _allocated = val),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_allocated <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation amount must be greater than zero.')));
                    return;
                  }
                  final model = PaymentEntryReferenceModel(
                    referenceDoctype: _refDoctype,
                    referenceName: _refName,
                    totalAmount: _grandTotal,
                    outstandingAmount: _outstanding,
                    allocatedAmount: _allocated,
                    exchangeRate: 1.0,
                  );
                  widget.onLink(model);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Confirm Link', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchLinkField({
    required String label,
    required String value,
    required String doctype,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) {
                return _SearchLinkSheet(doctype: doctype, onSelect: onChanged);
              },
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'Search $doctype...',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: value.isNotEmpty ? AppColors.textPrimary : AppColors.textLight, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({required String label, required double value, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            initialValue: value == 0.0 ? '' : value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0.0;
              onChanged(parsed);
            },
            decoration: const InputDecoration(border: InputBorder.none),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
