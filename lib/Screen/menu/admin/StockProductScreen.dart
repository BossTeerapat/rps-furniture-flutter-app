import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/widgets/image_helper.dart';

class StockProductScreen extends StatefulWidget {
  const StockProductScreen({super.key});

  @override
  State<StockProductScreen> createState() => _StockProductScreenState();
}

class _StockProductScreenState extends State<StockProductScreen> {
  String _action = 'minstock';
  bool _isLoading = true;
  String? _error;
  int _count = 10;
  List<dynamic> _products = [];
  // pagination
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // track expanded product ids (or indices)
  final Set<int> _expanded = {};
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadProducts();
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
      _loadProducts(loadMore: true);
    }
  }

  // Inline expansion: show compact options directly beneath the card when tapped
  Widget _buildExpandedOptions(Map<String, dynamic> p) {
    final options = (p['options'] as List<dynamic>?) ?? [];
    final screenW = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ตัวเลือก',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('ไม่มีตัวเลือก'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map<Widget>((o) {
                final type = (o['type'] ?? '') as String;
                final value = (o['value'] ?? '') as String;
                final label = type != '' ? '$type: $value' : value;
                final stock = o['stock'] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  constraints: BoxConstraints(minWidth: 80, maxWidth: screenW - 140),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: stock > 0 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: stock > 0 ? Colors.green[800] : Colors.red[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
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
        _error = null;
      });
      _page = 1;
      _hasMore = true;
      _expanded.clear();
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.stockProduct),
        headers: headers,
        body: jsonEncode({'action': _action, 'page': _page, 'pageSize': _pageSize}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> newItems = List<dynamic>.from(data['products'] ?? []);
        final int serverPage = data['page'] ?? _page;
        final int? totalPages = data['totalPages'];

        setState(() {
          _count = data['count'] ?? _count;
          if (loadMore) {
            _products.addAll(newItems);
          } else {
            _products = newItems;
          }

          if (totalPages != null) {
            _hasMore = serverPage < totalPages;
          } else {
            _hasMore = newItems.length >= _pageSize;
          }

          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        if (loadMore) _page = (_page > 1) ? _page - 1 : 1;
        setState(() {
          _error = 'ไม่สามารถโหลดข้อมูลได้';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (loadMore) _page = (_page > 1) ? _page - 1 : 1;
      setState(() {
        _error = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildProductCard(Map<String, dynamic> p, int index) {
    final images = p['imageUrl'] ?? '';
    final isExpanded = _expanded.contains(index);
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            });
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  buildProductImageWidget(
                    images,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('สต๊อกรวม: ${p['stock'] ?? 0}'),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
        // expanded panel
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isExpanded ? _buildExpandedOptions(p) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คลังสินค้า'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_action != 'minstock') {
                              setState(() {
                                _action = 'minstock';
                              });
                              _loadProducts();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _action == 'minstock'
                                  ? AppTheme.primaryColor.withOpacity(0.12)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _action == 'minstock' ? AppTheme.primaryColor : Colors.grey.shade300,
                              ),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 20,
                                  color: _action == 'minstock' ? AppTheme.primaryColor : Colors.grey[700],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'น้อยสุด',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _action == 'minstock' ? AppTheme.primaryColor : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_action != 'maxstock') {
                              setState(() {
                                _action = 'maxstock';
                              });
                              _loadProducts();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _action == 'maxstock'
                                  ? AppTheme.primaryColor.withOpacity(0.12)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _action == 'maxstock' ? AppTheme.primaryColor : Colors.grey.shade300,
                              ),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  size: 20,
                                  color: _action == 'maxstock' ? AppTheme.primaryColor : Colors.grey[700],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'มากสุด',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _action == 'maxstock' ? AppTheme.primaryColor : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                      onRefresh: _loadProducts,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _products.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _products.length) {
                                // loader footer
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final p = _products[index] as Map<String, dynamic>;
                              return _buildProductCard(p, index);
                            },
                          ),
                    ),
          ),
        ],
      ),
    );
  }
}
