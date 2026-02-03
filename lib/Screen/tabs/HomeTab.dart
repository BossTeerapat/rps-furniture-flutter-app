import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/product/ProductListScreen.dart';
import 'package:rps_app/Screen/menu/CategoriesScreen.dart';
import 'package:rps_app/Screen/product/ProductDetailScreen.dart';
import 'package:rps_app/Screen/product/SearchScreen.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:rps_app/widgets/search_field.dart';
import 'package:rps_app/widgets/cart_button.dart';
import 'package:provider/provider.dart';
import 'package:rps_app/providers/cart_notifier.dart';
// shared preferences and cart API moved to CartNotifier
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  HomeTabState createState() => HomeTabState();
}

// Made public so other widgets can call refreshAllData via a GlobalKey
class HomeTabState extends State<HomeTab> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  // Cart badge is provided by CartNotifier

  // Product sections data
  final Map<String, List<Map<String, dynamic>>> _productSections = {
    'new': [],
    'bestseller': [],
    'sale': [],
    'recommend': [],
  };
  Map<String, bool> _sectionLoading = {
    'new': true,
    'bestseller': true,
    'sale': true,
    'recommend': true,
  };

  // All products (for the grid view and filter chips)
  List<Map<String, dynamic>> _allProducts = [];
  bool _isAllLoading = true;
  String _currentFilter = ''; // '' means all
  // pagination for all products
  int _allPage = 1;
  final int _allPageSize = 20; // as requested by backend
  int _allTotalPages = 1;
  bool _allHasMore = true;
  bool _allIsLoadingMore = false;
  late ScrollController _mainScrollController;

  // Cache system
  DateTime? _categoriesLastLoaded;
  Map<String, DateTime?> _sectionsLastLoaded = {
    'new': null,
    'bestseller': null,
    'sale': null,
    'recommend': null,
  };
  static const Duration _cacheExpiry = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _mainScrollController = ScrollController();
    _mainScrollController.addListener(_onMainScroll);
    _loadCategories();
    _loadProductSections();
    _loadAllProducts('');
    // initial cart count loaded by CartNotifier in main
    // Use dedicated SearchScreen on tap instead of inline overlay
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScroll);
    _mainScrollController.dispose();
    super.dispose();
  }

  void _onMainScroll() {
    if (!_allHasMore || _isAllLoading || _allIsLoadingMore) return;
    if (!_mainScrollController.hasClients) return;
    final threshold = 0; //โหลดรายการสินค้าชุดใหม่เมื่อถึงก้นหน้า
    final maxScroll = _mainScrollController.position.maxScrollExtent;
    final current = _mainScrollController.position.pixels;
    if (maxScroll - current <= threshold) {
      _loadAllProducts(_currentFilter, loadMore: true);
    }
  }

  // Check if cache is still valid
  bool _isCacheValid(DateTime? lastLoaded) {
    if (lastLoaded == null) return false;
    return DateTime.now().difference(lastLoaded) < _cacheExpiry;
  }

  // Get localized category text
  String _getCategoriesTitle(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en' ? 'Categories' : 'หมวดหมู่สินค้า';
  }

  String _getViewAllText(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en' ? 'View All' : 'ดูทั้งหมด';
  }

  String _getShopNowText(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en' ? 'Shop Now' : 'เลือกซื้อเลย';
  }

  String _getNoCategoriesText(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en'
        ? 'No categories available'
        : 'ไม่มีหมวดหมู่สินค้า';
  }

  String _getNoProductsText(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en'
        ? 'No products in this category'
        : 'ไม่มีสินค้าในหมวดหมู่นี้';
  }

  // Get localized category name
  String _getCategoryName(String categoryName) {
    final currentLocale = Localizations.localeOf(context).languageCode;

    if (currentLocale == 'en') {
      switch (categoryName) {
        case 'เตียงนอน':
          return 'Beds';
        case 'ตู้เสื้อผ้า':
          return 'Wardrobes';
        case 'โต๊ะอาหาร':
          return 'Dining Tables';
        case 'ที่นอน':
          return 'Mattresses';
        case 'โซฟา':
          return 'Sofas';
        default:
          return categoryName;
      }
    }
    return categoryName;
  }

  // Get localized status label
  String _getStatusLabel(String statusName) {
    final currentLocale = Localizations.localeOf(context).languageCode;

    if (currentLocale == 'en') {
      switch (statusName.toLowerCase()) {
        case 'new':
          return 'New';
        case 'sale':
          return 'Sale';
        case 'bestseller':
          return 'Best';
        case 'recommend':
          return 'Recommend';
        default:
          return statusName;
      }
    } else {
      switch (statusName.toLowerCase()) {
        case 'new':
          return 'สินค้าใหม่';
        case 'sale':
          return 'ลดราคา';
        case 'bestseller':
          return 'ขายดี';
        case 'recommend':
          return 'แนะนำ';
        default:
          return statusName;
      }
    }
  }

  String _getAllProductsTitle(AppLocalizations? localizations) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    return currentLocale == 'en' ? 'All Products' : 'สินค้าทั้งหมด';
  }

  String _formatPrice(double price) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    if (currentLocale == 'en') {
      return '฿${price.toStringAsFixed(0)}';
    } else {
      return '฿${price.toStringAsFixed(0)}';
    }
  }

  // Refresh all data (bypass cache)
  Future<void> _refreshAllData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _sectionLoading = {
          'new': true,
          'bestseller': true,
          'sale': true,
          'recommend': true,
        };
      });
    }

    // Clear cache timestamps to force reload
    _categoriesLastLoaded = null;
    _sectionsLastLoaded = {
      'new': null,
      'bestseller': null,
      'sale': null,
      'recommend': null,
    };

    await _loadCategories();
    await _loadProductSections();
    await Provider.of<CartNotifier>(context, listen: false).loadCount();
  }

  // Public helper to allow external callers to request a refresh
  Future<void> refreshAllData() async {
    await _refreshAllData();
  }

  Future<void> _loadCategories() async {
    // Check cache first
    if (_isCacheValid(_categoriesLastLoaded) && _categories.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listCategories),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['categories'] != null) {
          if (mounted) {
            setState(() {
              _categories = List<Map<String, dynamic>>.from(data['categories']);
              _isLoading = false;
            });
          }
          _categoriesLastLoaded = DateTime.now(); // Update cache timestamp
        } else {
          throw Exception(
            'API returned status: ${data['status']}, message: ${data['msg']}',
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดหมวดหมู่: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadProductSections() async {
    final statusList = ['new', 'bestseller', 'sale', 'recommend'];

    for (String status in statusList) {
      // Check cache first
      if (_isCacheValid(_sectionsLastLoaded[status]) &&
          (_productSections[status]?.isNotEmpty ?? false)) {
        if (mounted) {
          setState(() {
            _sectionLoading[status] = false;
          });
        }
        continue;
      }

      try {
        final headers = await ApiConfig.buildHeaders();
        final body = {"statusName": status};

        final response = await http.post(
          Uri.parse(ApiConfig.listProductsByStatus),
          headers: headers,
          body: json.encode(body),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['status'] == 200 && data['products'] != null) {
            if (mounted) {
              setState(() {
                _productSections[status] = List<Map<String, dynamic>>.from(
                  data['products'],
                );
                _sectionLoading[status] = false;
              });
            }
            _sectionsLastLoaded[status] =
                DateTime.now(); // Update cache timestamp
          } else {
            if (mounted) {
              setState(() {
                _sectionLoading[status] = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _sectionLoading[status] = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _sectionLoading[status] = false;
          });
        }
      }
    }
  }

  // Load all products or products filtered by statusName ('' returns all)
  Future<void> _loadAllProducts(
    String statusName, {
    bool loadMore = false,
  }) async {
    if (mounted) {
      _currentFilter = statusName;
    }

    if (loadMore) {
      if (!_allHasMore) return;
      if (mounted) {
        setState(() {
          _allIsLoadingMore = true;
          _allPage += 1;
        });
      } else {
        _allIsLoadingMore = true;
        _allPage += 1;
      }
    } else {
      if (mounted) {
        setState(() {
          _isAllLoading = true;
        });
      }
      _allPage = 1;
      _allHasMore = true;
      _allTotalPages = 1;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final body = {
        "statusName": statusName,
        'page': _allPage,
        'pageSize': _allPageSize,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.listProductsByStatus),
        headers: headers,
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final products = data['products'] ?? [];

        if (mounted) {
          setState(() {
            if (loadMore) {
              _allProducts.addAll(List<Map<String, dynamic>>.from(products));
            } else {
              _allProducts = List<Map<String, dynamic>>.from(products);
            }
            _isAllLoading = false;
            _allIsLoadingMore = false;
          });
        }

        // update pagination info if provided
        final int respPage =
            data['page'] is int
                ? data['page'] as int
                : (data['page'] is String
                    ? int.tryParse(data['page']) ?? _allPage
                    : _allPage);
        final dynamic totalPagesRaw = data['totalPages'];
        final int? respTotalPages =
            totalPagesRaw is int
                ? totalPagesRaw
                : (totalPagesRaw is String
                    ? int.tryParse(totalPagesRaw)
                    : null);
        if (mounted) {
          setState(() {
            _allPage = respPage;
            if (respTotalPages != null) {
              _allTotalPages = respTotalPages;
              _allHasMore = _allPage < _allTotalPages;
            } else {
              // fallback: if server didn't provide totalPages, decide by items length
              _allHasMore = List.from(products).length >= _allPageSize;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAllLoading = false;
            _allIsLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAllLoading = false;
          _allIsLoadingMore = false;
        });
      }
      print('Error loading all products (filter=$statusName): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: SearchField(
          readOnly: true,
          hint: localizations?.search ?? 'ค้นหาสินค้า',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SearchScreen()),
            );
          },
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
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Banner Section
                _buildBannerSection(localizations),

                const SizedBox(height: 20),

                // Categories Section
                _buildCategoriesSection(localizations),

                const SizedBox(height: 20),

                // // Product Sections
                // _buildProductSection('new', _getSectionTitle('new', localizations), localizations),
                // _buildProductSection('bestseller', _getSectionTitle('bestseller', localizations), localizations),
                // _buildProductSection('sale', _getSectionTitle('sale', localizations), localizations),
                // _buildProductSection('recommend', _getSectionTitle('recommend', localizations), localizations),
                const SizedBox(height: 8),
                // Filter chips for All Products
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildFilterChips(localizations),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _buildAllProductsGrid(localizations),
                      if (_allIsLoadingMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: _DotsLoading()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection(AppLocalizations? localizations) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: -100,
            bottom: -80,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localizations?.welcome ?? 'ยินดีต้อนรับสู่',
                        style: const TextStyle(
                          color: AppTheme.primaryWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.appName ?? 'รุ่งประเสริฐเฟอร์นิเจอร์',
                        style: const TextStyle(
                          color: AppTheme.primaryWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.brandSlogan ??
                            'เฟอร์นิเจอร์คุณภาพ ราคาเป็นกันเอง',
                        style: const TextStyle(
                          color: AppTheme.primaryWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to all products
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ProductListScreen(
                                    statusName: "",
                                    displayTitle: _getAllProductsTitle(
                                      localizations,
                                    ),
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryWhite,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _getShopNowText(localizations),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chair, color: AppTheme.primaryWhite, size: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(AppLocalizations? localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getCategoriesTitle(localizations),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  );
                },
                child: Text(
                  _getViewAllText(localizations),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _isLoading
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
            : _categories.isEmpty
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _getNoCategoriesText(localizations),
                  style: const TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),
            )
            : Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _buildCategoryItem(category);
                },
              ),
            ),
      ],
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    // Define icons for different categories
    IconData getIconForCategory(String categoryName) {
      switch (categoryName.toLowerCase()) {
        case 'เตียงนอน':
          return Icons.bed;
        case 'ตู้เสื้อผ้า':
          return Icons.checkroom;
        case 'โต๊ะอาหาร':
          return Icons.table_restaurant;
        case 'ที่นอน':
          return Icons.hotel;
        case 'โซฟา':
          return Icons.chair;
        default:
          return Icons.home_outlined;
      }
    }

    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // Navigate to category products
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ProductListScreen(
                    categoryId: category['id'] ?? 0,
                    categoryName: category['name'] ?? '',
                  ),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                getIconForCategory(category['name'] ?? ''),
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCategoryName(category['name'] ?? ''),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '(${category['_count']?['products'] ?? 0})',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final price = product['price']?.toDouble() ?? 0.0;
    final salePrice = product['salePrice']?.toDouble() ?? 0.0;
    final hasDiscount = salePrice > 0 && salePrice < price;
    final statusLabel = product['status']?['label'] ?? '';
    final statusName = product['status']?['name'] ?? '';

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Navigate to product detail and refresh cart count when returning
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        ProductDetailScreen(productId: product['id'] ?? 0),
              ),
            );
            // Refresh cart count after returning from product detail
            // Ask CartNotifier to reload
            Provider.of<CartNotifier>(context, listen: false).loadCount();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    color: Colors.grey[200],
                  ),
                  child: Stack(
                    children: [
                      // Image: ใช้ helper ตัวใหม่เพื่อรองรับหลายรูปแบบ
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: _buildProductImageWidget(product),
                      ),
                      // Status badge
                      if (statusLabel.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getStatusColor(statusName),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusLabel(statusName),
                              style: const TextStyle(
                                color: AppTheme.primaryWhite,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Discount badge
                      if (hasDiscount)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${(((price - salePrice) / price) * 100).round()}%',
                              style: const TextStyle(
                                color: AppTheme.primaryWhite,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Product Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product['name'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Price
                      if (hasDiscount) ...[
                        // Original price (crossed out)
                        Text(
                          _formatPrice(price),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondaryColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        // Sale price
                        Text(
                          _formatPrice(salePrice),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ] else ...[
                        // Regular price
                        Text(
                          _formatPrice(price),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations? localizations) {
    final chips = [
      {'label': _getAllProductsTitle(localizations), 'value': ''},
      {'label': _getStatusLabel('new'), 'value': 'new'},
      {'label': _getStatusLabel('bestseller'), 'value': 'bestseller'},
      {'label': _getStatusLabel('sale'), 'value': 'sale'},
      {'label': _getStatusLabel('recommend'), 'value': 'recommend'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            chips.map((c) {
              final selected = _currentFilter == c['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c['label'].toString()),
                  selected: selected,
                  onSelected: (_) async {
                    final value = c['value'].toString();
                    // load all products with this filter
                    await _loadAllProducts(value);
                    // if user picks a curated filter, scroll to that curated section optionally
                    // For now, we just refresh the grid
                  },
                  selectedColor: AppTheme.primaryColor.withOpacity(0.12),
                  backgroundColor: AppTheme.primaryWhite,
                  labelStyle: TextStyle(
                    color:
                        selected
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimaryColor,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildAllProductsGrid(AppLocalizations? localizations) {
    if (_isAllLoading) {
      return SizedBox(
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_allProducts.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          _getNoProductsText(localizations),
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    // Show a compact grid of products (2 columns)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final p = _allProducts[index];
        return _buildProductCard(p);
      },
    );
  }

  Widget _buildProductImageWidget(Map<String, dynamic> product) {
    try {
      final images = product['images'];
      dynamic firstImage;
      if (images is List && images.isNotEmpty) {
        firstImage = images[0];
        if (firstImage is Map) {
          firstImage =
              firstImage['url'] ??
              firstImage['base64'] ??
              firstImage['data'] ??
              firstImage['image'];
        }
      }

      if (firstImage == null) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.image, color: Colors.grey[400], size: 40),
        );
      }

      return buildProductImageWidget(
        firstImage,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return Container(
        color: Colors.grey[200],
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey[400],
          size: 40,
        ),
      );
    }
  }
}

// A small, tasteful three-dot loading indicator
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
