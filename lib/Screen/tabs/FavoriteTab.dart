import 'package:flutter/material.dart';
import 'package:rps_app/widgets/cart_button.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/Screen/product/ProductDetailScreen.dart';

class FavoriteTab extends StatefulWidget {
  final bool active;
  const FavoriteTab({Key? key, this.active = false}) : super(key: key);

  @override
  State<FavoriteTab> createState() => _FavoriteTabState();
}

class _FavoriteTabState extends State<FavoriteTab> {
  List<dynamic> _favoriteProducts = [];
  bool _isLoading = true;
  String? _error;
  // pagination
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _checkAuthAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check auth when the widget becomes active again
    _checkAuthAndLoad();
  }

  @override
  void didUpdateWidget(covariant FavoriteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the tab becomes active (from false -> true), reload favorites
    if (widget.active && !oldWidget.active) {
      _checkAuthAndLoad();
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
    const threshold = 200; // px before reaching bottom to prefetch
    final pos = _scrollController.position;
    if (pos.pixels + threshold >= pos.maxScrollExtent) {
      _loadFavoriteProducts(loadMore: true);
    }
  }

  Future<void> _loadFavoriteProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() { _isLoadingMore = true; });
      _page += 1;
    } else {
      setState(() { _isLoading = true; _error = null; });
      _page = 1;
      _hasMore = true;
    }
    try {
      // state set above

      final prefs = await SharedPreferences.getInstance();

      // ลองดึง accountId จาก user_id หรือ accountId
      int? accountId = prefs.getInt('user_id') ?? prefs.getInt('accountId');
      if (accountId == null) {
        // ลองดึงในรูปแบบ String แล้วแปลงเป็น int
        final userIdString =
            prefs.getString('user_id') ?? prefs.getString('accountId');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      // ตรวจสอบว่าผู้ใช้เข้าสู่ระบบหรือไม่จาก username หรือ isLoggedIn
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final username = prefs.getString('username');
      final hasUserData = username != null && username.isNotEmpty;

      if (accountId == null || (!isLoggedIn && !hasUserData)) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'กรุณาเข้าสู่ระบบ';
          });
        }
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listFaveriteProduct),
        headers: headers,
        body: jsonEncode({'accountId': accountId, 'page': _page, 'pageSize': _pageSize}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = List<dynamic>.from(data['favorites'] ?? []);
        final int serverPage = data['page'] ?? _page;
        final int? totalPages = data['totalPages'];

        if (mounted) {
          setState(() {
            if (loadMore) {
              _favoriteProducts.addAll(items);
            } else {
              _favoriteProducts = items;
            }

            if (totalPages != null) {
              _hasMore = serverPage < totalPages;
            } else {
              _hasMore = items.length >= _pageSize;
            }

            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'ไม่สามารถโหลดรายการโปรดได้';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'เกิดข้อผิดพลาด: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToProductDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(productId: product['id']),
      ),
    ).then((_) {
      // Refresh favorites when returning from product detail
      _checkAuthAndLoad();
    });
  }

  Future<void> _checkAuthAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    int? accountId = prefs.getInt('user_id') ?? prefs.getInt('accountId');
    if (accountId == null) {
      final userIdString = prefs.getString('user_id') ?? prefs.getString('accountId');
      if (userIdString != null && userIdString.isNotEmpty) {
        accountId = int.tryParse(userIdString);
      }
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (accountId == null || !isLoggedIn) {
      // Not logged in: clear any previous data and show prompt
      if (mounted) {
        setState(() {
          _favoriteProducts = [];
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = false;
          _error = 'กรุณาเข้าสู่ระบบ';
        });
      }
      return;
    }

    // Logged in -> load favorites
    await _loadFavoriteProducts(loadMore: false);
  }

  // cart count is handled by CartNotifier

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          localizations?.favorite ?? 'รายการโปรด',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [const CartButton(), const SizedBox(width: 8)],
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
                : (_error != null || _favoriteProducts.isEmpty)
                ? RefreshIndicator(
                  onRefresh: () => _loadFavoriteProducts(loadMore: false),
                  color: AppTheme.primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      // ensure the scrollable area fills the viewport so pull-to-refresh works
                      height: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 80,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            localizations?.favorite ?? 'รายการโปรด',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'ยังไม่มีสินค้าในรายการโปรด',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : RefreshIndicator(
                  onRefresh: () => _loadFavoriteProducts(loadMore: false),
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _favoriteProducts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _favoriteProducts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final favorite = _favoriteProducts[index];
                      final product = favorite['product'];
                      return _buildFavoriteCard(product);
                    },
                  ),
                ),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> product) {
    final images = product['images'] as List<dynamic>?;
    final imageUrl = images?.isNotEmpty == true ? images![0]['url'] : null;
    final price = product['price']?.toDouble() ?? 0.0;
    final salePrice = product['salePrice']?.toDouble();
    final status = product['status'];
    final category = product['category'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProductDetail(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child:
                      imageUrl != null
                          ? buildProductImageWidget(
                            imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                          : const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category
                    if (category != null)
                      Text(
                        'หมวดหมู่: ${category['name']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Status Badge
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status['name']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status['label'] ?? status['name'],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Price
                    Row(
                      children: [
                        if (salePrice != null && salePrice < price) ...[
                          Text(
                            '฿${salePrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '฿${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '฿${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Stock
                    const SizedBox(height: 4),
                    Text(
                      'คงเหลือ: ${product['stock'] ?? 0} ชิ้น',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String statusName) {
    return AppTheme.getStatusColor(statusName);
  }
}
