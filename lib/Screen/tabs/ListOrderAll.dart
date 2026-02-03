import 'package:flutter/material.dart';
import 'package:rps_app/Screen/order/OrderDetailScreen.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
// ...existing code...
import 'package:rps_app/widgets/order_card_widget.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ListOrderAll extends StatefulWidget {
  const ListOrderAll({super.key});

  @override
  State<ListOrderAll> createState() => _ListOrderAllState();
}

class _ListOrderAllState extends State<ListOrderAll> {
  
  Future<void> _refreshOrders() async {
    await _loadOrders(_selectedAction);
  }

  String _selectedAction = 'verifying'; // Default action: show 'ตรวจสอบ' first
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _role;
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
  _loadRole();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role');
    });
    if (_role == 'admin') {
      _loadOrders(_selectedAction);
    } else if (_role == 'employee') {
      // default: load preparing, shipping, completed, canceled only
      _selectedAction = 'preparing';
      _loadOrders(_selectedAction);
    }
  }

  Future<void> _loadOrders(String action, {bool loadMore = false}) async {
    if (!mounted) return;
    if (loadMore) {
      if (_isLoadingMore || !_hasMore || _isLoading) return;
      setState(() { _isLoadingMore = true; });
      _page += 1;
    } else {
      setState(() { _isLoading = true; });
      _page = 1;
      _hasMore = true;
    }

  // scroll controller is initialized in initState

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listOrderAll),
        headers: headers,
        body: jsonEncode({'action': action, 'page': _page, 'pageSize': _pageSize}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200 && data['orders'] != null) {
          final List<Map<String, dynamic>> newItems = List<Map<String, dynamic>>.from(data['orders']);
          final int serverPage = data['page'] ?? _page;
          final int? totalPages = data['totalPages'];

          if (mounted) {
            setState(() {
              if (loadMore) {
                _orders.addAll(newItems);
              } else {
                _orders = newItems;
              }

              if (totalPages != null) {
                _hasMore = serverPage < totalPages;
              } else {
                _hasMore = newItems.length >= _pageSize;
              }
            });
          }
        } else {
          throw Exception(data['msg'] ?? 'Failed to load orders');
        }
      } else {
        throw Exception('Failed to connect to server');
      }
    } catch (e) {
      if (loadMore) _page = (_page > 1) ? _page - 1 : 1;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
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
      _loadOrders(_selectedAction, loadMore: true);
    }
  }

  Widget _buildActionIcons() {
    final actions =
        _role == 'employee'
            ? {
              'preparing': Icons.build,
              'shipping': Icons.local_shipping,
              'completed': Icons.check_circle,
              'canceled': Icons.cancel,
            }
            : {
              'pending': Icons.hourglass_empty,
              'verifying': Icons.verified,
              'preparing': Icons.build,
              'shipping': Icons.local_shipping,
              'completed': Icons.check_circle,
              'canceled': Icons.cancel,
            };
    final labels = {
      'pending': 'รอชำระเงิน',
      'verifying': 'ตรวจสอบ',
      'preparing': 'เตรียมสินค้า',
      'shipping': 'กำลังจัดส่ง',
      'completed': 'เสร็จสิ้น',
      'canceled': 'ยกเลิก',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            actions.entries.map((entry) {
              final action = entry.key;
              final icon = entry.value;
              final label = labels[action] ?? action;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () {
                    if (_role == 'employee' &&
                        (action == 'pending' || action == 'verifying')) {
                      // Do nothing for employee on pending/verifying
                      return;
                    }
                    setState(() {
                      _selectedAction = action;
                    });
                    _loadOrders(action);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: _selectedAction == action ? AppTheme.primaryColor : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: _selectedAction == action ? AppTheme.primaryColor : Colors.grey,
                          fontSize: 12,
                          fontWeight: _selectedAction == action ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('ไม่มีคำสั่งซื้อในสถานะนี้'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _orders.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final order = _orders[index];
  // items and totals are handled inside OrderCardWidget

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
              _loadOrders(_selectedAction);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        title: Text(
          localizations?.order ?? 'คำสั่งซื้อ',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildActionIcons(), // Action icons row
          const Divider(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshOrders,
              color: AppTheme.primaryColor,
              child: _buildOrderList(),
            ),
          ), // Order list
        ],
      ),
    );
  }
}
