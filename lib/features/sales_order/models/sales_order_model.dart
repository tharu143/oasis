import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class SalesOrderModel {
  final String? name;
  final String customer;
  final String? customerName;
  final String? customerNameInArabic;
  final String transactionDate;
  final String deliveryDate;
  final String orderType;
  final String currency;
  final double conversionRate;
  final String sellingPriceList;
  final String priceListCurrency;
  final double plcConversionRate;
  final String? workflowState;
  final String? customQuoteType;
  final String? customRetailQuoteType;
  final String? customSubject;
  final String? customRef;
  final String? customPreparedBy;
  final String? customVerifiedBy;
  final String? customApprovedBy;
  final String? customTermsDetailsArabic;
  final double? grandTotal;
  final double? netTotal;
  final List<SalesOrderItemModel> items;

  SalesOrderModel({
    this.name,
    required this.customer,
    this.customerName,
    this.customerNameInArabic,
    required this.transactionDate,
    required this.deliveryDate,
    required this.orderType,
    required this.currency,
    required this.conversionRate,
    required this.sellingPriceList,
    required this.priceListCurrency,
    required this.plcConversionRate,
    this.workflowState,
    this.customQuoteType,
    this.customRetailQuoteType,
    this.customSubject,
    this.customRef,
    this.customPreparedBy,
    this.customVerifiedBy,
    this.customApprovedBy,
    this.customTermsDetailsArabic,
    this.grandTotal,
    this.netTotal,
    required this.items,
  });

  factory SalesOrderModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderModel(
      name: json['name'],
      customer: json['customer'] ?? '',
      customerName: json['customer_name'] ?? json['customer'] ?? '',
      customerNameInArabic: json['custom_customer_name_in_arabic'] ?? '',
      transactionDate: json['transaction_date'] ?? '',
      deliveryDate: json['delivery_date'] ?? '',
      orderType: json['order_type'] ?? 'Sales',
      currency: json['currency'] ?? 'QAR',
      conversionRate: (json['conversion_rate'] ?? 1.0).toDouble(),
      sellingPriceList: json['selling_price_list'] ?? 'Standard Selling',
      priceListCurrency: json['price_list_currency'] ?? 'QAR',
      plcConversionRate: (json['plc_conversion_rate'] ?? 1.0).toDouble(),
      workflowState: json['workflow_state'] ?? 'Draft',
      customQuoteType: json['custom_quote_type'] ?? 'Retail',
      customRetailQuoteType: json['custom_retail_quote_type'] ?? 'Supply Only',
      customSubject: json['custom_subject'] ?? '',
      customRef: json['custom_ref'] ?? '',
      customPreparedBy: json['custom_prepared_by'] ?? json['custom_prepared_by_name'] ?? '',
      customVerifiedBy: json['custom_verified_by'] ?? json['custom_verified_by_name'] ?? '',
      customApprovedBy: json['custom_approved_by'] ?? json['custom_approved_by_name'] ?? '',
      customTermsDetailsArabic: json['custom_terms_details_arabic'] ?? '',
      grandTotal: (json['grand_total'] ?? json['base_grand_total'] ?? 0.0).toDouble(),
      netTotal: (json['net_total'] ?? json['base_total'] ?? 0.0).toDouble(),
      items: (json['items'] as List?)
              ?.map((i) => SalesOrderItemModel.fromJson(i))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'customer': customer,
      'customer_name': customerName,
      'custom_customer_name_in_arabic': customerNameInArabic,
      'transaction_date': transactionDate,
      'delivery_date': deliveryDate,
      'order_type': orderType,
      'currency': currency,
      'conversion_rate': conversionRate,
      'selling_price_list': sellingPriceList,
      'price_list_currency': priceListCurrency,
      'plc_conversion_rate': plcConversionRate,
      'custom_quote_type': customQuoteType,
      'custom_retail_quote_type': customRetailQuoteType,
      'custom_subject': customSubject,
      'custom_ref': customRef,
      if (customPreparedBy != null) 'custom_prepared_by': customPreparedBy,
      if (customVerifiedBy != null) 'custom_verified_by': customVerifiedBy,
      if (customApprovedBy != null) 'custom_approved_by': customApprovedBy,
      'custom_terms_details_arabic': customTermsDetailsArabic,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Color get statusColor {
    final state = (workflowState ?? 'Draft').toLowerCase();
    if (state.contains('approved') || state == 'verified') {
      return AppColors.approvedMD; // harmony green
    } else if (state.contains('reject')) {
      return AppColors.rejectedMD; // bold red
    } else if (state == 'draft') {
      return AppColors.draft; // muted grey
    } else {
      return AppColors.pendingFinance; // vibrant orange
    }
  }
}

class SalesOrderItemModel {
  final String itemCode;
  final String? itemName;
  final double qty;
  final double rate;
  final double? amount;
  final String uom;

  SalesOrderItemModel({
    required this.itemCode,
    this.itemName,
    required this.qty,
    required this.rate,
    this.amount,
    required this.uom,
  });

  factory SalesOrderItemModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? json['item_code'] ?? '',
      qty: (json['qty'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? ((json['qty'] ?? 0.0) * (json['rate'] ?? 0.0))).toDouble(),
      uom: json['uom'] ?? 'Nos',
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
    };
  }
}
