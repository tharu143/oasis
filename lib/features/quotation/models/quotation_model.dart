import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_colors.dart';

class QuotationItem {
  final String itemCode;
  final String itemName;
  final String description;
  final double qty;
  final String uom;
  final double valuationRate;
  final String customAreaServed;
  final double amount; // Keep for UI if needed

  QuotationItem({
    required this.itemCode,
    this.itemName = '',
    required this.description,
    required this.qty,
    this.uom = 'Nos',
    this.valuationRate = 0.0,
    this.customAreaServed = '',
    this.amount = 0.0,
  });
}

class PaymentScheduleItem {
  final double paymentAmount;
  final double outstanding;
  final double paidAmount;
  final double basePaymentAmount;
  final double baseOutstanding;
  final String dueDate;
  final double invoicePortion;

  PaymentScheduleItem({
    required this.paymentAmount,
    this.outstanding = 0.0,
    this.paidAmount = 0.0,
    this.basePaymentAmount = 0.0,
    this.baseOutstanding = 0.0,
    this.dueDate = '',
    this.invoicePortion = 0.0,
  });
}

class Quotation {
  final String name; // maps to 'name' or 'id'
  final String workflowState;
  final String title;
  final String quotationTo;
  final String partyName;
  final String customerName;
  final String transactionDate;
  final String customQuoteType;
  final String customAmcPeriod;
  final String customNoOfVisits;
  final String orderType;
  final String company;
  final String customApprovedBy;
  final String customApprovedByName;
  final String customSubject;
  final String customSubjectInArabic;
  final String customContractPeriod;
  final String customContractPeriodInArabic;
  final String currency;
  final double totalQty;
  final double baseTotal;
  final double baseGrandTotal;
  final String baseInWords;
  final String customScopeOfWork;
  final String customScopeOfWorkInArabic;
  final String customExclusionsEng;
  final String customExclusionsInArabic;
  final String customPaymentTermsEng;
  final String customPaymentTermsArabic;
  final List<PaymentScheduleItem> paymentSchedule;
  final List<QuotationItem> items;
  
  // Extra UI fields
  final String statusLabel;

  Quotation({
    required this.name,
    required this.workflowState,
    this.title = '',
    this.quotationTo = '',
    this.partyName = '',
    required this.customerName,
    required this.transactionDate,
    this.customQuoteType = '',
    this.customAmcPeriod = '',
    this.customNoOfVisits = '',
    this.orderType = '',
    this.company = '',
    this.customApprovedBy = '',
    this.customApprovedByName = '',
    this.customSubject = '',
    this.customSubjectInArabic = '',
    this.customContractPeriod = '',
    this.customContractPeriodInArabic = '',
    this.currency = 'QAR',
    this.totalQty = 0.0,
    this.baseTotal = 0.0,
    this.baseGrandTotal = 0.0,
    this.baseInWords = '',
    this.customScopeOfWork = '',
    this.customScopeOfWorkInArabic = '',
    this.customExclusionsEng = '',
    this.customExclusionsInArabic = '',
    this.customPaymentTermsEng = '',
    this.customPaymentTermsArabic = '',
    this.paymentSchedule = const [],
    this.items = const [],
    this.statusLabel = '',
  });

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

List<Quotation> get mockQuotations => [
  Quotation(
    name: 'SAL-QTN-2026-00373',
    workflowState: 'Draft',
    title: 'Mr MUBARAK SALMEEN AL MOHANNADI',
    quotationTo: 'Lead',
    partyName: 'CRM-LEAD-2026-00042',
    customerName: 'Mr MUBARAK SALMEEN AL MOHANNADI',
    transactionDate: '2026-05-09',
    customQuoteType: 'Retail',
    customAmcPeriod: '',
    customNoOfVisits: '',
    orderType: 'Sales',
    company: 'Al Waha Engineering',
    customApprovedBy: '',
    customApprovedByName: '',
    customSubject: 'SUPPLY AND INSTALLATION OF WALL MOUNTED SPLIT MITSUBISHI ELECTRIC BRAND',
    customSubjectInArabic: 'توريد وتركيب مكيفات هواء من نوع سبليت مثبتة على الحائط من ماركة ميتسوبيشي إلكتريك',
    currency: 'QAR',
    totalQty: 2.0,
    baseTotal: 4100.0,
    baseGrandTotal: 4100.0,
    baseInWords: 'QAR Four Thousand, One Hundred only.',
    customScopeOfWork: 'TERMS AND CONDITIONS: 1. SCOPE OF WORK: SUPPLY AND INSTALLATION...',
    customScopeOfWorkInArabic: '',
    statusLabel: 'Ordered',
    items: [
      QuotationItem(itemCode: 'MS-GS24VF', itemName: 'MS-GS24VF', description: 'MS-GS24VF', qty: 1.0, uom: 'Nos', valuationRate: 1379.47, amount: 2050.0),
    ],
    paymentSchedule: [
      PaymentScheduleItem(paymentAmount: 4100.0, outstanding: 4100.0, paidAmount: 0.0, basePaymentAmount: 4100.0, baseOutstanding: 4100.0, dueDate: '2026-05-09'),
    ],
  ),
  Quotation(
    name: 'SAL-QTN-2025-00104',
    workflowState: 'Pending by MD',
    title: 'MR SAMI NAJI-70100654',
    quotationTo: 'Customer',
    partyName: 'Mr.Sami Najar-70100654/55848433',
    customerName: 'MR SAMI NAJI',
    transactionDate: '2025-10-07',
    customQuoteType: 'AMC',
    customAmcPeriod: '1 Year',
    customNoOfVisits: '04',
    orderType: 'Maintenance',
    company: 'Al Waha Engineering',
    customSubject: 'QUOTATION FOR QUARTERLY MAINTENANCE CONTRACT FOR AIR CONDITIONNINGS.',
    customSubjectInArabic: 'عرض سعر لعقد صيانة ربع سنوي للمكيفات',
    customContractPeriod: '01-10-2025 TO 30-09-2026',
    customContractPeriodInArabic: 'من  01-10-2025 الى 30-09-2026',
    currency: 'QAR',
    totalQty: 6.0,
    baseTotal: 1400.0,
    baseGrandTotal: 1400.0,
    baseInWords: 'QAR One Thousand, Four Hundred only.',
    customExclusionsEng: 'COMPRESSOR, PC BOARD, FAN MOTORS ARE EXCLUDED',
    customPaymentTermsEng: 'HALF YEARLY PAYMENT: QAR 700.00 – ADVANCE PAYMENT',
    statusLabel: 'Pending',
    items: [
      QuotationItem(itemCode: 'MU-CP18', itemName: 'MU-CP18', description: 'MU-CP18', qty: 2.0, uom: 'Nos', valuationRate: 1246.53),
    ],
    paymentSchedule: [
      PaymentScheduleItem(paymentAmount: 1400.0, outstanding: 1400.0, paidAmount: 0.0, basePaymentAmount: 1400.0, baseOutstanding: 1400.0),
    ],
  ),
  Quotation(
    name: 'SAL-QTN-2024-00999',
    workflowState: 'Approved By MD',
    title: 'QATAR PETROLEUM',
    quotationTo: 'Customer',
    partyName: 'QATAR PETROLEUM',
    customerName: 'QATAR PETROLEUM',
    transactionDate: '2024-01-15',
    customQuoteType: 'Retail',
    orderType: 'Sales',
    company: 'Al Waha Engineering',
    customApprovedBy: 'md@oasis.com',
    customApprovedByName: 'Managing Director',
    customSubject: 'HVAC SYSTEM INSTALLATION FOR MAIN LOBBY',
    customSubjectInArabic: '',
    currency: 'QAR',
    totalQty: 10.0,
    baseTotal: 85000.0,
    baseGrandTotal: 85000.0,
    baseInWords: 'QAR Eighty Five Thousand only.',
    statusLabel: 'Approved',
    items: [
      QuotationItem(itemCode: 'HVAC-100', itemName: 'Central AC Unit', description: '5 Ton AC Unit', qty: 10.0, uom: 'Nos', valuationRate: 8500.0),
    ],
    paymentSchedule: [
      PaymentScheduleItem(paymentAmount: 85000.0, outstanding: 0.0, paidAmount: 85000.0, basePaymentAmount: 85000.0, baseOutstanding: 0.0),
    ],
  ),
];
