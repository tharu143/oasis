import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/quotation/models/quotation_model.dart';
import 'package:oasis/features/quotation/presentation/screens/quotation_detail_screen.dart';

class QuotationListScreen extends StatefulWidget {
  final String? filterStatus;
  const QuotationListScreen({super.key, this.filterStatus});

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<Quotation> _quotations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _start = 0;
  final int _limit = 25;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _fetchQuotations();
      }
    });
  }

  Future<void> _fetchQuotations({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _start = 0;
        _quotations.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, String> params = {
        'limit_start': _start.toString(),
        'limit_page_length': _limit.toString(),
      };

      if (widget.filterStatus != null) {
        params['workflow_state'] = widget.filterStatus!;
      }

      if (_searchQuery.isNotEmpty) {
        params['search_term'] = _searchQuery;
      }
      if (widget.filterStatus != null) {
        params['workflow_state'] = widget.filterStatus!;
      }

      final response = await _apiClient.get('oasis_mobile.api.quotation.get_quotation_list', params: params);
      final List<dynamic> data = response['message']?['data'] ?? [];
      
      final List<Quotation> newItems = data.map((item) => Quotation.fromJson(item)).toList();

      setState(() {
        _quotations.addAll(newItems);
        _start += _limit;
        _hasMore = newItems.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching quotations: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          widget.filterStatus != null ? '${widget.filterStatus} Quotes' : 'Quotations',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchQuotations(refresh: true);
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by ID or Customer...',
                hintStyle: const TextStyle(color: AppColors.textLight),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchQuotations(refresh: true),
              color: AppColors.primary,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _quotations.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _quotations.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }
                  final q = _quotations[index];
                  return _buildQuotationCard(context, q);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(BuildContext context, Quotation q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuotationDetailScreen(quotation: q),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      q.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  _buildStatusBadge(q),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    q.transactionDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    '${q.currency} ${intl.NumberFormat('#,##0.00').format(q.baseGrandTotal)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Quotation q) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: q.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: q.statusColor.withOpacity(0.3)),
      ),
      child: Text(
        q.workflowState,
        style: GoogleFonts.plusJakartaSans(
          color: q.statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

