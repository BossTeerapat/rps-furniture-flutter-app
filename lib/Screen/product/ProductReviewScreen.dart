import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Service/API_Config.dart';
import '../../widgets/image_helper.dart';
import '../../theme/app_theme.dart';

class ProductReviewScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const ProductReviewScreen({super.key, required this.order});

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  // Keyed by '${productId}_${productOptionId ?? 0}' so same product with
  // different options have separate review state.
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _includeReviewerName = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {

    final items = widget.order['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final product = item['product'] ?? {};
      final productId = product['id'] as int;
      final opt = _getProductOptionFromItem(item as Map<String, dynamic>);
      final productOptionId = opt != null && opt['id'] != null ? opt['id'].toString() : '0';
      final key = '${productId}_$productOptionId';
      _ratings[key] = 5; // Default rating
      _commentControllers[key] = TextEditingController();
      // default to showing reviewer name
      _includeReviewerName[key] = true;
    }
  }

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Try to extract a product option id and a human label from an order item.
  // Supports many possible shapes from different APIs.
  Map<String, dynamic>? _getProductOptionFromItem(Map<String, dynamic> item) {

    // 1) direct keys that may be scalar id or nested map
    final directKeys = ['productOptionId', 'product_option_id', 'optionId', 'selectedOptionId', 'productOption', 'product_option', 'option'];
    for (var key in directKeys) {
      if (item.containsKey(key) && item[key] != null) {
        final val = item[key];
        if (val is Map) {
          final id = val['id'] ?? val['productOptionId'] ?? val['product_option_id'] ?? val['optionId'];
          final label = val['label'] ?? val['value'] ?? val['name'] ?? val['title'];
          final type = val['type'] ?? val['productOption']?['type'] ?? val['optionType'];
          return {
            'id': id ?? val,
            'label': (label ?? id ?? val).toString(),
            'type': type?.toString() ?? '',
          };
        } else {
          return {'id': val, 'label': val.toString()};
        }
      }
    }

    // 2) selectedOptions / options arrays
    final listKeys = ['selectedOptions', 'selected_options', 'options', 'productOptions', 'product_options'];
    for (var key in listKeys) {
      if (item.containsKey(key) && item[key] != null) {
        final val = item[key];
        if (val is List && val.isNotEmpty) {
          final first = val[0];
            if (first is Map) {
            final id = first['id'] ?? first['productOptionId'] ?? first['optionId'];
            final label = first['label'] ?? first['value'] ?? first['name'] ?? first['title'];
            final type = first['type'] ?? first['productOption']?['type'] ?? first['optionType'];
            return {'id': id ?? first, 'label': (label ?? id ?? first).toString(), 'type': type?.toString() ?? ''};
          } else {
            return {'id': first, 'label': first.toString()};
          }
        } else if (val is Map) {
          final id = val['id'] ?? val['productOptionId'] ?? val['optionId'];
          final label = val['label'] ?? val['value'] ?? val['name'];
          final type = val['type'] ?? val['productOption']?['type'] ?? val['optionType'];
          return {'id': id ?? val, 'label': (label ?? id ?? val).toString(), 'type': type?.toString() ?? ''};
        }
      }
    }

    return null;
  }

  Future<void> _submitReviews() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getInt('user_id');
      if (accountId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
      }

      final headers = await ApiConfig.buildHeaders();
      final items = widget.order['items'] as List<dynamic>? ?? [];

      // Build reviews array according to new API structure
      List<Map<String, dynamic>> reviews = [];

      for (var item in items) {
        final product = item['product'] ?? {};
        final productId = product['id'] as int;
        final opt = _getProductOptionFromItem(item as Map<String, dynamic>);
        final productOptionId = opt != null ? opt['id'] : null;
        final key = '${productId}_${productOptionId ?? 0}';
        final rating = _ratings[key] ?? 5;
        final comment = _commentControllers[key]?.text.trim() ?? '';
        // user selection: show name if switch true, hide if false
        final includeName = _includeReviewerName[key] ?? true;

        // Send `anonymous` boolean (true = hide name) as requested
        Map<String, dynamic> review = {
          'productId': productId,
          'rating': rating,
          'anonymous': !(includeName),
        };

        if (productOptionId != null) {
          review['productOptionId'] = productOptionId;
        }

        // Only add comment if it's not empty after trimming
        if (comment.isNotEmpty) {
          review['comment'] = comment;
        }

        reviews.add(review);
      }
      final requestBody = {
        'accountId': accountId,
        'orderId': widget.order['id'],
        'reviews': reviews,
      };

      try {

        print('POST ${ApiConfig.postReview} body: ${jsonEncode(requestBody)}');

        final response = await http.post(
          Uri.parse(ApiConfig.postReview),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        print('POST ${ApiConfig.postReview} response: ${response.statusCode} ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['status'] == 200 || data['status'] == 201) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ส่งรีวิวสำเร็จทุกรายการ'),
                  backgroundColor: Colors.green,
                ),
              );
              // Pop twice to go back to StatusOrderTab and refresh
              Navigator.of(
                context,
              ).pop(); // First pop - from ProductReviewScreen
              Navigator.of(context).pop({
                'refresh': true,
              }); // Second pop - from OrderDetailScreen with refresh signal
            }
          } else {
            throw Exception(data['msg'] ?? 'เกิดข้อผิดพลาด');
          }
        } else {
          throw Exception(
            'เกิดข้อผิดพลาดในการเชื่อมต่อ (${response.statusCode})',
          );
        }
      } catch (e) {
        throw Exception('เกิดข้อผิดพลาด: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildStarRating(String key, int currentRating) {
    return Row(
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _ratings[key] = index + 1;
            });
          },
          child: Icon(
            index < currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 30,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'รีวิวสินค้า',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body:
          items.isEmpty
              ? const Center(
                child: Text(
                  'ไม่พบสินค้าในคำสั่งซื้อ',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : Column(
                children: [
                  // Order Info Header
                  Container(
                    width: double.infinity,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คำสั่งซื้อ #${widget.order['id']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'กรุณาให้คะแนนและแสดงความคิดเห็นเกี่ยวกับสินค้า',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Products List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = item['product'] ?? {};
                        final productId = product['id'] as int;
                        final optForKey = _getProductOptionFromItem(item as Map<String, dynamic>);
                        final key = '${productId}_${optForKey != null && optForKey['id'] != null ? optForKey['id'] : 0}';
                        final currentRating = _ratings[key] ?? 5;
                        final images = List<Map<String, dynamic>>.from(
                          product['images'] ?? [],
                        );
                        final imageUrl =
                            images.isNotEmpty ? images[0]['url'] : '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Info
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child:
                                          imageUrl.isNotEmpty
                                              ? buildProductImageWidget(
                                                imageUrl,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              )
                                              : Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // show selected product option (if available)
                                          Builder(builder: (ctx) {
                                            final opt = _getProductOptionFromItem(item);
                                            if (opt != null && (opt['label'] ?? '').toString().isNotEmpty) {
                                              final type = (opt['type'] ?? '').toString().trim();
                                              final label = opt['label'].toString();
                                              final display = type.isNotEmpty ? '$type: $label' : label;
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  display,
                                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          }),
                                          const SizedBox(height: 4),
                                          Text(
                                            'จำนวน: ${item['quantity']} ชิ้น',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),

                                // Rating
                                const Text(
                                  'ให้คะแนน',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildStarRating(key, currentRating),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$currentRating ดาว',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Comment
                                const Text(
                                  'แสดงความคิดเห็น (ไม่บังคับ)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentControllers[key],
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'แบ่งปันประสบการณ์การใช้สินค้านี้...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                                    Row(
                                  children: [
                                    Switch(
                                      value: _includeReviewerName[key] ?? true,
                                      onChanged: (val) {
                                        setState(() {
                                          _includeReviewerName[key] = val;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('แสดงชื่อผู้รีวิว', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Submit Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReviews,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isSubmitting
                                ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'กำลังส่งรีวิว...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                                : const Text(
                                  'ส่งรีวิว',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
