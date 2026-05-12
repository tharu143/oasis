import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/quotation/models/quotation_model.dart';

class QuotationDetailScreen extends StatelessWidget {
  final Quotation quotation;

  const QuotationDetailScreen({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildModernHeader(context),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      height: 72,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Light slate background
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Items'),
                            Tab(text: 'Financials'),
                            Tab(text: 'Terms'),
                          ],
                        ),
                      ),
                    ),

                  ),
                ];
              },
              body: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildOverviewTab(),
                  _buildItemsTab(),
                  _buildFinancialsTab(),
                  _buildTermsTab(),
                ],
              ),
            ),
            _buildFloatingBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.03)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: quotation.statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: quotation.statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        quotation.workflowState.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(quotation.baseGrandTotal)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quotation.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.ios_share, color: Colors.white, size: 22), onPressed: () {}),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildClientInfo(),
        const SizedBox(height: 24),
        _buildQuotationSummary(),
        const SizedBox(height: 24),
        _buildApprovalMetadata(),
      ],
    );
  }

  Widget _buildItemsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: quotation.items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        if (item.itemName.isNotEmpty)
                          Text(item.itemName, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.qty.toInt()} ${item.uom}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text('Rate: ${intl.NumberFormat("#,##0.00").format(item.valuationRate)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
              if (item.customAreaServed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                  child: Text('Area Served: ${item.customAreaServed}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                )
              ]
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildFinancialsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildFinancialDetails(),
        if (quotation.paymentSchedule.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Payment Schedule',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...quotation.paymentSchedule.map((schedule) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Payment Amount', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(schedule.paymentAmount)}'),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow('Base Payment', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(schedule.basePaymentAmount)}'),
                _buildInfoRow('Paid Amount', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(schedule.paidAmount)}'),
                _buildInfoRow('Outstanding', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(schedule.outstanding)}'),
                _buildInfoRow('Base Outstanding', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(schedule.baseOutstanding)}'),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildSubjectCard(),
        if (quotation.customScopeOfWork.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Scope of Work', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildTermsCard(quotation.customScopeOfWork, quotation.customScopeOfWorkInArabic),
        ],
        if (quotation.customExclusionsEng.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Exclusions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildTermsCard(quotation.customExclusionsEng, quotation.customExclusionsInArabic),
        ],
        if (quotation.customPaymentTermsEng.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Payment Terms', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildTermsCard(quotation.customPaymentTermsEng, quotation.customPaymentTermsArabic),
        ],
      ],
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quotation.customerName,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Title', quotation.title),
          _buildInfoRow('Quotation To', quotation.quotationTo),
          _buildInfoRow('Party Name', quotation.partyName),
          _buildInfoRow('Company', quotation.company),
        ],
      ),
    );
  }

  Widget _buildQuotationSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Date', quotation.transactionDate),
          _buildInfoRow('Type', quotation.customQuoteType),
          _buildInfoRow('Order Type', quotation.orderType),
          _buildInfoRow('AMC Period', quotation.customAmcPeriod.isEmpty ? 'N/A' : quotation.customAmcPeriod),
          _buildInfoRow('No. of Visits', quotation.customNoOfVisits.isEmpty ? 'N/A' : quotation.customNoOfVisits),
          _buildInfoRow('Total Qty', '${quotation.totalQty.toInt()} Units'),
        ],
      ),
    );
  }

  Widget _buildFinancialDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Base Total', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(quotation.baseTotal)}'),
          _buildInfoRow('Base Grand Total', '${quotation.currency} ${intl.NumberFormat("#,##0.00").format(quotation.baseGrandTotal)}'),
          const Divider(height: 24),
          Text('In Words:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            quotation.baseInWords,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quotation.customSubject,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
          ),
          if (quotation.customSubjectInArabic.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              quotation.customSubjectInArabic,
              textAlign: TextAlign.right,
              style: GoogleFonts.notoSansArabic(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
          if (quotation.customContractPeriod.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Contract Period:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(quotation.customContractPeriod, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                Text(quotation.customContractPeriodInArabic, style: GoogleFonts.notoSansArabic(fontSize: 12)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTermsCard(String eng, String arb) {
    String cleanEng = eng.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').replaceAll(r'\n', '\n').trim();
    String cleanArb = arb.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').replaceAll(r'\n', '\n').trim();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanEng,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          if (cleanArb.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Text(
              cleanArb,
              textAlign: TextAlign.right,
              style: GoogleFonts.notoSansArabic(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovalMetadata() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approval Chain', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _buildInfoRow('Approved By', quotation.customApprovedBy),
          _buildInfoRow('Approver Name', quotation.customApprovedByName),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Fixed width for perfect vertical alignment
            child: Text(
              label, 
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Text(':', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomActions() {
    List<Widget> buttons = [];
    final state = quotation.workflowState.toLowerCase();

    if (state.contains('pending')) {
      buttons.add(
        Expanded(child: _buildActionButton('REJECT', Colors.white, AppColors.rejectedMD, borderColor: AppColors.rejectedMD)),
      );
      buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(child: _buildActionButton('APPROVE', AppColors.approvedMD, Colors.white)),
      );
    } else if (state == 'draft') {
      buttons.add(
        Expanded(child: _buildActionButton('SUBMIT', AppColors.primary, Colors.white)),
      );
    } else {
      // Default or Approved
      buttons.add(
        Expanded(child: _buildActionButton('GENERATE PDF', AppColors.primary, Colors.white)),
      );
    }

    // Always keep the tiny print/options icon
    buttons.add(const SizedBox(width: 12));
    buttons.add(
      Container(
        height: 60, width: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: const Icon(Icons.print_outlined, color: AppColors.primary),
      ),
    );

    return Positioned(
      bottom: 24, left: 24, right: 24,
      child: Row(children: buttons),
    );
  }

  Widget _buildActionButton(String title, Color bgColor, Color textColor, {Color? borderColor}) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: bgColor != Colors.white 
            ? [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
            : [],
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  
  _SliverAppBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
