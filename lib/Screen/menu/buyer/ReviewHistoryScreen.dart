import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({super.key});

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _loadAccountId();
  }

  Future<void> _loadAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    _accountId = prefs.getInt('user_id');
    if (_accountId == null) {
      final userIdString = prefs.getString('user_id');
      if (userIdString != null && userIdString.isNotEmpty) {
        _accountId = int.tryParse(userIdString);
      }
    }

    if (_accountId != null) {
      await _loadReviewHistory();
    }
  }

  Future<void> _loadReviewHistory() async {
    if (_accountId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final headers = await ApiConfig.buildHeaders();

      final requestBody = {
        'accountId': _accountId,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.reviewHistory),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
            _stats = data['stats'];
            _isLoading = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลรีวิวได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildStatsCard() {
    if (_stats == null) return Container();

    final totalReviews = _stats!['totalReviews'] ?? 0;
    final averageRating = (_stats!['averageRating'] ?? 0.0).toDouble();
    final ratingDistribution = _stats!['ratingDistribution'] ?? {};

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สถิติรีวิวของคุณ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$totalReviews',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        'รีวิวทั้งหมด',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ],
                      ),
                      Text(
                        'คะแนนเฉลี่ย',
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
            const SizedBox(height: 8),
            const Text(
              'การกระจายคะแนน',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(5, (index) {
              final star = 5 - index;
              final count = ratingDistribution['star$star'] ?? 0;
              final percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '$star',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final product = review['product'] ?? {};
    final order = review['order'] ?? {};
    final rating = (review['rating'] ?? 0) as int;
    final comment = review['comment'] ?? '';
    final createdAt = review['createdAt'] ?? '';
    
    final images = List<Map<String, dynamic>>.from(product['images'] ?? []);
    final imageUrl = images.isNotEmpty ? images[0]['url'] : '';
    final category = product['category'] ?? {};
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Info with Image
            Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? buildProductImageWidget(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      Text(
                        category['name'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '฿${product['salePrice']?.toString() ?? '0'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          if (product['price'] != product['salePrice']) ...[
                            const SizedBox(width: 8),
                            Text(
                              '฿${product['price']?.toString() ?? '0'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Review Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'คะแนน: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 18,
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      '($rating/5)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Order Info
            Row(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'คำสั่งซื้อ #${order['id']} • ${_formatDate(order['createdAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'รีวิวของฉัน',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.primaryWhite,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _loadReviewHistory(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.primaryWhite,
                        ),
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'ยังไม่มีรีวิว',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เมื่อคุณรีวิวสินค้า\nรีวิวจะแสดงที่นี่',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Stats Card
                        _buildStatsCard(),
                        
                        // Reviews List
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadReviewHistory,
                            child: ListView.builder(
                              itemCount: _reviews.length,
                              itemBuilder: (context, index) {
                                return _buildReviewCard(_reviews[index]);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
