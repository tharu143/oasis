import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class MaterialRequestModel {
  final String? name;
  final String company;
  final String materialRequestType; // 'Purchase', 'Material Transfer', 'Material Issue', 'Manufacture', 'Customer Provided'
  final String transactionDate;
  final String? workflowState;
  final String? customSubject;
  final String? customCustomer;
  final String? customSalesOrder;
  final String? customRequestedBy;
  final String? customRequestedByName;
  final String? customRemarks;
  final String? customCheckedBy;
  final String? customCheckedByName;
  final String? customApprovedBy;
  final String? customApprovedByName;
  final List<MaterialRequestItemModel> items;

  MaterialRequestModel({
    this.name,
    required this.company,
    required this.materialRequestType,
    required this.transactionDate,
    this.workflowState,
    this.customSubject,
    this.customCustomer,
    this.customSalesOrder,
    this.customRequestedBy,
    this.customRequestedByName,
    this.customRemarks,
    this.customCheckedBy,
    this.customCheckedByName,
    this.customApprovedBy,
    this.customApprovedByName,
    required this.items,
  });

  factory MaterialRequestModel.fromJson(Map<String, dynamic> json) {
    return MaterialRequestModel(
      name: json['name'],
      company: json['company'] ?? '',
      materialRequestType: json['material_request_type'] ?? 'Purchase',
      transactionDate: json['transaction_date'] ?? '',
      workflowState: json['workflow_state'] ?? 'Draft',
      customSubject: json['custom_subject'],
      customCustomer: json['custom_customer'],
      customSalesOrder: json['custom_sales_order'],
      customRequestedBy: json['custom_requested_by'] ?? json['custom_requested_by_name'] ?? '',
      customRequestedByName: json['custom_requested_by_name'],
      customRemarks: json['custom_remarks'],
      customCheckedBy: json['custom_checked_by'] ?? json['custom_checked_by_name'] ?? '',
      customCheckedByName: json['custom_checked_by_name'],
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'] ?? '',
      customApprovedByName: json['custom_approved_by_name'],
      items: (json['items'] as List?)
              ?.map((i) => MaterialRequestItemModel.fromJson(i))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'company': company,
      'material_request_type': materialRequestType,
      'transaction_date': transactionDate,
      'custom_subject': customSubject,
      'custom_customer': customCustomer,
      'custom_sales_order': customSalesOrder,
      if (customRequestedBy != null) 'custom_requested_by': customRequestedBy,
      if (customRequestedByName != null) 'custom_requested_by_name': customRequestedByName,
      'custom_remarks': customRemarks,
      if (customCheckedBy != null) 'custom_checked_by': customCheckedBy,
      if (customCheckedByName != null) 'custom_checked_by_name': customCheckedByName,
      if (customApprovedBy != null) 'custom_approved_by': customApprovedBy,
      if (customApprovedByName != null) 'custom_approved_by_name': customApprovedByName,
      'items': items.map((i) => i.toJson()).toList(),
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
    } else {
      return AppColors.pendingFinance; // Vibrant Orange (Pending)
    }
  }
}

double _doubleFromJson(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) {
    return double.tryParse(val) ?? 0.0;
  }
  return 0.0;
}

class MaterialRequestItemModel {
  final String itemCode;
  final String? itemName;
  final double qty;
  final String uom;
  final double conversionFactor;
  final String stockUom;
  final double stockQty;
  final String scheduleDate;

  MaterialRequestItemModel({
    required this.itemCode,
    this.itemName,
    required this.qty,
    required this.uom,
    required this.conversionFactor,
    required this.stockUom,
    required this.stockQty,
    required this.scheduleDate,
  });

  factory MaterialRequestItemModel.fromJson(Map<String, dynamic> json) {
    return MaterialRequestItemModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? json['item_code'] ?? '',
      qty: _doubleFromJson(json['qty']),
      uom: json['uom'] ?? 'Nos',
      conversionFactor: _doubleFromJson(json['conversion_factor'] ?? 1.0),
      stockUom: json['stock_uom'] ?? json['uom'] ?? 'Nos',
      stockQty: _doubleFromJson(json['stock_qty']),
      scheduleDate: json['schedule_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'qty': qty,
      'uom': uom,
      'conversion_factor': conversionFactor,
      'stock_uom': stockUom,
      'stock_qty': stockQty,
      'schedule_date': scheduleDate,
    };
  }
}
