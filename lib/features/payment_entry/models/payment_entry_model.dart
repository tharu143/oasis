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

int _intFromJson(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  if (val is String) {
    return int.tryParse(val) ?? 0;
  }
  return 0;
}

class PaymentEntryModel {
  final String? name;
  final String company;
  final String paymentType; // 'Receive', 'Pay', 'Internal Transfer'
  final String postingDate;
  final String modeOfPayment;
  final String? partyType; // 'Customer', 'Supplier', etc.
  final String? party;
  final String paidFrom;
  final String paidTo;
  final double paidAmount;
  final double receivedAmount;
  final double targetExchangeRate;
  final String? referenceNo;
  final String? referenceDate;
  final String? remarks;
  final int? customRemarks;
  final String? workflowState;
  final String? customPreparedBy;
  final String? customPreparedByName;
  final String? customVerifiedBy;
  final String? customVerifiedByName;
  final String? customApprovedBy;
  final String? customApprovedByName;
  final int docstatus;
  final List<PaymentEntryReferenceModel> references;

  PaymentEntryModel({
    this.name,
    required this.company,
    required this.paymentType,
    required this.postingDate,
    required this.modeOfPayment,
    this.partyType,
    this.party,
    required this.paidFrom,
    required this.paidTo,
    required this.paidAmount,
    required this.receivedAmount,
    required this.targetExchangeRate,
    this.referenceNo,
    this.referenceDate,
    this.remarks,
    this.customRemarks,
    this.workflowState,
    this.customPreparedBy,
    this.customPreparedByName,
    this.customVerifiedBy,
    this.customVerifiedByName,
    this.customApprovedBy,
    this.customApprovedByName,
    this.docstatus = 0,
    required this.references,
  });

  factory PaymentEntryModel.fromJson(Map<String, dynamic> json) {
    return PaymentEntryModel(
      name: json['name'],
      company: json['company'] ?? '',
      paymentType: json['payment_type'] ?? 'Receive',
      postingDate: json['posting_date'] ?? '',
      modeOfPayment: json['mode_of_payment'] ?? '',
      partyType: json['party_type'],
      party: json['party'],
      paidFrom: json['paid_from'] ?? '',
      paidTo: json['paid_to'] ?? '',
      paidAmount: _doubleFromJson(json['paid_amount']),
      receivedAmount: _doubleFromJson(json['received_amount']),
      targetExchangeRate: _doubleFromJson(json['target_exchange_rate'] ?? 1.0),
      referenceNo: json['reference_no'],
      referenceDate: json['reference_date'],
      remarks: json['remarks'],
      customRemarks: _intFromJson(json['custom_remarks']),
      workflowState: json['workflow_state'],
      customPreparedBy: json['custom_prepared_by'],
      customPreparedByName: json['custom_prepared_by_name'],
      customVerifiedBy: json['custom_verified_by'],
      customVerifiedByName: json['custom_verified_by_name'],
      customApprovedBy: json['custom_approved_by'],
      customApprovedByName: json['custom_approved_by_name'],
      docstatus: json['docstatus'] is int ? json['docstatus'] : (json['docstatus'] != null ? int.tryParse(json['docstatus'].toString()) ?? 0 : 0),
      references: (json['references'] as List?)
              ?.map((r) => PaymentEntryReferenceModel.fromJson(r))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'company': company,
      'payment_type': paymentType,
      'posting_date': postingDate,
      'mode_of_payment': modeOfPayment,
      if (partyType != null) 'party_type': partyType,
      if (party != null) 'party': party,
      'paid_from': paidFrom,
      'paid_to': paidTo,
      'paid_amount': paidAmount,
      'received_amount': receivedAmount,
      'target_exchange_rate': targetExchangeRate,
      'reference_no': referenceNo,
      'reference_date': referenceDate,
      'remarks': remarks,
      'custom_remarks': customRemarks,
      'docstatus': docstatus,
      'references': references.map((r) => r.toJson()).toList(),
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

class PaymentEntryReferenceModel {
  final String referenceDoctype; // 'Sales Invoice', 'Purchase Invoice', etc.
  final String referenceName;
  final double totalAmount;
  final double outstandingAmount;
  final double allocatedAmount;
  final double exchangeRate;

  PaymentEntryReferenceModel({
    required this.referenceDoctype,
    required this.referenceName,
    required this.totalAmount,
    required this.outstandingAmount,
    required this.allocatedAmount,
    required this.exchangeRate,
  });

  factory PaymentEntryReferenceModel.fromJson(Map<String, dynamic> json) {
    return PaymentEntryReferenceModel(
      referenceDoctype: json['reference_doctype'] ?? '',
      referenceName: json['reference_name'] ?? '',
      totalAmount: _doubleFromJson(json['total_amount']),
      outstandingAmount: _doubleFromJson(json['outstanding_amount']),
      allocatedAmount: _doubleFromJson(json['allocated_amount']),
      exchangeRate: _doubleFromJson(json['exchange_rate'] ?? 1.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reference_doctype': referenceDoctype,
      'reference_name': referenceName,
      'total_amount': totalAmount,
      'outstanding_amount': outstandingAmount,
      'allocated_amount': allocatedAmount,
      'exchange_rate': exchangeRate,
    };
  }
}
