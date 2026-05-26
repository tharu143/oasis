import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class SalesInvoiceModel {
  final String? name;
  final String customer;
  final String? customerName;
  final String postingDate;
  final String dueDate;
  final String postingTime;
  final String currency;
  final double conversionRate;
  final String sellingPriceList;
  final String priceListCurrency;
  final double plcConversionRate;
  final String? workflowState;
  final String? status;
  final int? docstatus;
  final double outstandingAmount;
  final String? customQuoteType;
  final String? customRetailQuoteType;
  final String? customPreparedBy;
  final String? customVerifiedBy;
  final String? customApprovedBy;
  final double? grandTotal;
  final double? netTotal;
  final List<SalesInvoiceItemModel> items;

  SalesInvoiceModel({
    this.name,
    required this.customer,
    this.customerName,
    required this.postingDate,
    required this.dueDate,
    this.postingTime = '',
    required this.currency,
    required this.conversionRate,
    required this.sellingPriceList,
    required this.priceListCurrency,
    required this.plcConversionRate,
    this.workflowState,
    this.status,
    this.docstatus,
    required this.outstandingAmount,
    this.customQuoteType,
    this.customRetailQuoteType,
    this.customPreparedBy,
    this.customVerifiedBy,
    this.customApprovedBy,
    this.grandTotal,
    this.netTotal,
    required this.items,
  });

  factory SalesInvoiceModel.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceModel(
      name: json['name'],
      customer: json['customer'] ?? '',
      customerName: json['customer_name'] ?? json['customer'] ?? '',
      postingDate: json['posting_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      postingTime: json['posting_time'] ?? '',
      currency: json['currency'] ?? 'QAR',
      conversionRate: (json['conversion_rate'] ?? 1.0).toDouble(),
      sellingPriceList: json['selling_price_list'] ?? 'Standard Selling',
      priceListCurrency: json['price_list_currency'] ?? 'QAR',
      plcConversionRate: (json['plc_conversion_rate'] ?? 1.0).toDouble(),
      workflowState: json['workflow_state'],
      status: json['status'],
      docstatus: json['docstatus'] is int ? json['docstatus'] : (json['docstatus'] != null ? int.tryParse(json['docstatus'].toString()) : null),
      outstandingAmount: (json['outstanding_amount'] ?? 0.0).toDouble(),
      customQuoteType: json['custom_quote_type'],
      customRetailQuoteType: json['custom_retail_quote_type'],
      customPreparedBy: json['custom_prepared_by'] ?? json['custom_prepared_by_name'],
      customVerifiedBy: json['custom_verified_by'] ?? json['custom_verified_by_name'],
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'],
      grandTotal: (json['grand_total'] ?? json['base_grand_total'] ?? 0.0).toDouble(),
      netTotal: (json['net_total'] ?? json['base_total'] ?? 0.0).toDouble(),
      items: (json['items'] as List?)
              ?.map((i) => SalesInvoiceItemModel.fromJson(i))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'customer': customer,
      'posting_date': postingDate,
      'due_date': dueDate,
      'posting_time': postingTime,
      'currency': currency,
      'conversion_rate': conversionRate,
      'selling_price_list': sellingPriceList,
      'price_list_currency': priceListCurrency,
      'plc_conversion_rate': plcConversionRate,
      'custom_quote_type': customQuoteType,
      'custom_retail_quote_type': customRetailQuoteType,
      'custom_prepared_by': customPreparedBy,
      'custom_verified_by': customVerifiedBy,
      'custom_approved_by': customApprovedBy,
      'items': items.map((i) => i.toJson()).toList(),
      if (docstatus != null) 'docstatus': docstatus,
    };
  }

  Color get statusColor {
    final state = (status ?? workflowState ?? 'Draft').toLowerCase();
    if (state == 'draft') {
      return Colors.blueGrey;
    } else if (state == 'paid') {
      return AppColors.approvedMD; // harmony green
    } else if (state == 'overdue') {
      return AppColors.rejectedMD; // bold red
    } else {
      return AppColors.pendingFinance; // orange (unpaid / pending)
    }
  }
}

class SalesInvoiceItemModel {
  final String? name;
  final String itemCode;
  final String? itemName;
  final double qty;
  final double rate;
  final double? amount;
  final String uom;
  final double conversionFactor;
  final String stockUom;
  final double stockQty;

  SalesInvoiceItemModel({
    this.name,
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

  factory SalesInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceItemModel(
      name: json['name'],
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? json['item_code'] ?? '',
      qty: (json['qty'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? ((json['qty'] ?? 0.0) * (json['rate'] ?? 0.0))).toDouble(),
      uom: json['uom'] ?? 'Nos',
      conversionFactor: (json['conversion_factor'] ?? 1.0).toDouble(),
      stockUom: json['stock_uom'] ?? 'Nos',
      stockQty: (json['stock_qty'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'item_code': itemCode,
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
