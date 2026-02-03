import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/widgets/image_helper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _items = [
    {'key': 'total', 'label': 'ยอดขายรวม', 'icon': Icons.attach_money},
    {'key': 'bestseller', 'label': 'สินค้าขายดี', 'icon': Icons.star},
    {'key': 'monthly', 'label': 'ยอดขายเดือนนี้', 'icon': Icons.calendar_today},
  ];

  Widget _buildTopSelector(BuildContext context) {
    return Container(
      color: AppTheme.primaryWhite,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final selected = i == _selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = i;
                });
                // If user selected total sales, fetch latest data
                if (i == 0) {
                  _fetchSalesData();
                } else if (i == 1) {
                  // bestsellers
                  _fetchBestSellers(_bestsellerTop);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        selected
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color:
                          selected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            selected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    switch (_items[_selectedIndex]['key']) {
      case 'total':
        return _buildTotalSales();
      case 'bestseller':
        return _buildBestSeller();
      case 'monthly':
        return _buildMonthlySales();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTotalSales() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Business-styled total sales card with gradient, big number and small KPIs
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryWhite))
                  : (_error != null
                      ? Text(_error!, style: const TextStyle(color: Colors.white))
                      : Row(
                          children: [
                            // Left: main numbers
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ยอดขายรวม',
                                    style: const TextStyle(
                                      color: AppTheme.primaryWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatCurrency(_totalRevenue),
                                    style: const TextStyle(
                                      color: AppTheme.primaryWhite,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryWhite.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.receipt_long, size: 14, color: AppTheme.primaryWhite),
                                            const SizedBox(width: 6),
                                            Text('คำสั่งซื้อ: $_totalOrders', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryWhite.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.inventory_2, size: 14, color: AppTheme.primaryWhite),
                                            const SizedBox(width: 6),
                                            Text('สินค้า: $_totalItemsSold', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Profit and margin
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('กำไรรวม: ${_formatCurrency(_grossProfit)}', style: const TextStyle(color: AppTheme.primaryWhite)),
                                            const SizedBox(height: 6),
                                            Builder(builder: (_) {
                                              final margin = (_totalRevenue == 0) ? 0.0 : (_grossProfit / _totalRevenue);
                                              final progress = margin.isNaN ? 0.0 : (margin < 0 ? 0.0 : (margin > 1 ? 1.0 : margin));
                                              final marginLabel = (_totalRevenue == 0) ? '-' : '${(margin * 100).toStringAsFixed(1)}%';
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  LinearProgressIndicator(
                                                    value: progress,
                                                    color: AppTheme.successColor,
                                                    backgroundColor: AppTheme.primaryWhite.withOpacity(0.12),
                                                    minHeight: 8,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text('Margin: $marginLabel', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Right: icon or sparkline placeholder
                            const SizedBox(width: 12),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: Icon(Icons.show_chart, color: AppTheme.primaryColor, size: 36),
                            ),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 12),
          const Text('รายการสินค้าขายดี:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoading)
            const SizedBox.shrink()
          else if (_error != null)
            const SizedBox.shrink()
          else if (_topProducts.isEmpty)
            const Text('ยังไม่มีข้อมูล')
          else
            Column(
              children:
                  _topProducts.map((prod) {
                    final img = _resolveProductImage(prod) ?? prod['image'];
                    return Card(
                      child: ListTile(
            leading: img != null
              ? buildProductImageWidget(img, width: 48, height: 48, fit: BoxFit.cover)
              : const Icon(Icons.image_not_supported),
                        title: Text(prod['name'] ?? '-'),
                        subtitle: Text(
                          'จำนวน: ${prod['quantity'] ?? 0}\nรวม: ${_formatCurrency((prod['revenue'] ?? 0).toDouble())}',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                        trailing: _buildProfitChip(prod),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  // state fields for sales
  bool _isLoading = false;
  String? _error;
  double _totalRevenue = 0.0;
  double _grossProfit = 0.0;
  int _totalOrders = 0;
  int _totalItemsSold = 0;
  List<dynamic> _topProducts = [];

  // Try to resolve many possible image shapes returned by API
  dynamic _resolveProductImage(dynamic prod) {
    if (prod == null) return null;
    try {
      if (prod is String) return prod;
      if (prod is Map<String, dynamic>) {
        // common keys
        if (prod.containsKey('image') && prod['image'] != null) return prod['image'];
        if (prod.containsKey('imageUrl') && prod['imageUrl'] != null) return prod['imageUrl'];
        if (prod.containsKey('images') && prod['images'] != null) {
          final imgs = prod['images'];
          if (imgs is List && imgs.isNotEmpty) {
            final first = imgs[0];
            if (first is String) return first;
            if (first is Map && first['url'] != null) return first['url'];
            if (first is Map && (first['data'] != null || first['base64'] != null)) return first['data'] ?? first['base64'];
          }
        }
        // nested product object
        if (prod.containsKey('product') && prod['product'] != null) return _resolveProductImage(prod['product']);
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    // fetch initial totals
    _fetchSalesData();
  }

  Future<void> _fetchSalesData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.saler);
      // POST without body returns overall sales per API note
      final resp = await http.post(uri, headers: headers, body: jsonEncode({}));
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        // support responses that wrap data or return fields at root
        final data = jsonResp['data'] ?? jsonResp;
        setState(() {
          _totalRevenue = (data['totalRevenue'] ?? 0).toDouble();
          _grossProfit = (data['grossProfit'] ?? 0).toDouble();
          _totalOrders = (data['totalOrders'] ?? 0) as int;
          _totalItemsSold = (data['totalItemsSold'] ?? 0) as int;
          _topProducts = (data['topProducts'] ?? []) as List<dynamic>;
        });
      } else {
        setState(() {
          _error = 'API error: ${resp.statusCode}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBestSeller() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'สินค้าขายดี',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Text('อันดับ: ', style: TextStyle(fontSize: 14)),
                  DropdownButton<int>(
                    value: _bestsellerTop,
                    items:
                        const [5, 10, 20, 50]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: Text('$v')),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _bestsellerTop = v;
                      });
                      _fetchBestSellers(v);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isBestsellerLoading)
            const Center(child: CircularProgressIndicator())
          else if (_bestsellerError != null)
            Text(_bestsellerError!, style: const TextStyle(color: Colors.red))
          else if (_bestsellerProducts.isEmpty)
            const Text('ยังไม่มีข้อมูล')
          else
            Column(
              children:
                  _bestsellerProducts.map((prod) {
                    final img = _resolveProductImage(prod) ?? prod['image'];
                    return Card(
                      child: ListTile(
            leading: img != null
              ? buildProductImageWidget(img, width: 48, height: 48, fit: BoxFit.cover)
              : const Icon(Icons.image_not_supported),
                        title: Text(prod['name'] ?? '-'),
                        subtitle: Text(
                          'จำนวน: ${prod['quantity'] ?? 0}  •  รายได้: ${_formatCurrency((prod['revenue'] ?? 0).toDouble())}',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                        trailing: _buildProfitChip(prod),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  // bestseller state
  int _bestsellerTop = 10;
  bool _isBestsellerLoading = false;
  String? _bestsellerError;
  List<dynamic> _bestsellerProducts = [];

  Future<void> _fetchBestSellers(int top) async {
    setState(() {
      _isBestsellerLoading = true;
      _bestsellerError = null;
    });
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.saler);
      final body = {
        'statusNames': ['completed', 'success'],
        'top': top,
      };
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final data = jsonResp['data'] ?? jsonResp;
        if (mounted) {
          setState(() {
            _bestsellerProducts = (data['topProducts'] ?? []) as List<dynamic>;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _bestsellerError = 'API error: ${resp.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bestsellerError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBestsellerLoading = false;
        });
      }
    }
  }

  Widget _buildMonthlySales() {
    final monthLabel =
        _monthlyDate == null
            ? 'เลือกเดือน (ค่าเริ่มต้น: เดือนนี้)'
            : '${_monthlyDate!.year}-${_monthlyDate!.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ยอดขายเดือน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(monthLabel),
                ],
              ),
              Row(
                children: [
                  const Text('อันดับ: ', style: TextStyle(fontSize: 14)),
                  DropdownButton<int>(
                    value: _monthlyTop,
                    items:
                        const [5, 10, 20, 50]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: Text('$v')),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _monthlyTop = v;
                      });
                      _fetchMonthlyData();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Month picker moved to AppBar action to avoid overflow and improve accessibility
                  const SizedBox.shrink(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Monthly totals styled similarly to total sales card
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isMonthlyLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryWhite))
                  : (_monthlyError != null
                      ? Text(_monthlyError!, style: const TextStyle(color: Colors.white))
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ยอดขายเดือน',
                                    style: const TextStyle(
                                      color: AppTheme.primaryWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatCurrency(_monthlyTotalRevenue),
                                    style: const TextStyle(
                                      color: AppTheme.primaryWhite,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryWhite.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.receipt_long, size: 14, color: AppTheme.primaryWhite),
                                            const SizedBox(width: 6),
                                            Text('คำสั่งซื้อ: $_monthlyTotalOrders', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryWhite.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.inventory_2, size: 14, color: AppTheme.primaryWhite),
                                            const SizedBox(width: 6),
                                            Text('สินค้า: $_monthlyTotalItemsSold', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('กำไรรวม: ${_formatCurrency(_monthlyGrossProfit)}', style: const TextStyle(color: AppTheme.primaryWhite)),
                                  const SizedBox(height: 6),
                                  Builder(builder: (_) {
                                    final margin = (_monthlyTotalRevenue == 0) ? 0.0 : (_monthlyGrossProfit / _monthlyTotalRevenue);
                                    final progress = margin.isNaN ? 0.0 : (margin < 0 ? 0.0 : (margin > 1 ? 1.0 : margin));
                                    final marginLabel = (_monthlyTotalRevenue == 0) ? '-' : '${(margin * 100).toStringAsFixed(1)}%';
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: progress,
                                          color: AppTheme.successColor,
                                          backgroundColor: AppTheme.primaryWhite.withOpacity(0.12),
                                          minHeight: 8,
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Margin: $marginLabel', style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12)),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 32),
                            ),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 8),
          if (_isMonthlyLoading)
            const SizedBox.shrink()
          else if (_monthlyError != null)
            const SizedBox.shrink()
          else if (_monthlyTopProducts.isEmpty)
            const Text('ยังไม่มีข้อมูล')
          else
            Column(
              children:
                  _monthlyTopProducts.map((prod) {
                    final img = _resolveProductImage(prod) ?? prod['image'];
                    return Card(
                      child: ListTile(
                        leading: img != null
                            ? buildProductImageWidget(img, width: 48, height: 48, fit: BoxFit.cover)
                            : const Icon(Icons.image_not_supported),
                        title: Text(prod['name'] ?? '-'),
                        subtitle: Text(
                          'จำนวน: ${prod['quantity'] ?? 0}  •  รายได้: ${_formatCurrency((prod['revenue'] ?? 0).toDouble())}',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                        trailing: _buildProfitChip(prod),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  // monthly state
  DateTime? _monthlyDate;
  int _monthlyTop = 10;
  bool _isMonthlyLoading = false;
  String? _monthlyError;
  double _monthlyTotalRevenue = 0.0;
  double _monthlyGrossProfit = 0.0;
  int _monthlyTotalOrders = 0;
  int _monthlyTotalItemsSold = 0;
  List<dynamic> _monthlyTopProducts = [];

  Future<void> _fetchMonthlyData() async {
    setState(() {
      _isMonthlyLoading = true;
      _monthlyError = null;
    });
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.saler);
      final now = DateTime.now();
      final selected = _monthlyDate ?? DateTime(now.year, now.month, 1);
      final start =
          DateTime(selected.year, selected.month, 1).toUtc().toIso8601String();
      final endDate = DateTime(
        selected.year,
        selected.month + 1,
        1,
      ).subtract(const Duration(days: 1));
      final end =
          DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
          ).toUtc().toIso8601String();
      final body = {
        'startDate': start,
        'endDate': end,
        'statusNames': ['completed', 'success'],
        'top': _monthlyTop,
      };
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final data = jsonResp['data'] ?? jsonResp;
        if (mounted) {
          setState(() {
            _monthlyTotalRevenue = (data['totalRevenue'] ?? 0).toDouble();
            _monthlyGrossProfit = (data['grossProfit'] ?? 0).toDouble();
            _monthlyTotalOrders = (data['totalOrders'] ?? 0) as int;
            _monthlyTotalItemsSold = (data['totalItemsSold'] ?? 0) as int;
            _monthlyTopProducts = (data['topProducts'] ?? []) as List<dynamic>;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _monthlyError = 'API error: ${resp.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _monthlyError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMonthlyLoading = false;
        });
      }
    }
  }

  double _productProfit(dynamic prod) {
    try {
      final revenue = (prod['revenue'] ?? 0).toDouble();
      final quantity = (prod['quantity'] ?? 0).toDouble();
      final costPerUnit = (prod['costPerUnit'] ?? prod['cost'] ?? 0).toDouble();
      final profit = revenue - (costPerUnit * quantity);
      return profit;
    } catch (_) {
      return 0.0;
    }
  }

  String _formatCurrency(double value) {
    try {
      final fmt = NumberFormat.currency(locale: 'th', symbol: '฿');
      return fmt.format(value);
    } catch (_) {
      return '฿${value.toStringAsFixed(2)}';
    }
  }

  Widget _buildProfitChip(dynamic prod) {
    final profit = _productProfit(prod);
    final percent = _profitPercentage(prod);
    final positive = profit >= 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: positive ? AppTheme.successColor.withOpacity(0.12) : AppTheme.errorColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${positive ? '+' : '-'}${_formatCurrency(profit.abs())}',
            style: TextStyle(
              color: positive ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          percent != null ? '${percent.toStringAsFixed(1)}%' : '',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  double? _profitPercentage(dynamic prod) {
    try {
      final revenue = (prod['revenue'] ?? 0).toDouble();
      final profit = _productProfit(prod);
      if (revenue == 0) return null;
      return (profit / revenue) * 100.0;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        title: Text(
          localizations?.sales ?? 'ยอดขาย',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_items[_selectedIndex]['key'] == 'monthly')
            IconButton(
              icon: const Icon(
                Icons.calendar_month,
                color: AppTheme.primaryWhite,
              ),
              onPressed: () async {
                final now = DateTime.now();
                final initial =
                    _monthlyDate ?? DateTime(now.year, now.month, 1);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(now.year, now.month, now.day),
                  helpText: 'เลือกวันที่เพื่อกำหนดเดือน',
                  fieldLabelText: 'เลือกวันที่',
                );
                if (picked != null) {
                  setState(() {
                    _monthlyDate = DateTime(picked.year, picked.month, 1);
                  });
                  _fetchMonthlyData();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSelector(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    final key = _items[_selectedIndex]['key'];
    if (key == 'total') {
      await _fetchSalesData();
    } else if (key == 'bestseller') {
      await _fetchBestSellers(_bestsellerTop);
    } else if (key == 'monthly') {
      await _fetchMonthlyData();
    }
  }
}
