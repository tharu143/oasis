import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/journal_entry_model.dart';
import 'journal_entry_detail_screen.dart';

class JournalEntryFormScreen extends StatefulWidget {
  final JournalEntryModel? journalEntry;
  const JournalEntryFormScreen({super.key, this.journalEntry});

  @override
  State<JournalEntryFormScreen> createState() => _JournalEntryFormScreenState();
}

class _JournalEntryFormScreenState extends State<JournalEntryFormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  Map<String, dynamic> _doc = {};

  // Tab Navigation Controllers
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Form Field Controllers
  late TextEditingController _chequeNoController;
  late TextEditingController _refIdController;
  late TextEditingController _remarksController;
  late TextEditingController _preparedByController;
  late TextEditingController _verifiedByController;
  late TextEditingController _approvedByController;

  // Attachment State
  final List<Map<String, dynamic>> _attachments = []; // {name, path, url, isUploading}
  final ImagePicker _imagePicker = ImagePicker();

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

    if (widget.journalEntry != null) {
      final jv = widget.journalEntry!;
      _doc = {
        'name': jv.name,
        'company': jv.company,
        'voucher_type': jv.voucherType,
        'posting_date': jv.postingDate.isNotEmpty ? jv.postingDate : todayStr,
        'cheque_no': jv.chequeNo ?? '',
        'cheque_date': jv.chequeDate ?? todayStr,
        'custom_reference_id': jv.customReferenceId ?? '',
        'user_remark': jv.userRemark ?? '',
        'custom_prepared_by': jv.customPreparedBy ?? '',
        'custom_prepared_by_name': jv.customPreparedByName ?? '',
        'custom_verified_by': jv.customVerifiedBy ?? '',
        'custom_verified_by_name': jv.customVerifiedByName ?? '',
        'custom_approved_by': jv.customApprovedBy ?? '',
        'custom_approved_by_name': jv.customApprovedByName ?? '',
        'total_debit': jv.totalDebit ?? 0.0,
        'total_credit': jv.totalCredit ?? 0.0,
        'difference': jv.difference ?? 0.0,
        'accounts': jv.accounts.map((e) => e.toJson()).toList(),
      };
    } else {
      _doc = {
        'company': 'Oasis Trading and Importing HVAC',
        'voucher_type': 'Journal Entry',
        'posting_date': todayStr,
        'cheque_no': '',
        'cheque_date': todayStr,
        'custom_reference_id': '',
        'user_remark': '',
        'custom_prepared_by': '',
        'custom_prepared_by_name': '',
        'custom_verified_by': '',
        'custom_verified_by_name': '',
        'custom_approved_by': '',
        'custom_approved_by_name': '',
        'total_debit': 0.0,
        'total_credit': 0.0,
        'difference': 0.0,
        'accounts': <Map<String, dynamic>>[],
      };
    }

    _setupControllers();
  }

  void _setupControllers() {
    _chequeNoController = TextEditingController(text: _doc['cheque_no']);
    _refIdController = TextEditingController(text: _doc['custom_reference_id']);
    _remarksController = TextEditingController(text: _doc['user_remark']);
    _preparedByController = TextEditingController(text: _doc['custom_prepared_by']);
    _verifiedByController = TextEditingController(text: _doc['custom_verified_by']);
    _approvedByController = TextEditingController(text: _doc['custom_approved_by']);

    _chequeNoController.addListener(() => _doc['cheque_no'] = _chequeNoController.text);
    _refIdController.addListener(() => _doc['custom_reference_id'] = _refIdController.text);
    _remarksController.addListener(() => _doc['user_remark'] = _remarksController.text);
    _preparedByController.addListener(() => _doc['custom_prepared_by'] = _preparedByController.text);
    _verifiedByController.addListener(() => _doc['custom_verified_by'] = _verifiedByController.text);
    _approvedByController.addListener(() => _doc['custom_approved_by'] = _approvedByController.text);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chequeNoController.dispose();
    _refIdController.dispose();
    _remarksController.dispose();
    _preparedByController.dispose();
    _verifiedByController.dispose();
    _approvedByController.dispose();
    super.dispose();
  }

  // --- Real-time Balancing Double-Entry calculation ---
  void _calculateDoubleEntryTotals() {
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    final List<dynamic> accounts = _doc['accounts'] as List<dynamic>? ?? [];
    for (var acc in accounts) {
      totalDebit += (acc['debit'] as num? ?? 0.0).toDouble();
      totalCredit += (acc['credit'] as num? ?? 0.0).toDouble();
    }

    setState(() {
      _doc['total_debit'] = totalDebit;
      _doc['total_credit'] = totalCredit;
      _doc['difference'] = totalDebit - totalCredit;
    });
  }

  // --- Search autocomplete lookup sheets ---
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

  // --- FAB Add Line bottom dialog sheet ---
  void _openAccountEntrySheet({Map<String, dynamic>? editItem, int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AccountLineItemDialog(
        editItem: editItem,
        onSave: (newItem) {
          setState(() {
            if (editIndex != null) {
              _doc['accounts'][editIndex] = newItem;
            } else {
              _doc['accounts'].add(newItem);
            }
            _calculateDoubleEntryTotals();
          });
        },
      ),
    );
  }

  // --- Submit handler ---
  Future<void> _saveOrSubmit() async {
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
      final isNew = widget.journalEntry == null;
      final endpoint = isNew
          ? 'oasis_mobile.api.journal_entry.create_journal_entry'
          : 'oasis_mobile.api.journal_entry.update_journal_entry';

      final Map<String, dynamic> payload = {
        if (!isNew) 'name': _doc['name'],
        'data': _doc,
      };

      final response = await _apiClient.post(endpoint, payload);

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

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? 'Journal Entry created successfully!'
                  : 'Journal Entry updated successfully!',
            ),
            backgroundColor: AppColors.approvedMD,
          ),
        );

        final createdName = _extractDocName(response);
        if (createdName != null && isNew) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => JournalEntryDetailScreen(
                journalEntry: JournalEntryModel.fromJson({'name': createdName}),
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save voucher: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String? _checkValidation() {
    if (_doc['company'] == null || _doc['company'].toString().isEmpty) {
      return 'Company is mandatory on Tab 1.';
    }
    final List<dynamic> accounts = _doc['accounts'] as List<dynamic>? ?? [];
    if (accounts.length < 2) {
      return 'Double-entry requires at least 2 ledger accounts on Tab 2.';
    }
    final diff = (_doc['difference'] as num? ?? 0.0).toDouble();
    if (diff.abs() > 0.001) {
      return 'Unbalanced entries! Debits and Credits must balance to 0 (Difference is ${diff.toStringAsFixed(2)}).';
    }
    // Attachment is mandatory — at least one uploaded proof required
    final hasUploadedAttachment = _attachments.any((a) => a['isUploading'] != true && a['url'] != null);
    if (!hasUploadedAttachment) {
      // Navigate to Proof tab so the user sees where to add it
      _tabController.animateTo(3);
      return 'Attachment / Invoice Proof is mandatory. Please upload at least one file on Tab 4 (Proof).';
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
                      _buildHeaderInfoTab(),
                      _buildLedgerEntriesTab(),
                      _buildReferenceTab(),
                      _buildProofAndRemarksTab(),
                      _buildAuditTab(),
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
        widget.journalEntry == null ? 'New Journal Entry' : 'Edit Entry',
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
          Tab(text: '1. Header', icon: Icon(Icons.info_outline_rounded, size: 20)),
          Tab(text: '2. Ledger', icon: Icon(Icons.account_balance_rounded, size: 20)),
          Tab(text: '3. Reference', icon: Icon(Icons.assignment_rounded, size: 20)),
          Tab(text: '4. Remarks', icon: Icon(Icons.rate_review_rounded, size: 20)),
          Tab(text: '5. Audit', icon: Icon(Icons.fact_check_rounded, size: 20)),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoTab() {
    final List<String> voucherTypes = [
      'Journal Entry',
      'Bank Entry',
      'Cash Entry',
      'Contra Entry',
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
                'Voucher Type',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _doc['voucher_type'],
                items: voucherTypes.map((v) {
                  return DropdownMenuItem<String>(
                    value: v,
                    child: Text(v, style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _doc['voucher_type'] = val;
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
                'Posting Date',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final parsed = DateTime.parse(_doc['posting_date']);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: parsed,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _doc['posting_date'] = DateFormat('yyyy-MM-dd').format(picked);
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
                        _doc['posting_date'],
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
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

  Widget _buildLedgerEntriesTab() {
    final List<dynamic> accounts = _doc['accounts'] as List<dynamic>? ?? [];
    final diff = (_doc['difference'] as num? ?? 0.0).toDouble();
    final deb = (_doc['total_debit'] as num? ?? 0.0).toDouble();
    final cred = (_doc['total_credit'] as num? ?? 0.0).toDouble();

    final isBalanced = diff.abs() < 0.001;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ledger Lines (${accounts.length})',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
              ),
              GestureDetector(
                onTap: () => _openAccountEntrySheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Add', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No ledger lines added yet.',
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textLight, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _openAccountEntrySheet(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Add Ledger Line', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final item = accounts[index];
                      final acc = item['account'] ?? '';
                      final debitVal = (item['debit'] ?? 0.0) as double;
                      final creditVal = (item['credit'] ?? 0.0) as double;
                      final cc = item['cost_center'] ?? '';

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
                            accounts.removeAt(index);
                            _calculateDoubleEntryTotals();
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
                          child: ListTile(
                            onTap: () => _openAccountEntrySheet(editItem: item, editIndex: index),
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              acc,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: cc.toString().isNotEmpty
                                ? Text('Cost Center: $cc', style: GoogleFonts.plusJakartaSans(fontSize: 12))
                                : null,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (debitVal > 0)
                                  Text(
                                    '+ QAR ${debitVal.toStringAsFixed(2)} (Dr)',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.approvedMD,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (creditVal > 0)
                                  Text(
                                    '- QAR ${creditVal.toStringAsFixed(2)} (Cr)',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.rejectedMD,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Dynamic balancing bar
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Debit', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight)),
                        Text('QAR ${deb.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Credit', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight)),
                        Text('QAR ${cred.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Difference', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isBalanced
                            ? AppColors.approvedMD.withValues(alpha: 0.15)
                            : AppColors.pendingFinance.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBalanced ? Icons.check_circle_rounded : Icons.warning_rounded,
                            size: 14,
                            color: isBalanced ? AppColors.approvedMD : AppColors.pendingFinance,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isBalanced ? 'Balanced' : 'Unbalanced: QAR ${diff.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isBalanced ? AppColors.approvedMD : AppColors.pendingFinance,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceTab() {
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
                'Reference / Cheque Number',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _chequeNoController,
                decoration: InputDecoration(
                  hintText: 'e.g. CHQ-8888',
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
                'Reference Date',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final parsed = DateTime.parse(_doc['cheque_date']);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: parsed,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _doc['cheque_date'] = DateFormat('yyyy-MM-dd').format(picked);
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
                        _doc['cheque_date'],
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Custom Reference ID',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _refIdController,
                decoration: InputDecoration(
                  hintText: 'e.g. REF-JE-001',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Attachment Helpers ---

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Add Attachment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Choose how to attach your proof', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _attachOptionTile(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF6366F1),
                  label: 'Camera',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _attachOptionTile(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF10B981),
                  label: 'Gallery',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _attachOptionTile(
                  icon: Icons.folder_open_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Files',
                  onTap: () { Navigator.pop(context); _pickFile(); },
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOptionTile({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      await _uploadAttachment(picked.path, picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.path == null) return;
      await _uploadAttachment(f.path!, f.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _uploadAttachment(String filePath, String fileName) async {
    // Add as "uploading" placeholder
    final placeholder = {'name': fileName, 'path': filePath, 'url': null, 'isUploading': true};
    setState(() => _attachments.add(placeholder));

    final docname = _doc['name']?.toString();

    try {
      final resp = await _apiClient.uploadFile(
        filePath: filePath,
        fileName: fileName,
        doctype: 'Journal Entry',
        docname: docname,
        isPrivate: false,
      );
      final fileUrl = (resp['message'] is Map ? resp['message']['file_url'] : null)
          ?? resp['file_url']
          ?? fileName;
      setState(() {
        final idx = _attachments.indexOf(placeholder);
        if (idx != -1) _attachments[idx] = {'name': fileName, 'path': filePath, 'url': fileUrl, 'isUploading': false};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$fileName" uploaded ✓'), backgroundColor: AppColors.approvedMD),
        );
      }
    } catch (e) {
      setState(() => _attachments.remove(placeholder));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildProofAndRemarksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Attachment Card ──
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attachments / Invoice Proof',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      if (_attachments.isNotEmpty)
                        Text(
                          '${_attachments.length} file(s)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Upload Zone – tap to open picker
                  GestureDetector(
                    onTap: _showAttachmentPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 42, color: const Color(0xFF6366F1).withOpacity(0.7)),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to attach',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera  •  Gallery  •  Files',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Attached files list
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...List.generate(_attachments.length, (i) {
                      final att = _attachments[i];
                      final isImg = att['name'].toString().toLowerCase().endsWith('.jpg')
                          || att['name'].toString().toLowerCase().endsWith('.jpeg')
                          || att['name'].toString().toLowerCase().endsWith('.png');
                      final isUploading = att['isUploading'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail or icon
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: isImg && att['path'] != null
                                  ? Image.file(File(att['path']), width: 44, height: 44, fit: BoxFit.cover)
                                  : Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF6366F1), size: 24),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    att['name'],
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isUploading ? 'Uploading…' : 'Uploaded ✓',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isUploading ? AppColors.textSecondary : AppColors.approvedMD,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUploading)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
                                onPressed: () => setState(() => _attachments.removeAt(i)),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Remarks Card ──
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
                    'Remarks',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarksController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter internal notes or entry reason...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    final List<dynamic> accounts = _doc['accounts'] as List<dynamic>? ?? [];

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
                  _buildAuditTile('Prepared By (Email)', _preparedByController, 'accountant@oasisqatar.com'),
                  const SizedBox(height: 14),
                  _buildAuditTile('Verified By (Email)', _verifiedByController, 'verifier@oasisqatar.com'),
                  const SizedBox(height: 14),
                  _buildAuditTile('Approved By (Email)', _approvedByController, 'manager@oasisqatar.com'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Ledger summary grid
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
                    'Ledger Rows Summary',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  if (accounts.isEmpty)
                    Text('No lines added yet.', style: GoogleFonts.plusJakartaSans(color: AppColors.textLight))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = accounts[index];
                        final isDr = (item['debit'] ?? 0.0) > 0;
                        final amt = isDr ? item['debit'] : item['credit'];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['account'] ?? '',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'QAR ${amt.toStringAsFixed(2)} (${isDr ? 'Dr' : 'Cr'})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: isDr ? AppColors.approvedMD : AppColors.rejectedMD,
                                  fontSize: 13,
                                ),
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
    final diff = (_doc['difference'] as num? ?? 0.0).toDouble();
    final isUnbalanced = diff.abs() > 0.001;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentTabIndex > 0)
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(_currentTabIndex - 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                minimumSize: const Size(64, 56),
                elevation: 0,
              ),
              child: const Icon(Icons.arrow_back_rounded),
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
                    if (isUnbalanced) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot submit: Vouchers are unbalanced. Difference must be 0.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } else {
                      _saveOrSubmit();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_currentTabIndex == 4 && isUnbalanced) ? AppColors.draft : AppColors.primary,
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

// --- FAB Bottom Sheet dialog to create account entry rows ---
class _AccountLineItemDialog extends StatefulWidget {
  final Map<String, dynamic>? editItem;
  final Function(Map<String, dynamic>) onSave;

  const _AccountLineItemDialog({this.editItem, required this.onSave});

  @override
  State<_AccountLineItemDialog> createState() => _AccountLineItemDialogState();
}

class _AccountLineItemDialogState extends State<_AccountLineItemDialog> {
  final _dialogFormKey = GlobalKey<FormState>();

  String _account = '';
  double _debit = 0.0;
  double _credit = 0.0;
  String _costCenter = '';

  late TextEditingController _debitController;
  late TextEditingController _creditController;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      _account = widget.editItem!['account'] ?? '';
      _debit = (widget.editItem!['debit'] as num? ?? 0.0).toDouble();
      _credit = (widget.editItem!['credit'] as num? ?? 0.0).toDouble();
      _costCenter = widget.editItem!['cost_center'] ?? '';
    }

    _debitController = TextEditingController(text: _debit > 0 ? _debit.toString() : '');
    _creditController = TextEditingController(text: _credit > 0 ? _credit.toString() : '');
  }

  @override
  void dispose() {
    _debitController.dispose();
    _creditController.dispose();
    super.dispose();
  }

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

  void _submitRow() {
    if (_account.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account selection is mandatory'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_debit <= 0.0 && _credit <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Either Debit or Credit amount must be entered'), backgroundColor: AppColors.error),
      );
      return;
    }

    widget.onSave({
      'account': _account,
      'debit': _debit,
      'credit': _credit,
      'debit_in_account_currency': _debit,
      'credit_in_account_currency': _credit,
      'exchange_rate': 1.0,
      'cost_center': _costCenter,
    });
    Navigator.pop(context);
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
      child: Form(
        key: _dialogFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.editItem == null ? 'Add Ledger Line' : 'Edit Ledger Line',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Account',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openSearchSheet('Select Account', 'Account', (val, details) {
                _account = val;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _account.isNotEmpty ? _account : 'Tap to search ledger account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debit (Dr)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _debitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          setState(() {
                            _debit = double.tryParse(val) ?? 0.0;
                            if (_debit > 0) {
                              _credit = 0.0;
                              _creditController.clear();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit (Cr)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _creditController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          setState(() {
                            _credit = double.tryParse(val) ?? 0.0;
                            if (_credit > 0) {
                              _debit = 0.0;
                              _debitController.clear();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Cost Center (Optional)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openSearchSheet('Select Cost Center', 'Cost Center', (val, details) {
                _costCenter = val;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _costCenter.isNotEmpty ? _costCenter : 'Search Cost Center',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Add Ledger Line',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Autocomplete Link Search Modal Sheet ---
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
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
                    onChanged: _onSearchChanged,
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
