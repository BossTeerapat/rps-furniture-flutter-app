import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/Screen/order/OrderDetailScreen.dart';
import 'package:rps_app/widgets/image_helper.dart';

class HistoryOrderScreen extends StatefulWidget {
  final bool employeeMode;
  final int? employeeId;
  const HistoryOrderScreen({super.key, this.employeeMode = false, this.employeeId});

  @override
  State<HistoryOrderScreen> createState() => _HistoryOrderScreenState();
}

class _HistoryOrderScreenState extends State<HistoryOrderScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;
  int? _accountId;
  // pagination
  int _page = 1;
  int _pageSize = 10;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadAccountId();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;
    final thresholdPixels = 200.0; // start loading before reaching the end
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll - current <= thresholdPixels) {
      // try load next page
      _loadHistoryOrders(loadMore: true);
    }
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

    // If on employee mode and employeeId was passed via widget, prefer that
    if (widget.employeeMode && widget.employeeId != null) {
      _accountId = widget.employeeId; // reuse _accountId as the id to query
    }

    if (_accountId != null) {
      // initialize pagination
      _page = 1;
      _hasMore = true;
      _totalPages = 1;
      await _loadHistoryOrders();
    }
  }

  Future<void> _loadHistoryOrders({bool loadMore = false}) async {
    if (_accountId == null) return;

    if (loadMore) {
      if (!_hasMore) return;
      _isLoadingMore = true;
      _page += 1;
    } else {
      // refresh or initial load
      _page = 1;
      _hasMore = true;
      _totalPages = 1;
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final headers = await ApiConfig.buildHeaders();

      if (widget.employeeMode) {
        final requestBody = {'employeeId': _accountId, 'page': _page, 'pageSize': _pageSize};
        final response = await http.post(Uri.parse(ApiConfig.employeeOrders), headers: headers, body: jsonEncode(requestBody));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['items'] ?? [];
          final int respPage = data['page'] is int ? data['page'] as int : (data['page'] is String ? int.tryParse(data['page']) ?? _page : _page);
          final dynamic totalPagesRaw = data['totalPages'];
          final int? respTotalPages = totalPagesRaw is int ? totalPagesRaw : (totalPagesRaw is String ? int.tryParse(totalPagesRaw) : null);
          setState(() {
            if (loadMore) {
              _orders.addAll(List<Map<String, dynamic>>.from(items as List<dynamic>));
            } else {
              _orders = List<Map<String, dynamic>>.from(items as List<dynamic>);
            }
            _isLoading = false;
            _isLoadingMore = false;
            _page = respPage;
            if (respTotalPages != null) {
              _totalPages = respTotalPages;
              _hasMore = _page < _totalPages;
            } else {
              // fallback: if server didn't provide totalPages, decide by items length
              _hasMore = List.from(items).length >= _pageSize;
            }
          });
        } else {
          throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
        }
      } else {
        final requestBody = {
          'accountId': _accountId,
          'statusNames': ['success']
        };

        final response = await http.post(
          Uri.parse(ApiConfig.listOrderBuyer),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 200) {
            setState(() {
              _orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
              _isLoading = false;
            });
          } else {
            throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลประวัติการสั่งซื้อได้');
          }
        } else {
          throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> order) {
    final shippingPrice = (order['shippingPrice'] ?? 0).toDouble();
    final createdAt = order['createdAt'] ?? '';
    final paymentType = order['paymentType'] ?? {};
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    // Calculate actual total and quantity
    int totalQuantity = 0;
    double actualTotal = 0;
    for (var item in items) {
      final quantity = (item['quantity'] ?? 0) as int;
      final price = (item['price'] ?? 0).toDouble();
      totalQuantity += quantity;
      actualTotal += (price * quantity);
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(order: order),
          ),
        );

        if (mounted && result != null && result['refresh'] == true) {
          _loadHistoryOrders();
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'คำสั่งซื้อ #${order['id']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order['status']?['label'] ?? 'สำเร็จ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Order Date and Payment Type
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'วันที่: ${_formatDate(createdAt)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        paymentType['name'] == 'QR' ? Icons.qr_code : Icons.money,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paymentType['label'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Products List (show first 2 items)
              ...items.take(2).map((item) {
                final product = item['product'] ?? {};
                final quantity = item['quantity'] ?? 0;
                final price = (item['price'] ?? 0).toDouble();
                final images = (product['images'] ?? []) as List<dynamic>;
                final dynamic imageEntry = images.isNotEmpty ? images[0] : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                              child: imageEntry != null
                              ? buildProductImageWidget(imageEntry, width: 50, height: 50, fit: BoxFit.cover)
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 20,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'จำนวน: $quantity ชิ้น',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Item Total
                      Text(
                        '฿${(price * quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Show more items indicator
              if (items.length > 2)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'และอีก ${items.length - 2} รายการ...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const Divider(height: 16),

              // Summary Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รวม $totalQuantity ชิ้น (${items.length} รายการ)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (shippingPrice > 0) ...[
                        Text(
                          'ค่าจัดส่ง: ฿${shippingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        'รวมทั้งสิ้น: ฿${(actualTotal + shippingPrice).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
        title: Text(
          widget.employeeMode ? 'ประวัติการส่งของ' : 'ประวัติการสั่งซื้อ',
          style: const TextStyle(
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
      body: Column(
        children: [
          // Header Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.employeeMode ? 'รายการที่นำส่งสำเร็จ' : 'คำสั่งซื้อที่สำเร็จแล้ว',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                if (!_isLoading)
                  Text(
                    '${_orders.length} รายการ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
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
                              onPressed: () => _loadHistoryOrders(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: AppTheme.primaryWhite,
                              ),
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'ยังไม่มีประวัติการสั่งซื้อ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'เมื่อคุณซื้อสินค้าและได้รับสินค้าแล้ว\nประวัติจะแสดงที่นี่',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHistoryOrders,
                            child: ListView.builder(
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryCard(_orders[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
