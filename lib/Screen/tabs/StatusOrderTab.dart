import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/Screen/order/OrderDetailScreen.dart';
import 'package:rps_app/widgets/order_card_widget.dart';

class StatusOrderTab extends StatefulWidget {
  final bool active;
  const StatusOrderTab({super.key, this.active = false});

  @override
  State<StatusOrderTab> createState() => _StatusOrderTabState();
}

class _StatusOrderTabState extends State<StatusOrderTab> {
  Future<void> _refreshOrders() async {
    await _loadOrders(_selectedStatus);
  }
  String _selectedStatus = 'verifying';
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;
  int? _accountId;
  List<String>? _filterStatusLabels;
  // pagination
  int _page = 1;
  final int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
  _scrollController = ScrollController();
  _scrollController.addListener(_onScroll);
  // Check auth/account and load orders appropriately
  _checkAuthAndRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check auth in case something changed while widget was inactive
    _checkAuthAndRefresh();
  }

  @override
  void didUpdateWidget(covariant StatusOrderTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If active flag changed (e.g., user switched tabs), re-check auth and reload
    if (widget.active != oldWidget.active) {
      _checkAuthAndRefresh();
    }
  }

  // _loadAccountId removed; use _checkAuthAndRefresh which reads SharedPreferences

  Future<int?> _getAccountIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    int? id = prefs.getInt('user_id');
    if (id == null) {
      final s = prefs.getString('user_id');
      if (s != null && s.isNotEmpty) id = int.tryParse(s);
    }
    return id;
  }

  Future<void> _checkAuthAndRefresh() async {
    if (!mounted) return;
    final int? newAccountId = await _getAccountIdFromPrefs();

    // If account changed (login/logout or switch), update state
    if (newAccountId != _accountId) {
      _accountId = newAccountId;
      // If logged out, clear orders
      if (_accountId == null) {
        if (mounted) {
          setState(() {
            _orders = [];
            _filterStatusLabels = null;
            _error = null;
            _isLoading = false;
            _isLoadingMore = false;
            _page = 1;
            _hasMore = true;
          });
        }
      } else {
        // If logged in, load orders for current selected status
        await _loadOrders(_selectedStatus);
      }
      return;
    }

    // If account hasn't changed but the tab became active, and we have no orders, try loading
    if (widget.active && _accountId != null && _orders.isEmpty && !_isLoading) {
      await _loadOrders(_selectedStatus);
    }
  }

  Future<void> _loadOrders(String statusName) async {
    if (_accountId == null || !mounted) return;

    if (statusName != _selectedStatus) {
      // when switching status, reset paging
      _page = 1;
      _hasMore = true;
    }

    setState(() {
      _selectedStatus = statusName;
    });

    // default load (not loadMore)
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final headers = await ApiConfig.buildHeaders();

      // Determine which status names to send based on the selected status
      List<String> statusNames;
      if (statusName == 'verifying') {
        // For "รอตรวจสอบ" icon, send both pending and verifying
        statusNames = ['pending', 'verifying'];
      } else {
        // For other statuses, send as single item array
        statusNames = [statusName];
      }

      final requestBody = {'accountId': _accountId, 'statusNames': statusNames, 'page': _page, 'pageSize': _pageSize};

      final response = await http.post(
        Uri.parse(ApiConfig.listOrderBuyer),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final List<Map<String, dynamic>> newItems = List<Map<String, dynamic>>.from(data['orders'] ?? []);
          final int serverPage = data['page'] ?? _page;
          final int? totalPages = data['totalPages'];

          setState(() {
            if (_page == 1) {
              _orders = newItems;
            } else {
              _orders.addAll(newItems);
            }

            _filterStatusLabels = List<String>.from(data['filterInfo']?['statuses'] ?? []);

            if (totalPages != null) {
              _hasMore = serverPage < totalPages;
            } else {
              _hasMore = newItems.length >= _pageSize;
            }

            _isLoading = false;
            _isLoadingMore = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลออเดอร์ได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (_page > 1) _page = _page - 1;
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    const threshold = 200; // px before reaching bottom to prefetch
    final pos = _scrollController.position;
    if (pos.pixels + threshold >= pos.maxScrollExtent) {
      // load next page
      setState(() { _isLoadingMore = true; _page += 1; });
      _loadOrders(_selectedStatus);
    }
  }

  Widget _buildStatusIcon(
    String status,
    IconData icon,
    String label,
    Color color,
  ) {
    final isSelected = _selectedStatus == status;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // If user not logged in, prompt to login via Snackbar
          if (_accountId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กรุณาเข้าสู่ระบบเพื่อดูคำสั่งซื้อ'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Otherwise load orders for the selected status
          _loadOrders(status);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? color : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildOrderCard(Map<String, dynamic> order) {
    return OrderCardWidget(
      order: order,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(order: order),
          ),
        );

        if (mounted && result != null && result['refresh'] == true) {
          _loadOrders(_selectedStatus);
        }
      },
    );
  }
  



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
          localizations?.order ?? 'สถานะออเดอร์',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Status Icons Row
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _buildStatusIcon(
                  'verifying',
                  Icons.verified_user,
                  'รอตรวจสอบ',
                  AppTheme.getStatusColor('verifying'),
                ),
                _buildStatusIcon(
                  'preparing',
                  Icons.inventory,
                  'เตรียมสินค้า',
                  AppTheme.getStatusColor('preparing'),
                ),
                _buildStatusIcon(
                  'shipping',
                  Icons.local_shipping,
                  'จัดส่ง\n',
                  AppTheme.getStatusColor('shipping'),
                ),
                _buildStatusIcon(
                  'completed',
                  Icons.check_circle,
                  'สำเร็จ\n',
                  AppTheme.getStatusColor('completed'),
                ),
                _buildStatusIcon(
                  'canceled',
                  Icons.cancel,
                  'ยกเลิก\n',
                  AppTheme.getStatusColor('canceled'),
                ),
              ],
            ),
          ),

          // Filter Info
          if (_filterStatusLabels != null && _filterStatusLabels!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Text(
                'สถานะ: ${_filterStatusLabels!.join(', ')}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),

          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshOrders,
              color: AppTheme.primaryColor,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      children: [
                        SizedBox(height: 100),
                        Center(
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
                                onPressed: () => _loadOrders(_selectedStatus),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.primaryWhite,
                                ),
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _orders.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.assignment,
                                size: 80,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'ไม่มีออเดอร์ในสถานะนี้',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _orders.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _orders.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _buildOrderCard(_orders[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
