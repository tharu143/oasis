import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class PaymentSchedule {
  final double paymentAmount;
  final double basePaymentAmount;
  final double paidAmount;
  final double outstanding;
  final double baseOutstanding;

  PaymentSchedule({
    this.paymentAmount = 0.0,
    this.basePaymentAmount = 0.0,
    this.paidAmount = 0.0,
    this.outstanding = 0.0,
    this.baseOutstanding = 0.0,
  });

  factory PaymentSchedule.fromJson(Map<String, dynamic> json) {
    return PaymentSchedule(
      paymentAmount: (json['payment_amount'] ?? 0.0).toDouble(),
      basePaymentAmount: (json['base_payment_amount'] ?? 0.0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0.0).toDouble(),
      outstanding: (json['outstanding'] ?? 0.0).toDouble(),
      baseOutstanding: (json['base_outstanding'] ?? 0.0).toDouble(),
    );
  }
}

class QuotationItem {
  final String itemCode;
  final String itemName;
  final String description;
  final double qty;
  final String uom;
  final double rate;
  final double valuationRate;
  final double amount;
  final String customAreaServed;
  final String customCap;
  final String customModel;
  final String customProjectItem;
  final String customTypeOfUnit;

  QuotationItem({
    required this.itemCode,
    this.itemName = '',
    required this.description,
    required this.qty,
    this.uom = 'Nos',
    this.rate = 0.0,
    this.valuationRate = 0.0,
    this.amount = 0.0,
    this.customAreaServed = '',
    this.customCap = '',
    this.customModel = '',
    this.customProjectItem = '',
    this.customTypeOfUnit = '',
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      itemCode: (json['item_code'] ?? '').toString(),
      itemName: (json['item_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      qty: (json['qty'] ?? 0.0).toDouble(),
      uom: (json['uom'] ?? 'Nos').toString(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      valuationRate: (json['valuation_rate'] ?? json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      customAreaServed: (json['custom_area_served'] ?? '').toString(),
      customCap: (json['custom_cap'] ?? '').toString(),
      customModel: (json['custom_model'] ?? '').toString(),
      customProjectItem: (json['custom_project_item'] ?? '').toString(),
      customTypeOfUnit: (json['custom_type_of_unit'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'qty': qty,
      'rate': rate,
      'amount': amount,
      'custom_area_served': customAreaServed,
      'custom_cap': customCap,
      'custom_model': customModel,
      'custom_project_item': customProjectItem,
      'custom_type_of_unit': customTypeOfUnit,
      'description': description,
    };
  }
}

class Quotation {
  final String name;
  final String workflowState;
  final String title;
  final String quotationTo;
  final String partyName;
  final String customerName;
  final String transactionDate;
  final String validTill;
  final String company;
  final String currency;
  final String customQuoteType;
  final String customRef;
  final String customSubject;
  final String customSubjectInArabic;
  final String customAmcPeriod;
  final String customCustomerNameInArabic;
  
  // Contact & Address Arabic
  final String customContactNameArabic;
  final String customContactMobileNoArabic;
  final String customAddressArabic;
  
  // Branding & Technical
  final String customBrandName;
  final String customBrandNameInArabic;
  final String customCountryOfOrigin;
  final String customCountryOfOriginInArabic;
  final String customMaterialBrand;
  final String customProjectItems;
  
  final double baseGrandTotal;
  final double baseTotal;
  final String baseInWords;
  final String orderType;
  final String customNoOfVisits;
  final double totalQty;
  
  // Technical Specs
  final String customScopeOfWork;
  final String customScopeOfWorkInArabic;
  final String customExclusionsEng;
  final String customExclusionsInArabic;
  
  // Commercial Terms
  final String customPaymentTermsEng;
  final String customPaymentTermsArabic;
  final String customWarrantyEng;
  final String customWarrantyArabic;
  final String customCompletionPeriodEng;
  final String customCompletionPeriodArabic;
  final String customContractPeriod;
  final String customContractPeriodInArabic;
  final String customTermsDetailsArabic;
  final String customMoreTerms;
  
  // Internal Approvals
  final String customPreparedByName;
  final String customVerifiedByName;
  final String customApprovedBy;
  final String customApprovedByName;
  
  final List<QuotationItem> items;
  final List<PaymentSchedule> paymentSchedule;
  final List<String> workflowActions;
  final int docstatus;

  Quotation({
    required this.name,
    required this.workflowState,
    this.title = '',
    this.quotationTo = '',
    this.partyName = '',
    required this.customerName,
    required this.transactionDate,
    this.validTill = '',
    this.company = '',
    this.currency = 'QAR',
    this.customQuoteType = '',
    this.customRef = '',
    this.customSubject = '',
    this.customSubjectInArabic = '',
    this.customAmcPeriod = '',
    this.customCustomerNameInArabic = '',
    this.customContactNameArabic = '',
    this.customContactMobileNoArabic = '',
    this.customAddressArabic = '',
    this.customBrandName = '',
    this.customBrandNameInArabic = '',
    this.customCountryOfOrigin = '',
    this.customCountryOfOriginInArabic = '',
    this.customMaterialBrand = '',
    this.customProjectItems = '',
    this.baseGrandTotal = 0.0,
    this.baseTotal = 0.0,
    this.baseInWords = '',
    this.orderType = '',
    this.customNoOfVisits = '',
    this.totalQty = 0.0,
    this.customScopeOfWork = '',
    this.customScopeOfWorkInArabic = '',
    this.customExclusionsEng = '',
    this.customExclusionsInArabic = '',
    this.customPaymentTermsEng = '',
    this.customPaymentTermsArabic = '',
    this.customWarrantyEng = '',
    this.customWarrantyArabic = '',
    this.customCompletionPeriodEng = '',
    this.customCompletionPeriodArabic = '',
    this.customContractPeriod = '',
    this.customContractPeriodInArabic = '',
    this.customTermsDetailsArabic = '',
    this.customMoreTerms = '',
    this.customPreparedByName = '',
    this.customVerifiedByName = '',
    this.customApprovedBy = '',
    this.customApprovedByName = '',
    this.items = const [],
    this.paymentSchedule = const [],
    this.workflowActions = const [],
    this.docstatus = 0,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['items'] as List? ?? [])
        .map((i) => QuotationItem.fromJson(i))
        .toList();
    
    var scheduleList = (json['payment_schedule'] as List? ?? [])
        .map((s) => PaymentSchedule.fromJson(s))
        .toList();

    return Quotation(
      name: (json['name'] ?? '').toString(),
      workflowState: (json['workflow_state'] ?? 'Draft').toString(),
      title: (json['title'] ?? '').toString(),
      quotationTo: (json['quotation_to'] ?? '').toString(),
      partyName: (json['party_name'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      transactionDate: (json['transaction_date'] ?? '').toString(),
      validTill: (json['valid_till'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      currency: (json['currency'] ?? 'QAR').toString(),
      customQuoteType: (json['custom_quote_type'] ?? '').toString(),
      customRef: (json['custom_ref'] ?? '').toString(),
      customSubject: (json['custom_subject'] ?? '').toString(),
      customSubjectInArabic: (json['custom_subject_in_arabic'] ?? '').toString(),
      customAmcPeriod: (json['custom_amc_period'] ?? '').toString(),
      customCustomerNameInArabic: (json['custom_customer_name_in_arabic'] ?? '').toString(),
      customContactNameArabic: (json['custom_contact_name_arabic'] ?? '').toString(),
      customContactMobileNoArabic: (json['custom_contact_mobile_no_arabic'] ?? '').toString(),
      customAddressArabic: (json['custom_address_arabic'] ?? '').toString(),
      customBrandName: (json['custom_brand_name'] ?? '').toString(),
      customBrandNameInArabic: (json['custom_brand_name_in_arabic'] ?? '').toString(),
      customCountryOfOrigin: (json['custom_country_of_origin'] ?? '').toString(),
      customCountryOfOriginInArabic: (json['custom_country_of_origin_in_arabic'] ?? '').toString(),
      customMaterialBrand: (json['custom_material_brand'] ?? '').toString(),
      customProjectItems: (json['custom_project_items'] ?? '').toString(),
      baseGrandTotal: (json['base_grand_total'] ?? json['grand_total'] ?? 0.0).toDouble(),
      baseTotal: (json['base_total'] ?? 0.0).toDouble(),
      baseInWords: (json['base_in_words'] ?? '').toString(),
      orderType: (json['order_type'] ?? '').toString(),
      customNoOfVisits: (json['custom_no_of_visits'] ?? '').toString(),
      totalQty: (json['total_qty'] ?? 0.0).toDouble(),
      customScopeOfWork: (json['custom_scope_of_work'] ?? '').toString(),
      customScopeOfWorkInArabic: (json['custom_scope_of_work_in_arabic'] ?? '').toString(),
      customExclusionsEng: (json['custom_exclusions_eng'] ?? '').toString(),
      customExclusionsInArabic: (json['custom_exclusions_in_arabic'] ?? '').toString(),
      customPaymentTermsEng: (json['custom_payment_terms_eng'] ?? '').toString(),
      customPaymentTermsArabic: (json['custom_payment_terms_arabic'] ?? '').toString(),
      customWarrantyEng: (json['custom_warranty_eng'] ?? '').toString(),
      customWarrantyArabic: (json['custom_warranty_arabic'] ?? '').toString(),
      customCompletionPeriodEng: (json['custom_completion_period_eng'] ?? '').toString(),
      customCompletionPeriodArabic: (json['custom_completion_period_arabic'] ?? '').toString(),
      customContractPeriod: (json['custom_contract_period'] ?? '').toString(),
      customContractPeriodInArabic: (json['custom_contract_period_in_arabic'] ?? '').toString(),
      customTermsDetailsArabic: (json['custom_terms_details_arabic'] ?? '').toString(),
      customMoreTerms: (json['custom_more_terms'] ?? '').toString(),
      customPreparedByName: (json['custom_prepared_by_name'] ?? '').toString(),
      customVerifiedByName: (json['custom_verified_by_name'] ?? '').toString(),
      customApprovedBy: (json['custom_approved_by'] ?? '').toString(),
      customApprovedByName: (json['custom_approved_by_name'] ?? '').toString(),
      items: itemsList,
      paymentSchedule: scheduleList,
      workflowActions: List<String>.from(json['workflow_actions'] ?? []),
      docstatus: json['docstatus'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quotation_to': quotationTo,
      'party_name': partyName,
      'transaction_date': transactionDate,
      'valid_till': validTill,
      'company': company,
      'currency': currency,
      'custom_quote_type': customQuoteType,
      'custom_ref': customRef,
      'custom_subject': customSubject,
      'custom_subject_in_arabic': customSubjectInArabic,
      'custom_amc_period': customAmcPeriod,
      'custom_customer_name_in_arabic': customCustomerNameInArabic,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Color get statusColor {
    switch (workflowState.toLowerCase()) {
      case 'draft': return AppColors.draft;
      case 'pending by finance team': return AppColors.pendingFinance;
      case 'pending by md': return AppColors.pendingMD;
      case 'verified by finance team': return AppColors.verifiedFinance;
      case 'rejected by md': return AppColors.rejectedMD;
      case 'approved by md': return AppColors.approvedMD;
      default: return AppColors.pendingFinance;
    }
  }
}
