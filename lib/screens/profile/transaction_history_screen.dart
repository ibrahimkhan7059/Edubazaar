import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user_transaction.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import '../../services/auth_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<UserTransaction> _allTransactions = [];
  final List<UserTransaction> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, sales, purchases, donations
  String _searchQuery = '';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = [
    'all',
    'sales',
    'purchases',
    'donations'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'all';
            break;
          case 1:
            _selectedFilter = 'sales';
            break;
          case 2:
            _selectedFilter = 'purchases';
            break;
          case 3:
            _selectedFilter = 'donations';
            break;
        }
        setState(() {}); // Update stats
      }
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      print('📊 Loading transaction history...');

      // Try to load real transactions first
      List<UserTransaction> realTransactions = [];
      try {
        realTransactions = await _loadRealTransactions();
        print('✅ Loaded ${realTransactions.length} real transactions');
      } catch (e) {
        print('ℹ️ Real transactions not available: $e');
      }

      // Generate simulated transactions from listings for demo
      List<UserTransaction> simulatedTransactions =
          await _generateSimulatedTransactions();
      print(
          '✅ Generated ${simulatedTransactions.length} simulated transactions');

      // Combine and sort
      _allTransactions = [...realTransactions, ...simulatedTransactions];
      _allTransactions
          .sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    } catch (e) {
      print('❌ Error loading transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadTransactions,
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<UserTransaction>> _loadRealTransactions() async {
    // This will work when transactions table exists
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return [];

    // Query real transactions table (when it exists)
    // For now, return empty list
    return [];
  }

  Future<List<UserTransaction>> _generateSimulatedTransactions() async {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return [];

    List<UserTransaction> simulated = [];

    try {
      // Get user's listings to simulate sales
      final userListings =
          await MarketplaceService.getUserListings(currentUserId);

      for (int i = 0; i < userListings.length; i++) {
        final listing = userListings[i];

        // Simulate some transactions based on listing status
        if (listing.status == 'sold' || (i % 3 == 0)) {
          // Simulate some sales
          simulated.add(UserTransaction(
            id: 'sim_sale_${listing.id}',
            sellerId: currentUserId,
            buyerId: 'buyer_${i + 1}',
            listingId: listing.id,
            transactionDate: DateTime.now().subtract(Duration(days: i * 2)),
            status: listing.status == ListingStatus.sold
                ? TransactionStatus.completed
                : TransactionStatus.pending,
            transactionType: TransactionType.sale,
            amount: listing.price ?? 0.0,
            notes: 'Simulated sale transaction for ${listing.title}',
            createdAt: DateTime.now().subtract(Duration(days: i * 2)),
            updatedAt: DateTime.now().subtract(Duration(days: i)),
            // Additional fields for display
            listingTitle: listing.title,
            listingImage:
                listing.images.isNotEmpty ? listing.images.first : null,
            buyerName: 'Buyer ${i + 1}',
          ));
        }

        // Simulate some purchases (random)
        if (i % 4 == 0) {
          simulated.add(UserTransaction(
            id: 'sim_purchase_$i',
            sellerId: 'seller_$i',
            buyerId: currentUserId,
            listingId: 'listing_$i',
            transactionDate: DateTime.now().subtract(Duration(days: i * 3)),
            status: TransactionStatus.completed,
            transactionType: TransactionType.purchase,
            amount: (50 + (i * 25)).toDouble(),
            notes: 'Simulated purchase transaction',
            createdAt: DateTime.now().subtract(Duration(days: i * 3)),
            updatedAt: DateTime.now().subtract(Duration(days: i * 2)),
            // Additional fields for display
            listingTitle: 'Sample Book ${i + 1}',
            listingImage: null,
            sellerName: 'Seller ${i + 1}',
          ));
        }
      }

      // Add some donation examples
      if (simulated.length < 3) {
        simulated.add(UserTransaction(
          id: 'sim_donation_1',
          sellerId: currentUserId,
          buyerId: 'student_1',
          listingId: 'donation_1',
          transactionDate: DateTime.now().subtract(const Duration(days: 5)),
          status: TransactionStatus.completed,
          transactionType: TransactionType.donation,
          amount: 0.0,
          notes: 'Donated study materials to junior student',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now().subtract(const Duration(days: 4)),
          listingTitle: 'Physics Notes Donation',
          listingImage: null,
          buyerName: 'Student in Need',
        ));
      }
    } catch (e) {
      print('❌ Error generating simulated transactions: $e');
    }

    return simulated;
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions();
  }

  String _getOtherUserName(UserTransaction transaction) {
    final currentUserId = AuthService.getCurrentUserId();
    if (transaction.transactionType == TransactionType.sale) {
      // For sales, the other party is the buyer
      return transaction.buyerName ?? 'Unknown Buyer';
    } else {
      // For purchases and donations, the other party is the seller
      return transaction.sellerName ?? 'Unknown Seller';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          onTap: (index) {
            // The TabBarView will handle the switching automatically
            // We just need to update the selected filter for search/status filtering
            switch (index) {
              case 0:
                _selectedFilter = 'all';
                break;
              case 1:
                _selectedFilter = 'sales';
                break;
              case 2:
                _selectedFilter = 'purchases';
                break;
              case 3:
                _selectedFilter = 'donations';
                break;
            }
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Sales'),
            Tab(text: 'Purchases'),
            Tab(text: 'Donations'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildSummaryStats(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionList('all'),
                        _buildTransactionList('sales'),
                        _buildTransactionList('purchases'),
                        _buildTransactionList('donations'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(String filterType) {
    List<UserTransaction> transactions = _getFilteredTransactions(filterType);

    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionCard(transactions[index]);
        },
      ),
    );
  }

  List<UserTransaction> _getFilteredTransactions(String filterType) {
    List<UserTransaction> filtered = List.from(_allTransactions);

    // Filter by type
    if (filterType != 'all') {
      TransactionType? targetType;
      switch (filterType) {
        case 'sales':
          targetType = TransactionType.sale;
          break;
        case 'purchases':
          targetType = TransactionType.purchase;
          break;
        case 'donations':
          targetType = TransactionType.donation;
          break;
      }
      if (targetType != null) {
        filtered =
            filtered.where((t) => t.transactionType == targetType).toList();
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.listingTitle
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ==
                  true ||
              _getOtherUserName(t)
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              t.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ==
                  true)
          .toList();
    }

    return filtered;
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          // Force rebuild of all tab views by calling setState
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSummaryStats() {
    // Get current tab's transactions
    List<UserTransaction> currentTransactions =
        _getFilteredTransactions(_selectedFilter);

    final totalAmount =
        currentTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final salesCount = currentTransactions
        .where((t) => t.transactionType == TransactionType.sale)
        .length;
    final purchasesCount = currentTransactions
        .where((t) => t.transactionType == TransactionType.purchase)
        .length;
    final donationsCount = currentTransactions
        .where((t) => t.transactionType == TransactionType.donation)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', 'Rs. ${totalAmount.toStringAsFixed(0)}',
              AppTheme.primaryColor),
          _buildStatItem('Sales', '$salesCount', Colors.green),
          _buildStatItem('Purchases', '$purchasesCount', Colors.blue),
          _buildStatItem('Donations', '$donationsCount', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(UserTransaction transaction) {
    final currentUserId = AuthService.getCurrentUserId();
    final isIncoming = transaction.transactionType == TransactionType.sale ||
        (transaction.transactionType == TransactionType.donation &&
            transaction.sellerId == currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildTransactionIcon(transaction),
        title: Text(
          transaction.listingTitle ?? 'Unknown Item',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getOtherUserName(transaction),
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a')
                  .format(transaction.transactionDate),
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (transaction.amount > 0)
              Text(
                '${isIncoming ? '+' : '-'}Rs. ${transaction.amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isIncoming ? Colors.green : Colors.red,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            _buildStatusChip(transaction.status),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  Widget _buildTransactionIcon(UserTransaction transaction) {
    IconData iconData;
    Color color;

    switch (transaction.transactionType) {
      case TransactionType.sale:
        iconData = Icons.sell;
        color = Colors.green;
        break;
      case TransactionType.purchase:
        iconData = Icons.shopping_cart;
        color = Colors.blue;
        break;
      case TransactionType.donation:
        iconData = Icons.favorite;
        color = Colors.orange;
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildStatusChip(TransactionStatus status) {
    Color color;
    switch (status) {
      case TransactionStatus.completed:
        color = Colors.green;
        break;
      case TransactionStatus.pending:
        color = Colors.orange;
        break;
      case TransactionStatus.cancelled:
        color = Colors.red;
        break;
      case TransactionStatus.disputed:
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here\nonce you start buying or selling items.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshTransactions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Refresh',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(UserTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildTransactionIcon(transaction),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.listingTitle ?? 'Unknown Item',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transaction.transactionType.displayName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusChip(transaction.status),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Details
                        _buildDetailRow('Transaction ID', transaction.id),
                        _buildDetailRow(
                            'Date',
                            DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(transaction.transactionDate)),
                        _buildDetailRow(
                            'Other Party', _getOtherUserName(transaction)),
                        if (transaction.amount > 0)
                          _buildDetailRow('Amount',
                              'Rs. ${transaction.amount.toStringAsFixed(0)}'),
                        if (transaction.notes?.isNotEmpty == true)
                          _buildDetailRow('Notes', transaction.notes!),

                        const SizedBox(height: 24),

                        // Actions
                        if (transaction.status == TransactionStatus.pending)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // TODO: Implement cancel transaction
                                  },
                                  child: Text(
                                    'Cancel',
                                    style:
                                        GoogleFonts.poppins(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // TODO: Implement complete transaction
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                  child: Text(
                                    'Complete',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for string capitalization
extension StringCapitalization on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
 