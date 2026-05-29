import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class DeliveryNoteModel {
  final String? name;
  final String customer;
  final String? customerName;
  final String postingDate;
  final String postingTime;
  final String currency;
  final double conversionRate;
  final String sellingPriceList;
  final String priceListCurrency;
  final double plcConversionRate;
  final String? workflowState;
  final String? customQuoteType;
  final String? customRetailQuoteType;
  final String? customPreparedBy;
  final String? customVerifiedBy;
  final String? customApprovedBy;
  final int docstatus;
  final double? grandTotal;
  final double? netTotal;
  final List<DeliveryNoteItemModel> items;
  final String? company;

  DeliveryNoteModel({
    this.name,
    required this.customer,
    this.customerName,
    required this.postingDate,
    required this.postingTime,
    required this.currency,
    required this.conversionRate,
    required this.sellingPriceList,
    required this.priceListCurrency,
    required this.plcConversionRate,
    this.workflowState,
    this.customQuoteType,
    this.customRetailQuoteType,
    this.customPreparedBy,
    this.customVerifiedBy,
    this.customApprovedBy,
    this.docstatus = 0,
    this.grandTotal,
    this.netTotal,
    required this.items,
    this.company,
  });

  factory DeliveryNoteModel.fromJson(Map<String, dynamic> json) {
    return DeliveryNoteModel(
      name: json['name'],
      customer: json['customer'] ?? '',
      customerName: json['customer_name'] ?? json['customer'] ?? '',
      postingDate: json['posting_date'] ?? '',
      postingTime: json['posting_time'] ?? '',
      currency: json['currency'] ?? 'QAR',
      conversionRate: (json['conversion_rate'] ?? 1.0).toDouble(),
      sellingPriceList: json['selling_price_list'] ?? 'Standard Selling',
      priceListCurrency: json['price_list_currency'] ?? 'QAR',
      plcConversionRate: (json['plc_conversion_rate'] ?? 1.0).toDouble(),
      workflowState: json['workflow_state'] ?? 'Draft',
      customQuoteType: json['custom_quote_type'] ?? 'Retail',
      customRetailQuoteType: json['custom_retail_quote_type'] ?? 'Supply Only',
      customPreparedBy: json['custom_prepared_by'] ?? json['custom_prepared_by_name'] ?? '',
      customVerifiedBy: json['custom_verified_by'] ?? json['custom_verified_by_name'] ?? '',
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'] ?? '',
      docstatus: json['docstatus'] is int ? json['docstatus'] : (json['docstatus'] != null ? int.tryParse(json['docstatus'].toString()) ?? 0 : 0),
      grandTotal: (json['grand_total'] ?? json['base_grand_total'] ?? 0.0).toDouble(),
      netTotal: (json['net_total'] ?? json['base_total'] ?? 0.0).toDouble(),
      items: (json['items'] as List?)
              ?.map((i) => DeliveryNoteItemModel.fromJson(i))
              .toList() ?? [],
      company: json['company'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'customer': customer,
      'customer_name': customerName,
      'posting_date': postingDate,
      'posting_time': postingTime,
      'currency': currency,
      'conversion_rate': conversionRate,
      'selling_price_list': sellingPriceList,
      'price_list_currency': priceListCurrency,
      'plc_conversion_rate': plcConversionRate,
      'custom_quote_type': customQuoteType,
      'custom_retail_quote_type': customRetailQuoteType,
      if (customPreparedBy != null) 'custom_prepared_by': customPreparedBy,
      if (customVerifiedBy != null) 'custom_verified_by': customVerifiedBy,
      if (customApprovedBy != null) 'custom_approved_by': customApprovedBy,
      'items': items.map((i) => i.toJson()).toList(),
      if (company != null) 'company': company,
    };
  }

  Color get statusColor {
    final state = (workflowState ?? 'Draft').toLowerCase();
    if (state.contains('approved') || state == 'verified' || state.contains('verified by finance')) {
      return AppColors.approvedMD; // harmony green
    } else if (state.contains('reject')) {
      return AppColors.rejectedMD; // bold red
    } else if (state == 'draft') {
      return AppColors.draft; // muted grey
    } else {
      return AppColors.pendingFinance; // vibrant orange (Pending)
    }
  }
}

class DeliveryNoteItemModel {
  final String itemCode;
  final String? itemName;
  final double qty;
  final double rate;
  final double? amount;
  final String uom;
  final double conversionFactor;
  final String stockUom;
  final double stockQty;

  DeliveryNoteItemModel({
    required this.itemCode,
    this.itemName,
    required this.qty,
    required this.rate,
    this.amount,
    required this.uom,
    required this.conversionFactor,
    required this.stockUom,
    required this.stockQty,
  });

  factory DeliveryNoteItemModel.fromJson(Map<String, dynamic> json) {
    return DeliveryNoteItemModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? json['item_code'] ?? '',
      qty: (json['qty'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? ((json['qty'] ?? 0.0) * (json['rate'] ?? 0.0))).toDouble(),
      uom: json['uom'] ?? 'Nos',
      conversionFactor: (json['conversion_factor'] ?? 1.0).toDouble(),
      stockUom: json['stock_uom'] ?? json['uom'] ?? 'Nos',
      stockQty: (json['stock_qty'] ?? (json['qty'] ?? 0.0)).toDouble(),
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
    };
  }
}
