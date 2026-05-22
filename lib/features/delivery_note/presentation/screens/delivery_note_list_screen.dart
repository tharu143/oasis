import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import 'package:oasis/features/delivery_note/models/delivery_note_model.dart';
import 'delivery_note_detail_screen.dart';

class DeliveryNoteListScreen extends StatefulWidget {
  final String? filterStatus;
  const DeliveryNoteListScreen({super.key, this.filterStatus});

  @override
  State<DeliveryNoteListScreen> createState() => _DeliveryNoteListScreenState();
}

class _DeliveryNoteListScreenState extends State<DeliveryNoteListScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<DeliveryNoteModel> _deliveryNotes = [];
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
    _fetchDeliveryNotes();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _fetchDeliveryNotes();
      }
    });
  }

  Future<void> _fetchDeliveryNotes({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _start = 0;
        _deliveryNotes.clear();
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
        params['workflow_state'] = widget.filterStatus!;
      }

      if (_searchQuery.isNotEmpty) {
        params['search_term'] = _searchQuery;
      }

      final response = await _apiClient.get('oasis_mobile.api.delivery_note.get_delivery_note_list', params: params);
      final List<dynamic> data = response['message']?['data'] ?? response['data'] ?? [];
      
      final List<DeliveryNoteModel> newItems = data.map((item) => DeliveryNoteModel.fromJson(item)).toList();

      setState(() {
        _deliveryNotes.addAll(newItems);
        _start += _limit;
        _hasMore = newItems.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching delivery notes: $e')),
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
              ? '${widget.filterStatus} Notes' 
              : 'Delivery Notes',
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
                _fetchDeliveryNotes(refresh: true);
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by ID or Customer...',
                hintStyle: const TextStyle(color: AppColors.textLight),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF3B82F6), size: 20),
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
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchDeliveryNotes(refresh: true),
              color: const Color(0xFF3B82F6),
              child: _deliveryNotes.isEmpty && !_isLoading
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            Text(
                              'No Delivery Notes Found',
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
                      itemCount: _deliveryNotes.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _deliveryNotes.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                            ),
                          );
                        }
                        final note = _deliveryNotes[index];
                        return _buildDeliveryNoteCard(context, note);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryNoteCard(BuildContext context, DeliveryNoteModel note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.05),
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
              builder: (context) => DeliveryNoteDetailScreen(deliveryNote: note),
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
                      note.name ?? 'No Name',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  _buildStatusBadge(note),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.customerName ?? note.customer,
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
                    note.postingDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    '${note.currency} ${intl.NumberFormat('#,##0.00').format(note.grandTotal ?? 0.0)}',
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

  Widget _buildStatusBadge(DeliveryNoteModel note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: note.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: note.statusColor.withOpacity(0.3)),
      ),
      child: Text(
        note.workflowState ?? 'Draft',
        style: GoogleFonts.plusJakartaSans(
          color: note.statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
