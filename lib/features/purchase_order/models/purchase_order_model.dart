import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class PurchaseOrderModel {
  final String? name;
  final String supplier;
  final String? supplierName;
  final String transactionDate;
  final String currency;
  final double conversionRate;
  final String buyingPriceList;
  final String priceListCurrency;
  final double plcConversionRate;
  final String? workflowState;
  final String? customRef;
  final String? customRemarks;
  final String? customPreparedBy;
  final String? customVerifiedBy;
  final String? customApprovedBy;
  final double? grandTotal;
  final double? netTotal;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    this.name,
    required this.supplier,
    this.supplierName,
    required this.transactionDate,
    required this.currency,
    required this.conversionRate,
    required this.buyingPriceList,
    required this.priceListCurrency,
    required this.plcConversionRate,
    this.workflowState,
    this.customRef,
    this.customRemarks,
    this.customPreparedBy,
    this.customVerifiedBy,
    this.customApprovedBy,
    this.grandTotal,
    this.netTotal,
    required this.items,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      name: json['name'],
      supplier: json['supplier'] ?? '',
      supplierName: json['supplier_name'] ?? json['supplier'] ?? '',
      transactionDate: json['transaction_date'] ?? '',
      currency: json['currency'] ?? 'QAR',
      conversionRate: (json['conversion_rate'] ?? 1.0).toDouble(),
      buyingPriceList: json['buying_price_list'] ?? 'Standard Buying',
      priceListCurrency: json['price_list_currency'] ?? 'QAR',
      plcConversionRate: (json['plc_conversion_rate'] ?? 1.0).toDouble(),
      workflowState: json['workflow_state'] ?? 'Draft',
      customRef: json['custom_ref'],
      customRemarks: json['custom_remarks'],
      customPreparedBy: json['custom_prepared_by'] ?? json['custom_prepared_by_name'] ?? '',
      customVerifiedBy: json['custom_verified_by'] ?? json['custom_verified_by_name'] ?? '',
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'] ?? '',
      grandTotal: (json['grand_total'] ?? json['base_grand_total'] ?? 0.0).toDouble(),
      netTotal: (json['net_total'] ?? json['base_total'] ?? 0.0).toDouble(),
      items: (json['items'] as List?)
              ?.map((i) => PurchaseOrderItemModel.fromJson(i))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'supplier': supplier,
      'supplier_name': supplierName,
      'transaction_date': transactionDate,
      'currency': currency,
      'conversion_rate': conversionRate,
      'buying_price_list': buyingPriceList,
      'price_list_currency': priceListCurrency,
      'plc_conversion_rate': plcConversionRate,
      'custom_ref': customRef,
      'custom_remarks': customRemarks,
      if (customPreparedBy != null) 'custom_prepared_by': customPreparedBy,
      if (customVerifiedBy != null) 'custom_verified_by': customVerifiedBy,
      if (customApprovedBy != null) 'custom_approved_by': customApprovedBy,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Color get statusColor {
    final state = (workflowState ?? 'Draft').toLowerCase();
    if (state.contains('approved by md') || state == 'approved') {
      return AppColors.approvedMD; // harmony green
    } else if (state == 'rejected by md') {
      return const Color(0xFF991B1B); // dark red
    } else if (state.contains('rejected by finance') || state.contains('reject')) {
      return AppColors.rejectedMD; // bold red
    } else if (state.contains('verified by finance') || state.contains('verified')) {
      return AppColors.verifiedFinance; // harmony teal/blue
    } else if (state == 'draft') {
      return AppColors.draft; // muted grey
    } else {
      return AppColors.pendingFinance; // vibrant orange (Pending)
    }
  }
}

class PurchaseOrderItemModel {
  final String itemCode;
  final String? itemName;
  final double qty;
  final double rate;
  final double? amount;
  final String uom;
  final double conversionFactor;
  final String stockUom;
  final double stockQty;
  final String scheduleDate;

  PurchaseOrderItemModel({
    required this.itemCode,
    this.itemName,
    required this.qty,
    required this.rate,
    this.amount,
    required this.uom,
    required this.conversionFactor,
    required this.stockUom,
    required this.stockQty,
    required this.scheduleDate,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? json['item_code'] ?? '',
      qty: (json['qty'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? ((json['qty'] ?? 0.0) * (json['rate'] ?? 0.0))).toDouble(),
      uom: json['uom'] ?? 'Nos',
      conversionFactor: (json['conversion_factor'] ?? 1.0).toDouble(),
      stockUom: json['stock_uom'] ?? json['uom'] ?? 'Nos',
      stockQty: (json['stock_qty'] ?? (json['qty'] ?? 0.0)).toDouble(),
      scheduleDate: json['schedule_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'qty': qty,
      'rate': rate,
      'amount': amount,
      'uom': uom,
      'conversion_factor': conversionFactor,
      'stock_uom': stockUom,
      'stock_qty': stockQty,
      'schedule_date': scheduleDate,
    };
  }
}
