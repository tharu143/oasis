import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

double _doubleFromJson(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) {
    return double.tryParse(val) ?? 0.0;
  }
  return 0.0;
}

class JournalEntryModel {
  final String? name;
  final String company;
  final String voucherType; // 'Journal Entry', 'Bank Entry', 'Cash Entry', 'Contra Entry', etc.
  final String postingDate;
  final String? chequeNo;
  final String? chequeDate;
  final String? customReferenceId;
  final String? userRemark;
  final double? totalDebit;
  final double? totalCredit;
  final double? difference;
  final String? workflowState;
  final String? customPreparedBy;
  final String? customPreparedByName;
  final String? customVerifiedBy;
  final String? customVerifiedByName;
  final String? customApprovedBy;
  final String? customApprovedByName;
  final List<JournalEntryAccountModel> accounts;

  JournalEntryModel({
    this.name,
    required this.company,
    required this.voucherType,
    required this.postingDate,
    this.chequeNo,
    this.chequeDate,
    this.customReferenceId,
    this.userRemark,
    this.totalDebit,
    this.totalCredit,
    this.difference,
    this.workflowState,
    this.customPreparedBy,
    this.customPreparedByName,
    this.customVerifiedBy,
    this.customVerifiedByName,
    this.customApprovedBy,
    this.customApprovedByName,
    required this.accounts,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      name: json['name'],
      company: json['company'] ?? '',
      voucherType: json['voucher_type'] ?? 'Journal Entry',
      postingDate: json['posting_date'] ?? '',
      chequeNo: json['cheque_no'],
      chequeDate: json['cheque_date'],
      customReferenceId: json['custom_reference_id'],
      userRemark: json['user_remark'],
      totalDebit: _doubleFromJson(json['total_debit']),
      totalCredit: _doubleFromJson(json['total_credit']),
      difference: _doubleFromJson(json['difference']),
      workflowState: json['workflow_state'] ?? 'Draft',
      customPreparedBy: json['custom_prepared_by'] ?? json['custom_prepared_by_name'] ?? '',
      customPreparedByName: json['custom_prepared_by_name'],
      customVerifiedBy: json['custom_verified_by'] ?? json['custom_verified_by_name'] ?? '',
      customVerifiedByName: json['custom_verified_by_name'],
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'] ?? '',
      customApprovedByName: json['custom_approved_by_name'],
      accounts: (json['accounts'] as List?)
              ?.map((a) => JournalEntryAccountModel.fromJson(a))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'company': company,
      'voucher_type': voucherType,
      'posting_date': postingDate,
      'cheque_no': chequeNo,
      'cheque_date': chequeDate,
      'custom_reference_id': customReferenceId,
      'user_remark': userRemark,
      if (customPreparedBy != null) 'custom_prepared_by': customPreparedBy,
      if (customPreparedByName != null) 'custom_prepared_by_name': customPreparedByName,
      if (customVerifiedBy != null) 'custom_verified_by': customVerifiedBy,
      if (customVerifiedByName != null) 'custom_verified_by_name': customVerifiedByName,
      if (customApprovedBy != null) 'custom_approved_by': customApprovedBy,
      if (customApprovedByName != null) 'custom_approved_by_name': customApprovedByName,
      'accounts': accounts.map((a) => a.toJson()).toList(),
    };
  }

  Color get statusColor {
    final state = (workflowState ?? 'Draft').toLowerCase();
    if (state.contains('approved') || state == 'submitted') {
      return AppColors.approvedMD; // Harmony Green
    } else if (state.contains('reject')) {
      return AppColors.rejectedMD; // Bold Red
    } else if (state == 'draft') {
      return AppColors.draft; // Muted Grey
    } else if (state.contains('verified')) {
      return AppColors.verifiedFinance; // Harmony Teal/Blue
    } else if (state.contains('cancel')) {
      return AppColors.cancelled; // Bold Charcoal
    } else {
      return AppColors.pendingFinance; // Vibrant Orange (Pending)
    }
  }
}

class JournalEntryAccountModel {
  final String account;
  final double debitInAccountCurrency;
  final double creditInAccountCurrency;
  final double exchangeRate;
  final double? debit;
  final double? credit;
  final String? partyType;
  final String? party;
  final String? costCenter;
  final String? project;

  JournalEntryAccountModel({
    required this.account,
    required this.debitInAccountCurrency,
    required this.creditInAccountCurrency,
    required this.exchangeRate,
    this.debit,
    this.credit,
    this.partyType,
    this.party,
    this.costCenter,
    this.project,
  });

  factory JournalEntryAccountModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryAccountModel(
      account: json['account'] ?? '',
      debitInAccountCurrency: _doubleFromJson(json['debit_in_account_currency']),
      creditInAccountCurrency: _doubleFromJson(json['credit_in_account_currency']),
      exchangeRate: _doubleFromJson(json['exchange_rate'] ?? 1.0),
      debit: _doubleFromJson(json['debit']),
      credit: _doubleFromJson(json['credit']),
      partyType: json['party_type'],
      party: json['party'],
      costCenter: json['cost_center'],
      project: json['project'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account': account,
      'debit_in_account_currency': debitInAccountCurrency,
      'credit_in_account_currency': creditInAccountCurrency,
      'exchange_rate': exchangeRate,
      if (debit != null) 'debit': debit,
      if (credit != null) 'credit': credit,
      if (partyType != null) 'party_type': partyType,
      if (party != null) 'party': party,
      if (costCenter != null) 'cost_center': costCenter,
      if (project != null) 'project': project,
    };
  }
}
