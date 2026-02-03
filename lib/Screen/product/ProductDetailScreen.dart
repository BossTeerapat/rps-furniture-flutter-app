import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:rps_app/widgets/cart_button.dart';
import 'package:provider/provider.dart';
import 'package:rps_app/providers/cart_notifier.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingReviews = false;
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  bool _isAddingToCart = false;
  // cart count is provided by CartNotifier; no local copy needed

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
    _loadProductReviews();
    // ensure provider has correct cart count after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<CartNotifier>(context, listen: false).loadCount();
      } catch (_) {}
    });
  }

  Future<void> _loadProductDetail() async {
    try {
      final headers = await ApiConfig.buildHeaders();

      // include accountId if available so the API can return per-user fields like isFavorited
      final prefs = await SharedPreferences.getInstance();
      int? accountId = prefs.getInt('user_id') ?? prefs.getInt('accountId');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id') ?? prefs.getString('accountId');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      final body = {"id": widget.productId, "action": "detail"};
      if (accountId != null) {
        body['accountId'] = accountId;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.productDetail),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['product'] != null) {
          setState(() {
            _product = data['product'];
            // Prefer top-level isFavorited returned by the API when available
            var apiFav = data['isFavorited'] ?? data['is_favorited'] ?? data['favorited'];
            bool isFav = false;

            if (apiFav != null) {
              if (apiFav is bool) {
                isFav = apiFav;
              } else if (apiFav is int) {
                isFav = apiFav > 0;
              } else if (apiFav is String) {
                final s = apiFav.toLowerCase();
                isFav = s == '1' || s == 'true' || s == 'yes';
              }
            } else {
              // If API does not return top-level isFavorited, treat as "no user context" (not logged in)
              // and display as not favorited. Do NOT infer per-user favorite from product-level fields.
              isFav = false;
            }

            _isFavorite = isFav;
            _isLoading = false;
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
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลสินค้า: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadProductReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final body = {"id": widget.productId};

      final response = await http.post(
        Uri.parse(ApiConfig.productReview),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<Map<String, dynamic>> loadedReviews = [];

        // If the API returns an object with a 'reviews' key
        if (decoded is Map &&
            decoded['reviews'] != null &&
            decoded['reviews'] is List) {
          try {
            loadedReviews = List<Map<String, dynamic>>.from(decoded['reviews']);
          } catch (_) {
            loadedReviews =
                (decoded['reviews'] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
          }
        }
        // If the API returns a list directly
        else if (decoded is List) {
          try {
            loadedReviews = List<Map<String, dynamic>>.from(decoded);
          } catch (_) {
            loadedReviews =
                decoded
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
          }
        }

        setState(() {
          _reviews = loadedReviews;
          _isLoadingReviews = false;
        });
      } else {
        setState(() {
          _reviews = [];
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      setState(() {
        _reviews = [];
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;

    // Get user ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Try to get user_id as int first, then as string
    int? userId = prefs.getInt('user_id');
    if (userId == null) {
      final userIdString = prefs.getString('user_id');
      if (userIdString != null && userIdString.isNotEmpty) {
        userId = int.tryParse(userIdString);
      }
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มสินค้าที่ถูกใจ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isFavoriteLoading = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final body = {
        "action": _isFavorite ? "unfavorite" : "favorite",
        "accountId": userId, // ใช้ userId ที่เป็น int แล้ว
        "productId": widget.productId,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.updateFaveriteProduct),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isFavorite = !_isFavorite;
          // Update favorite count
          if (_product != null) {
            _product!['favoriteCount'] =
                _isFavorite
                    ? (_product!['favoriteCount'] ?? 0) + 1
                    : (_product!['favoriteCount'] ?? 1) - 1;
          }
          _isFavoriteLoading = false;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       _isFavorite
        //           ? 'เพิ่มสินค้าในรายการที่ถูกใจแล้ว'
        //           : 'ลบสินค้าออกจากรายการที่ถูกใจแล้ว',
        //     ),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isFavoriteLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _product == null
              ? _buildErrorState()
              : CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildProductImages(),
                        _buildProductInfo(),
                        _buildProductDescription(),
                        _buildReviewsSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
      bottomNavigationBar: _product != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่พบข้อมูลสินค้า',
            style: TextStyle(fontSize: 18, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('กลับ'),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.primaryColor,
      expandedHeight: 0,
      floating: true,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _product?['name'] ?? 'รายละเอียดสินค้า',
        style: const TextStyle(
          color: AppTheme.primaryWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        CartButton(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.share, color: AppTheme.primaryWhite),
          onPressed: () {
            // TODO: Share product
          },
        ),
      ],
    );
  }

  Widget _buildProductImages() {
    final images = _product?['images'] as List<dynamic>? ?? [];

    return Container(
      height: 300,
      color: AppTheme.primaryWhite,
      child: Column(
        children: [
          // Main Image
          Expanded(
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imgEntry = images[index];
                return Container(
                  margin: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: buildProductImageWidget(
                      imgEntry,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          // Image Indicators
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    images.asMap().entries.map((entry) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _currentImageIndex == entry.key
                                  ? AppTheme.primaryColor
                                  : Colors.grey[300],
                        ),
                      );
                    }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    final price = _product?['price']?.toDouble() ?? 0.0;
    final salePrice = _product?['salePrice']?.toDouble() ?? 0.0;
    final hasDiscount = salePrice > 0 && salePrice < price;
    final stock = _product?['stock'] ?? 0;
    final favoriteCount = _product?['favoriteCount'] ?? 0;
    final sold = _product?['sold'] ?? 0;
    final statusLabel = _product?['status']?['label'] ?? '';

    return Container(
      color: AppTheme.primaryWhite,
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name with Favorite Button
          Row(
            children: [
              Expanded(
                child: Text(
                  _product?['name'] ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                    height: 1.3,
                  ),
                ),
              ),
              // Favorite count (moved) and Favorite Button
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '(ขายไปแล้ว $sold ชิ้น)',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isFavoriteLoading ? null : _toggleFavorite,
                icon:
                    _isFavoriteLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color:
                              _isFavorite
                                  ? AppTheme.errorColor
                                  : AppTheme.textSecondaryColor,
                          size: 28,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Badge and Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              if (statusLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_product?['status']?['name'] ?? ''),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              // Price Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasDiscount) ...[
                      Text(
                        '฿${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondaryColor,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '฿${salePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${(((price - salePrice) / price) * 100).round()}%',
                              style: const TextStyle(
                                color: AppTheme.primaryWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '฿${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Product Details in Cards
          Row(
            children: [
              // Stock Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory, size: 20, color: Colors.blue[600]),
                      const SizedBox(height: 4),
                      Text(
                        'คงเหลือ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$stock ชิ้น',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Favorites Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.favorite, size: 20, color: Colors.red[600]),
                      const SizedBox(height: 4),
                      Text(
                        'ถูกใจแล้ว',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$favoriteCount คน',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Size Card (if available)
              if (_product?['size'] != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 20,
                          color: Colors.green[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ขนาด (ซม.)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_product?['size']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDescription() {
    final description = _product?['description'] ?? '';

    return Container(
      color: AppTheme.primaryWhite,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายละเอียดสินค้า',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
                height: 1.6,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      color: AppTheme.primaryWhite,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รีวิวสินค้า (${_reviews.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              if (_reviews.length > 3)
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all reviews
                  },
                  child: Text(
                    'ดูทั้งหมด',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingReviews)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ยังไม่มีรีวิวสำหรับสินค้านี้',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เป็นคนแรกที่รีวิวสินค้านี้!',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children:
                  _reviews
                      .take(3)
                      .map((review) => _buildReviewItem(review))
                      .toList(),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';
    final reviewerName =
        review['reviewerName'] ?? review['reviewer_name'] ?? '';
    final createdAt = review['createdAt'] ?? review['created_at'] ?? '';
    final productOption =
        review['productOption'] ??
        review['product_option'] ??
        review['productOptionId'] ??
        null;

    String dateLabel = '';
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      try {
        dateLabel = _formatDate(createdAt.toString());
      } catch (_) {
        dateLabel = createdAt.toString();
      }
    }

    String optionLabel = '';
    if (productOption != null) {
      if (productOption is Map) {
        final type =
            (productOption['type'] ?? productOption['optionType'] ?? '')
                .toString();
        final value =
            (productOption['value'] ??
                    productOption['label'] ??
                    productOption['name'] ??
                    '')
                .toString();
        final typeLabel = type.isNotEmpty ? _getOptionTypeLabel(type) : '';
        optionLabel = typeLabel.isNotEmpty ? '$typeLabel: $value' : value;
      } else {
        optionLabel = productOption.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer and date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  reviewerName.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              if (dateLabel.isNotEmpty)
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Rating stars
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                );
              }),
              const SizedBox(width: 8),
              Text(
                '$rating ดาว',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),

          if (optionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              optionLabel,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _showAddToCartModal(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.primaryWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'เพิ่มลงตะกร้า',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String statusName) {
    return AppTheme.getStatusColor(statusName);
  }

  void _showAddToCartModal() {
    int modalQuantity = 1;
    List<int> selectedOptionIds = [];
    List<Map<String, dynamic>> modalSelectedOptions = [];

    // Initialize with current selections
    final options = _product?['options'] as List<dynamic>? ?? [];

    // Group options by type
    Map<String, List<Map<String, dynamic>>> groupedOptions = {};
    for (var option in options) {
      String type = option['type'] ?? 'OTHER';
      if (!groupedOptions.containsKey(type)) {
        groupedOptions[type] = [];
      }
      groupedOptions[type]!.add(Map<String, dynamic>.from(option));
    }

    // Initialize selected options (one per type, prefer options with stock)
    for (var entry in groupedOptions.entries) {
      if (entry.value.isNotEmpty) {
        // Try to find an option with stock first
        var optionWithStock = entry.value.firstWhere(
          (option) => (option['stock'] ?? 0) > 0,
          orElse: () => entry.value[0], // fallback to first option
        );
        selectedOptionIds.add(optionWithStock['id']);
        modalSelectedOptions.add(optionWithStock);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildProductImageWidget(
                            ((_product?['images'] as List?)?.isNotEmpty == true
                                ? _product!['images'][0]['url']
                                : null),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _product?['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '฿${(_product?['salePrice'] ?? _product?['price'] ?? 0).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Options
                  if (groupedOptions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            groupedOptions.entries.map((entry) {
                              String optionType = entry.key;
                              List<Map<String, dynamic>> optionsList =
                                  entry.value;

                              // Find currently selected option for this type
                              var selectedOption = modalSelectedOptions
                                  .firstWhere(
                                    (opt) => opt['type'] == optionType,
                                    orElse: () => optionsList[0],
                                  );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getOptionTypeLabel(optionType),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GridView.count(
                                    crossAxisCount: 3,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 2.5,
                                    children:
                                        optionsList.map((option) {
                                          bool isSelected =
                                              selectedOption['id'] ==
                                              option['id'];
                                          int optionStock =
                                              option['stock'] ?? 0;
                                          String optionText =
                                              '${option['value'] ?? ''}${optionStock > 0 ? ' ($optionStock)' : ' (0)'}';
                                          bool isOutOfStock = optionStock <= 0;

                                          return GestureDetector(
                                            onTap:
                                                isOutOfStock
                                                    ? null
                                                    : () {
                                                      setModalState(() {
                                                        // Remove old option of this type
                                                        selectedOptionIds
                                                            .removeWhere((id) {
                                                              var opt = options
                                                                  .firstWhere(
                                                                    (o) =>
                                                                        o['id'] ==
                                                                        id,
                                                                    orElse:
                                                                        () =>
                                                                            null,
                                                                  );
                                                              return opt !=
                                                                      null &&
                                                                  opt['type'] ==
                                                                      optionType;
                                                            });
                                                        modalSelectedOptions
                                                            .removeWhere(
                                                              (opt) =>
                                                                  opt['type'] ==
                                                                  optionType,
                                                            );

                                                        // Add new option
                                                        selectedOptionIds.add(
                                                          option['id'],
                                                        );
                                                        modalSelectedOptions
                                                            .add(option);
                                                      });
                                                    },
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isOutOfStock
                                                        ? Colors.grey[100]
                                                        : isSelected
                                                        ? AppTheme.primaryColor
                                                        : Colors.transparent,
                                                border: Border.all(
                                                  color:
                                                      isOutOfStock
                                                          ? Colors.grey[300]!
                                                          : isSelected
                                                          ? AppTheme
                                                              .primaryColor
                                                          : Colors.grey[300]!,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                optionText,
                                                style: TextStyle(
                                                  color:
                                                      isOutOfStock
                                                          ? Colors.grey[500]
                                                          : isSelected
                                                          ? AppTheme
                                                              .primaryWhite
                                                          : AppTheme
                                                              .textPrimaryColor,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  decoration:
                                                      isOutOfStock
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }).toList(),
                      ),
                    ),

                  // Quantity
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'จำนวน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed:
                                        modalQuantity > 1
                                            ? () {
                                              setModalState(() {
                                                modalQuantity--;
                                              });
                                            }
                                            : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text(
                                    '$modalQuantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setModalState(() {
                                        modalQuantity++;
                                      });
                                    },
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'คงเหลือ ${_product?['stock'] ?? 0} ชิ้น',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Add to Cart Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isAddingToCart
                                ? null
                                : () async {
                                  // Check if selected options have stock
                                  bool hasOutOfStockOption = false;
                                  String outOfStockOptionName = '';

                                  for (var selectedOption
                                      in modalSelectedOptions) {
                                    int stock = selectedOption['stock'] ?? 0;
                                    if (stock <= 0) {
                                      hasOutOfStockOption = true;
                                      outOfStockOptionName =
                                          selectedOption['value'] ?? '';
                                      break;
                                    }
                                  }

                                  if (hasOutOfStockOption) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'ตัวเลือก "$outOfStockOptionName" หมดสต็อก กรุณาเลือกตัวเลือกอื่น',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(context);
                                  await _addToCart(
                                    modalQuantity,
                                    selectedOptionIds,
                                  );
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.primaryWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isAddingToCart
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryWhite,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'เพิ่มลงตะกร้า ($modalQuantity ชิ้น)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ),

                  // Bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getOptionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'color':
        return 'สี';
      case 'size':
        return 'ขนาด';
      case 'material':
        return 'วัสดุ';
      default:
        return type;
    }
  }

  Future<void> _addToCart(int quantity, List<int> optionIds) async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Get user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Try to get user_id as int first, then as string
      int? accountId = prefs.getInt('user_id');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      if (accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มสินค้าลงตะกร้า'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final body = {
        "accountId": accountId,
        "productId": widget.productId,
        "quantity": quantity,
        "optionIds": optionIds,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.addToCart),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 201 || data['status'] == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['msg'] ?? 'เพิ่มสินค้าลงตะกร้าสำเร็จ'),
                backgroundColor: Colors.green,
                // action: SnackBarAction(
                //   label: 'ดูตะกร้า',
                //   textColor: AppTheme.primaryWhite,
                //   onPressed: () {
                //     // TODO: Navigate to cart screen
                //   },
                // ),
              ),
            );
            // Refresh provider-backed cart count
            try {
              await Provider.of<CartNotifier>(
                context,
                listen: false,
              ).loadCount();
            } catch (e) {
              // ignore provider errors
            }
          }
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถเพิ่มสินค้าลงตะกร้าได้');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() {
      _isAddingToCart = false;
    });
  }
}
