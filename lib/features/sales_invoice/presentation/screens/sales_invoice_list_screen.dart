import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/sales_invoice_model.dart';
import 'sales_invoice_detail_screen.dart';

class SalesInvoiceListScreen extends StatefulWidget {
  final String? filterStatus;
  const SalesInvoiceListScreen({super.key, this.filterStatus});

  @override
  State<SalesInvoiceListScreen> createState() => _SalesInvoiceListScreenState();
}

class _SalesInvoiceListScreenState extends State<SalesInvoiceListScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<SalesInvoiceModel> _salesInvoices = [];
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
    _fetchSalesInvoices();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _fetchSalesInvoices();
      }
    });
  }

  Future<void> _fetchSalesInvoices({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _start = 0;
        _salesInvoices.clear();
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

      if (widget.filterStatus != null && widget.filterStatus!.isNotEmpty) {
        params['status'] = widget.filterStatus!;
        params['workflow_state'] = widget.filterStatus!;
      }

      if (_searchQuery.isNotEmpty) {
        params['search_term'] = _searchQuery;
      }

      dynamic response;
      try {
        response = await _apiClient.get('oasis_mobile.api.sales_invoice.get_sales_invoice_list', params: params);
      } catch (_) {
        // Fallback: Fetch directly using standard REST resource endpoints
        final Map<String, String> restParams = {
          'fields': '["name","customer","customer_name","posting_date","due_date","currency","grand_total","outstanding_amount","status","workflow_state"]',
          'limit_start': _start.toString(),
          'limit_page_length': _limit.toString(),
          'order_by': 'creation desc',
        };
        List<String> filters = [];
        if (widget.filterStatus != null && widget.filterStatus!.isNotEmpty) {
          filters.add('["status","=","${widget.filterStatus}"]');
        }
        if (_searchQuery.isNotEmpty) {
          filters.add('["customer_name","like","%$_searchQuery%"]');
        }
        if (filters.isNotEmpty) {
          restParams['filters'] = '[${filters.join(",")}]';
        }
        response = await _apiClient.get('../resource/Sales Invoice', params: restParams);
      }

      final List<dynamic> data = response['message']?['data'] ?? response['data'] ?? response['message'] ?? [];
      final List<SalesInvoiceModel> newItems = data.map((item) => SalesInvoiceModel.fromJson(Map<String, dynamic>.from(item))).toList();

      setState(() {
        _salesInvoices.addAll(newItems);
        _start += _limit;
        _hasMore = newItems.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching invoices: $e')),
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
          widget.filterStatus != null && widget.filterStatus!.isNotEmpty 
              ? '${widget.filterStatus} Invoices' 
              : 'Sales Invoices',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchSalesInvoices(refresh: true);
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by Customer...',
                hintStyle: const TextStyle(color: AppColors.textLight),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6), size: 20),
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
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchSalesInvoices(refresh: true),
              color: const Color(0xFF8B5CF6),
              child: _salesInvoices.isEmpty && !_isLoading
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            Text(
                              'No Invoices Found',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _salesInvoices.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _salesInvoices.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                            ),
                          );
                        }
                        final invoice = _salesInvoices[index];
                        return _buildInvoiceCard(context, invoice);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, SalesInvoiceModel invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.05),
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
              builder: (context) => SalesInvoiceDetailScreen(salesInvoice: invoice),
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
                      invoice.name ?? 'No Name',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  _buildStatusBadge(invoice),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      invoice.customerName ?? invoice.customer,
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
                    invoice.postingDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    '${invoice.currency} ${intl.NumberFormat('#,##0.00').format(invoice.grandTotal ?? 0.0)}',
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

  Widget _buildStatusBadge(SalesInvoiceModel invoice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: invoice.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: invoice.statusColor.withOpacity(0.3)),
      ),
      child: Text(
        invoice.status ?? invoice.workflowState ?? 'Draft',
        style: GoogleFonts.plusJakartaSans(
          color: invoice.statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
