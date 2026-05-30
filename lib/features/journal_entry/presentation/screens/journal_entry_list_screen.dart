import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/journal_entry_model.dart';
import 'journal_entry_detail_screen.dart';

class JournalEntryListScreen extends StatefulWidget {
  final String? initialState;
  const JournalEntryListScreen({super.key, this.initialState});

  @override
  State<JournalEntryListScreen> createState() => _JournalEntryListScreenState();
}

class _JournalEntryListScreenState extends State<JournalEntryListScreen> {
  final ApiClient _apiClient = ApiClient();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _start = 0;
  final int _pageLength = 25;
  String _selectedState = '';
  String _searchQuery = '';

  final List<String> _states = [
    'All',
    'Draft',
    'Pending',
    'Verified By Finance Team',
    'Rejected By Finance Team',
    'Approved By MD',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _selectedState = widget.initialState ?? 'All';
    _fetchList(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchList();
      }
    }
  }

  Future<void> _fetchList({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _start = 0;
        _items.clear();
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final params = {
        'limit_start': _start.toString(),
        'limit_page_length': _pageLength.toString(),
      };

      if (_selectedState.isNotEmpty && _selectedState != 'All') {
        params['workflow_state'] = _selectedState;
      }
      if (_searchQuery.isNotEmpty) {
        params['search_txt'] = _searchQuery;
      }

      final response = await _apiClient.get(
        'oasis_mobile.api.journal_entry.get_journal_entry_list',
        params: params,
      );

      final messageMap = response['message'] is Map ? response['message'] : null;
      final List<dynamic> data = (messageMap != null ? messageMap['data'] : null) ?? response['data'] ?? [];
      final bool hasMore = (messageMap != null ? messageMap['has_more'] : null) ?? response['has_more'] ?? false;

      setState(() {
        _items.addAll(data);
        _hasMore = hasMore;
        _start += _pageLength;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load list: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBox(),
          _buildStatusTabs(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchList(refresh: true),
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                            }
                            return _buildListTile(_items[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        'Journal Entries',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                  _fetchList(refresh: true);
                },
                decoration: InputDecoration(
                  hintText: 'Search vouchers...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textLight, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _fetchList(refresh: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _states.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedState == _states[index] ||
              (_selectedState == '' && _states[index] == 'All');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                _states[index],
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedState = _states[index] == 'All' ? '' : _states[index];
                  });
                  _fetchList(refresh: true);
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border),
              ),
              elevation: 0,
              pressElevation: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildListTile(Map<String, dynamic> item) {
    final docname = item['name'] ?? '';
    final company = item['company'] ?? '';
    final type = item['voucher_type'] ?? 'Journal Entry';
    final date = item['posting_date'] ?? '';
    final debit = (item['total_debit'] as num? ?? 0.0).toDouble();
    final credit = (item['total_credit'] as num? ?? 0.0).toDouble();
    final state = item['workflow_state'] ?? 'Draft';

    Color stateCol;
    final lstate = state.toString().toLowerCase();
    if (lstate.contains('approved') || lstate == 'submitted') {
      stateCol = AppColors.approvedMD;
    } else if (lstate.contains('reject')) {
      stateCol = AppColors.rejectedMD;
    } else if (lstate == 'draft') {
      stateCol = AppColors.draft;
    } else if (lstate.contains('verified')) {
      stateCol = AppColors.verifiedFinance;
    } else if (lstate.contains('cancel')) {
      stateCol = AppColors.cancelled;
    } else {
      stateCol = AppColors.pendingFinance;
    }

    String formattedDate = '';
    try {
      if (date.isNotEmpty) {
        final parsed = DateTime.parse(date);
        formattedDate = DateFormat('dd MMM yyyy').format(parsed);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          // Wrap in a lightweight JournalEntryModel stub
          final stub = JournalEntryModel(
            name: docname,
            company: company,
            voucherType: type,
            postingDate: date,
            workflowState: state,
            totalDebit: debit,
            totalCredit: credit,
            difference: 0.0,
            accounts: [],
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JournalEntryDetailScreen(journalEntry: stub),
            ),
          ).then((_) => _fetchList(refresh: true));
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      docname,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stateCol.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: stateCol,
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
                    type,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    company.isNotEmpty ? company : 'Oasis Trading',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    'QAR ${debit.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.primary,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          Text(
            'No Entries Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new Journal Entry or adjust filters.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
