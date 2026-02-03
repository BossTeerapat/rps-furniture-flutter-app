import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
// product detail and image helper moved to ProductCard widget
import 'package:rps_app/widgets/product_card.dart';
import 'package:rps_app/widgets/search_field.dart';
import 'package:rps_app/widgets/cart_button.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductListScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  final String? statusName;
  final String? displayTitle;
  final List<Map<String, dynamic>>? initialProducts;
  final String? initialQuery;

  const ProductListScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.statusName,
    this.displayTitle,
    this.initialProducts,
    this.initialQuery,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _filterCategory = '';
  // pagination
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // initialize scroll controller so it's always available to the scroll view
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // If caller provided an initial products list (e.g. search results), use it
    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      _products = widget.initialProducts!;
      _isLoading = false;
      _filterCategory =
          widget.initialQuery ??
          widget.displayTitle ??
          widget.categoryName ??
          'ผลลัพธ์การค้นหา';
  // If initial list is smaller than a full page, don't show the loading footer
  _hasMore = _products.length >= _pageSize;
    } else {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    const threshold = 200;
    final pos = _scrollController.position;
    if (pos.pixels + threshold >= pos.maxScrollExtent) {
      _loadProducts(loadMore: true);
    }
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
      _page += 1;
    } else {
      setState(() {
        _isLoading = true;
      });
      _page = 1;
      _hasMore = true;
    }
    try {
      final headers = await ApiConfig.buildHeaders();
      Map<String, dynamic> body = {};

      // Set body based on what parameters are provided
      if (widget.categoryId != null) {
        body["categoryId"] = widget.categoryId;
      } else if (widget.statusName != null) {
        body["statusName"] = widget.statusName;
      } else {
        body["statusName"] = ""; // Show all products
      }

      // include pagination
      body['page'] = _page;
      body['pageSize'] = _pageSize;

      final response = await http.post(
        Uri.parse(ApiConfig.listProductsByStatus),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['products'] != null) {
          final List<Map<String, dynamic>> newItems =
              List<Map<String, dynamic>>.from(data['products']);
          final int serverPage = data['page'] ?? _page;
          final int? totalPages = data['totalPages'];

          setState(() {
            if (loadMore) {
              _products.addAll(newItems);
            } else {
              _products = newItems;
            }

            _filterCategory =
                data['filterInfo']?['category'] ??
                widget.categoryName ??
                widget.displayTitle ??
                'สินค้าทั้งหมด';

            if (totalPages != null) {
              _hasMore = serverPage < totalPages;
            } else {
              _hasMore = newItems.length >= _pageSize;
            }

            _isLoading = false;
            _isLoadingMore = false;
          });
        } else {
          throw Exception(
            'API returned status: ${data['status']}, message: ${data['msg']}',
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดสินค้า: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: SearchField(
          readOnly: true,
          hint:
              _filterCategory.isNotEmpty
                  ? _filterCategory
                  : (widget.categoryName ?? widget.displayTitle ?? 'สินค้า'),
          onTap: () {
            // Close this ProductListScreen and return to the previous SearchScreen
            Navigator.pop(context);
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [const CartButton(), const SizedBox(width: 8)],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.backgroundColor, AppTheme.primaryWhite],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? _buildEmptyState(localizations)
                : _buildProductList(),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่มีสินค้าในหมวดหมู่นี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ลองเลือกหมวดหมู่อื่นดูครับ',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      children: [
        // Product count header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            'สินค้าทั้งหมด ${_products.length} รายการ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
        // Product grid (sliver) with full-width footer for loader
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _products[index];
                      return ProductCard(product: product);
                    },
                    childCount: _products.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                ),
              ),
              if (_hasMore)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: _DotsLoading()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  

  // status color helper moved to ProductCard
}

// Local three-dot loading indicator (copied from HomeTab's _DotsLoading)
class _DotsLoading extends StatefulWidget {
  const _DotsLoading();

  @override
  State<_DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<_DotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final t = (progress + i * 0.2) % 1.0;
              final opacity = (t < 0.5) ? (0.5 + t) : (1.5 - t);
              return Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
