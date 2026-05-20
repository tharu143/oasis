import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/quotation/models/quotation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuotationDetailScreen extends StatefulWidget {
  final Quotation quotation;

  const QuotationDetailScreen({super.key, required this.quotation});

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late Quotation _quotation;
  List<dynamic> _activityFeed = [];
  List<String> _userRoles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quotation = widget.quotation;
    _fetchDetails();
    _fetchHistory();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRoles = prefs.getStringList('roles') ?? [];
    });
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.quotation.get_quotation',
        params: {'name': _quotation.name},
      );
      if (response['message'] != null && response['message']['status'] == 'success') {
        debugPrint('🔍 [FULL DETAIL RESPONSE] ${response['message']['data']}');
        if (response['message']['debug'] != null) {
          debugPrint('🔍 [BACKEND DEBUG] ${response['message']['debug']}');
        }
        setState(() {
          final data = Map<String, dynamic>.from(response['message']['data']);
          if (response['message']['workflow_actions'] != null) {
            data['workflow_actions'] = response['message']['workflow_actions'];
          }
          _quotation = Quotation.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await _apiClient.get(
        'oasis_mobile.api.quotation.get_quotation_history',
        params: {'name': _quotation.name},
      );
      if (response['message'] != null) {
        final data = response['message'];
        List<dynamic> combined = [];

        if (data['workflow_history'] != null) {
          for (var item in data['workflow_history']) {
            combined.add({...item, 'type': 'workflow'});
          }
        }
        if (data['comments'] != null) {
          for (var item in data['comments']) {
            combined.add({...item, 'type': 'comment'});
          }
        }
        if (data['communications'] != null) {
          for (var item in data['communications']) {
            combined.add({...item, 'type': 'communication'});
          }
        }
        // Add Audit Log
        if (data['audit_log'] != null) {
          for (var item in data['audit_log']) {
            combined.add({...item, 'type': 'audit'});
          }
        }

        combined.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['creation'] ?? '') ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b['creation'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        setState(() {
          _activityFeed = combined;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
  }

  Future<void> _applyAction(String action) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to proceed with "$action"?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.post(
        'oasis_mobile.api.quotation.apply_workflow_action',
        {
          'name': _quotation.name,
          'action': action,
        },
      );
      if (response['message'] != null && response['message']['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action "$action" applied successfully')),
        );
        _fetchDetails();
        _fetchHistory();
      } else {
        throw response['message']?['message'] ?? 'Failed to apply action';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
                          color: const Color(0xFFF1F5F9),
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
                          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12),
                          tabs: const [
                            Tab(text: 'General'),
                            Tab(text: 'Technical'),
                            Tab(text: 'Commercial'),
                            Tab(text: 'Activity'),
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
                  _buildGeneralTab(),
                  _buildTechnicalTab(),
                  _buildCommercialTab(),
                  _buildActivityTab(),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.white24,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
              ),
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
                      color: _getStatusBgColor(_quotation.workflowState),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      _quotation.workflowState.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.bold, color: _getStatusTextColor(_quotation.workflowState),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_quotation.currency} ${intl.NumberFormat("#,##0.00").format(_quotation.baseGrandTotal)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _quotation.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 22), onPressed: _fetchDetails),
        const SizedBox(width: 8),
      ],
    );
  }

  Color _getStatusBgColor(String state) {
    if (state.toLowerCase().contains('approved')) return const Color(0xFFD1FAE5);
    if (state.toLowerCase().contains('pending')) return const Color(0xFFFEF3C7);
    return Colors.white.withOpacity(0.2);
  }

  Color _getStatusTextColor(String state) {
    if (state.toLowerCase().contains('approved')) return const Color(0xFF065F46);
    if (state.toLowerCase().contains('pending')) return const Color(0xFF92400E);
    return Colors.white;
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildClientSection(),
        const SizedBox(height: 24),
        _buildSectionTitle('Quotation Summary'),
        _buildSummaryCard(),
        const SizedBox(height: 24),
        _buildSectionTitle('Items'),
        const SizedBox(height: 12),
        ..._quotation.items.map((item) => _buildExpandableItemCard(item)).toList(),
        if (_quotation.customProjectItem.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Project Items'),
          const SizedBox(height: 12),
          ..._quotation.customProjectItem.map((item) => _buildProjectItemCard(item)).toList(),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Signatories'),
        _buildSignatoriesCard(),
      ],
    );
  }

  Widget _buildTechnicalTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildBilingualCard('Subject', _quotation.customSubject, _quotation.customSubjectInArabic),
        const SizedBox(height: 24),
        _buildBilingualCard('Scope of Work', _quotation.customScopeOfWork, _quotation.customScopeOfWorkInArabic),
        const SizedBox(height: 24),
        _buildTechnicalGrid(),
        const SizedBox(height: 24),
        _buildBilingualCard('Exclusions', _quotation.customExclusionsEng, _quotation.customExclusionsInArabic),
      ],
    );
  }

  Widget _buildCommercialTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildBilingualCard('Payment Terms', _quotation.customPaymentTermsEng, _quotation.customPaymentTermsArabic),
        if (_quotation.paymentSchedule.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildPaymentScheduleSection(),
        ],
        const SizedBox(height: 24),
        _buildBilingualCard('Warranty', _quotation.customWarrantyEng, _quotation.customWarrantyArabic),
        const SizedBox(height: 24),
        _buildBilingualCard('Completion Period', _quotation.customCompletionPeriodEng, _quotation.customCompletionPeriodArabic),
        const SizedBox(height: 24),
        _buildBilingualCard('Contract Period', _quotation.customContractPeriod, _quotation.customContractPeriodInArabic),
      ],
    );
  }

  Widget _buildActivityTab() {
    if (_activityFeed.isEmpty) {
      return const Center(child: Text('No activity found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      itemCount: _activityFeed.length,
      itemBuilder: (context, index) {
        final item = _activityFeed[index];
        final type = item['type'];
        final isLast = index == _activityFeed.length - 1;

        IconData icon;
        Color iconColor;
        String title;
        String? subtitle;
        String? content;

        switch (type) {
          case 'audit':
            icon = Icons.edit_note_rounded;
            iconColor = Colors.indigo;
            title = 'Field Updated';
            final user = item['user'] ?? item['modified_by'] ?? 'System';
            subtitle = '$user updated ${item['field_name']}';
            content = 'Changed from "${item['old_value']}" to "${item['new_value']}"';
            break;
          case 'workflow':
            icon = Icons.alt_route_rounded;
            iconColor = AppColors.primary;
            title = item['workflow_state'] ?? 'State Change';
            final user = item['user'] ?? item['modified_by'] ?? item['owner'] ?? 'System';
            subtitle = 'by $user';
            content = item['comment'];
            break;
          case 'comment':
            icon = Icons.comment_outlined;
            iconColor = Colors.orange;
            title = 'Comment';
            final commenter = item['user'] ?? item['comment_by'] ?? item['owner'] ?? 'System';
            subtitle = 'from $commenter';
            content = item['content'];
            break;
          case 'communication':
            icon = Icons.email_outlined;
            iconColor = Colors.blueGrey;
            title = item['subject'] ?? 'Email Sent';
            final sender = item['sender'] ?? item['user'] ?? 'System';
            subtitle = 'from $sender to ${item['recipients']}';
            content = item['content'];
            break;
          default:
            icon = Icons.info_outline;
            iconColor = Colors.grey;
            title = 'Update';
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 1, color: AppColors.border.withOpacity(0.5))),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ),
                          Text(
                            _formatDate(item['creation']),
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      if (subtitle != null)
                        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                      if (content != null && content.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            _stripHtml(content),
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
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
                    Text(_quotation.customerName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    if (_quotation.customCustomerNameInArabic.isNotEmpty)
                      Text(_quotation.customCustomerNameInArabic, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow('Contact Person', _quotation.partyName),
          _buildInfoRow('Address', _quotation.customAddressArabic),
          _buildInfoRow('Mobile', _quotation.customContactMobileNoArabic),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Date', _quotation.transactionDate),
          _buildInfoRow('Valid Till', _quotation.validTill),
          _buildInfoRow('Order Type', _quotation.orderType),
          _buildInfoRow('Quote Type', _quotation.customQuoteType),
          _buildInfoRow('Total Qty', '${_quotation.totalQty.toInt()} Units'),
        ],
      ),
    );
  }

  Widget _buildExpandableItemCard(QuotationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(item.itemCode, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(item.itemName, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Text(
          '${item.qty.toInt()} ${item.uom}',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _buildInfoRow('Area Served', item.customAreaServed),
          _buildInfoRow('Capacity', item.customCap),
          _buildInfoRow('Model', item.customModel),
          _buildInfoRow('Project Item', item.customProjectItem),
          _buildInfoRow('Description', _stripHtml(item.description)),
        ],
      ),
    );
  }

  Widget _buildSignatoriesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Prepared By', _quotation.customPreparedByName),
          _buildInfoRow('Verified By', _quotation.customVerifiedByName),
          _buildInfoRow('Approved By', _quotation.customApprovedByName),
        ],
      ),
    );
  }

  Widget _buildBilingualCard(String title, String eng, String arb) {
    if (eng.isEmpty && arb.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          if (eng.isNotEmpty)
            Text(_stripHtml(eng), style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
          if (eng.isNotEmpty && arb.isNotEmpty) const Divider(height: 24),
          if (arb.isNotEmpty)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                _stripHtml(arb),
                style: GoogleFonts.amiri(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectItemCard(QuotationProjectItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.item,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Text(
                '${item.qty.toStringAsFixed(0)} ${item.uom}',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          if (item.itemName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.itemName,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (item.description.isNotEmpty) ...[
            const Divider(height: 20),
            Text(
              _stripHtml(item.description),
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentScheduleSection() {
    if (_quotation.paymentSchedule.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Schedule',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_quotation.paymentTermsTemplate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _quotation.paymentTermsTemplate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 32),
          ...List.generate(_quotation.paymentSchedule.length, (index) {
            final milestone = _quotation.paymentSchedule[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.paymentTerm,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (milestone.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            milestone.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${milestone.invoicePortion.toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QAR ${milestone.paymentAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTechnicalGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Brand Name', _quotation.customBrandName),
          _buildInfoRow('Brand (Arabic)', _quotation.customBrandNameInArabic),
          _buildInfoRow('Country of Origin', _quotation.customCountryOfOrigin),
          _buildInfoRow('Origin (Arabic)', _quotation.customCountryOfOriginInArabic),
          _buildInfoRow(
            'Material Brand',
            _quotation.customMaterialBrand
                .map((item) {
                  final parts = [
                    if (item.description.isNotEmpty) item.description,
                    if (item.brand.isNotEmpty) item.brand,
                    if (item.make.isNotEmpty) item.make,
                  ];
                  return parts.join(' - ');
                })
                .where((s) => s.isNotEmpty)
                .join(', '),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary))),
          const Text(':', style: TextStyle(color: AppColors.border)),
          const SizedBox(width: 16),
          Expanded(child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      DateTime dt = DateTime.parse(dateStr.split('.')[0]);
      return intl.DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').trim();
  }

  Widget _buildFloatingBottomActions() {
    if (_quotation.workflowActions.isEmpty || _quotation.docstatus == 1) return const SizedBox.shrink();
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: _quotation.workflowActions.map((action) {
            final actionLower = action.toLowerCase();
            bool isSuccess = actionLower.contains('approve') || actionLower.contains('verify');
            bool isReject = actionLower.contains('reject');
            Color bgColor = AppColors.primary;
            if (isSuccess) bgColor = const Color(0xFF10B981);
            if (isReject) bgColor = const Color(0xFFEF4444);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildActionButton(action.toUpperCase(), bgColor, Colors.white, onTap: () => _applyAction(action)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, Color bgColor, Color textColor, {Color? borderColor, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor) : null,
            boxShadow: bgColor != Colors.transparent && bgColor != Colors.white
                ? [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: Text(title, style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _SliverAppBarDelegate({required this.child, required this.height});
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
