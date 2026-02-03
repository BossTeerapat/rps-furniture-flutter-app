import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/menu/admin/CreateProductScreen.dart';
import 'package:rps_app/Screen/menu/admin/EditProductScreen.dart';
import 'package:intl/intl.dart';
import 'package:rps_app/widgets/image_helper.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  String _status = ''; // empty = all
  bool _isLoading = false;
  String? _error;
  List<dynamic> _products = [];
  // pagination
  int _page = 1;
  final int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  late ScrollController _scrollController;

  final Map<String, String> _statusOptions = {
    '': 'ทั้งหมด',
    'new': 'สินค้าใหม่',
    'bestseller': 'ขายดี',
    'sale': 'ลดราคา',
    'recommend': 'แนะนำ',
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchProducts();
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
    final threshold = 0.0; // load when reaching bottom (can be tweaked)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll - current <= threshold) {
      _fetchProducts(loadMore: true);
    }
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
      _page += 1;
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
      _page = 1;
      _hasMore = true;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.listProductsByStatus);
      final Map<String, dynamic> body = {};
      if (_status.isNotEmpty) body['statusName'] = _status;
      body['page'] = _page;
      body['pageSize'] = _pageSize;
      final resp = await http.post(uri, headers: headers, body: jsonEncode(body));
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final data = jsonResp['data'] ?? jsonResp;
        final products = (data['products'] ?? jsonResp['products'] ?? []) as List<dynamic>;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _products.addAll(products);
            } else {
              _products = products;
            }
          });
        }

        // pagination: check page/totalPages if provided
        final int respPage = data['page'] is int ? data['page'] as int : (jsonResp['page'] is int ? jsonResp['page'] as int : _page);
        final dynamic totalPagesRaw = data['totalPages'] ?? jsonResp['totalPages'];
        final int? respTotalPages = totalPagesRaw is int ? totalPagesRaw : (totalPagesRaw is String ? int.tryParse(totalPagesRaw) : null);
        if (respTotalPages != null) {
          _hasMore = respPage < respTotalPages;
        } else {
          // fallback: if server didn't provide totalPages, decide by items length
          _hasMore = products.length >= _pageSize;
        }
      } else {
        if (mounted) setState(() => _error = 'API error: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
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

  String? _absoluteImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final s = url.toString();
    if (s.startsWith('http') || s.startsWith('https')) return s;
    final base = ApiConfig.baseUrl;
    if (base == null || base.isEmpty) return s; // can't resolve
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return s.startsWith('/') ? b + s : b + '/' + s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: const Text('จัดการสินค้า', style: TextStyle(color: AppTheme.primaryWhite)),
        actions: [
          IconButton(
            tooltip: 'เพิ่มสินค้า',
            icon: const Icon(Icons.add, color: AppTheme.primaryWhite),
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProductScreen()));
              if (res == true) {
                // placeholder: refresh list after creating
                _fetchProducts();
              }
            },
          )
        ],
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProducts,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('สถานะ: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: _statusOptions.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                        _fetchProducts();
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red))
              else if (_products.isEmpty)
                const Text('ยังไม่มีสินค้า', textAlign: TextAlign.center)
              else
                Column(
                  children: _products.map((p) {
                    final images = (p['images'] ?? []) as List<dynamic>;
                    String? imageUrl;
                    Uint8List? imageBytes;
                    if (images.isNotEmpty) {
                      final img0 = images[0];
                      if (img0 is String) {
                        final s = img0;
                        if (s.startsWith('http') || s.startsWith('https')) {
                          imageUrl = s;
                        } else if (s.contains('base64,')) {
                          final b64 = s.split('base64,').last;
                          try {
                            imageBytes = base64Decode(b64);
                          } catch (_) {}
                        } else {
                          try {
                            imageBytes = base64Decode(s);
                          } catch (_) {
                            imageUrl = _absoluteImageUrl(s);
                          }
                        }
                      } else if (img0 is Map) {
                        final url = img0['url']?.toString();
                        final b64field = img0['base64'] ?? img0['data'];
                        if (url != null && url.isNotEmpty) {
                          imageUrl = _absoluteImageUrl(url);
                        } else if (b64field != null) {
                          final s = b64field.toString();
                          final b64 = s.contains('base64,') ? s.split('base64,').last : s;
                          try {
                            imageBytes = base64Decode(b64);
                          } catch (_) {}
                        }
                      }
                    }
                    final category = p['category'] != null ? (p['category']['name'] ?? '') : '';
                    final price = (p['price'] ?? 0).toDouble();
                    final sale = (p['salePrice'] ?? p['sale'] ?? 0).toDouble();
                    final id = p['id'] ?? UniqueKey().toString();
                    return Dismissible(
                      key: ValueKey(id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                          // Show the ListAccount-style confirm dialog which will
                          // start a countdown and perform the server delete.
                          await _confirmAndDeleteProduct(p);
                          // We handle removal ourselves inside the helper, so
                          // return false to prevent Dismissible from auto-removing.
                          return false;
                        },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                  child: imageBytes != null
                    ? Image.memory(imageBytes, width: 84, height: 84, fit: BoxFit.cover)
                    : (imageUrl != null && imageUrl.isNotEmpty)
                      ? buildProductImageWidget(imageUrl, width: 84, height: 84, fit: BoxFit.cover)
                      : Container(
                          width: 84,
                          height: 84,
                          color: AppTheme.primaryColor.withOpacity(0.06),
                          child: const Icon(Icons.image_not_supported, color: AppTheme.textSecondaryColor),
                        ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text('หมวด: $category', style: TextStyle(color: AppTheme.textSecondaryColor)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(_formatCurrency(price), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 8),
                                        if (sale > 0) Text(_formatCurrency(sale), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                onPressed: () async {
                                  final pid = p['id'];
                                  if (pid == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบรหัสสินค้า')));
                                    return;
                                  }
                                  // Navigate to EditProductScreen and let it fetch productDetail itself
                                  try {
                                    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProductScreen(productId: pid)));
                                    if (result == true) _fetchProducts();
                                    return;
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ...existing code...

  Future<bool> _deleteProductOnServer(Map<String, dynamic> product) async {
    try {
      final id = product['id'];
      final headers = await ApiConfig.buildHeaders();
      final body = jsonEncode({'id': id, 'action': 'delete'});
      final uri = Uri.parse(ApiConfig.deleteProduct);
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 15));
      debugPrint('deleteProduct request: ${body}');
      debugPrint('deleteProduct response status: ${resp.statusCode} body: ${resp.body}');
      if (resp.statusCode == 200) {
        final Map<String, dynamic> j = jsonDecode(resp.body);
        if (j['msg'] != null) return true;
      }
    } catch (e) {
      debugPrint('deleteProduct error: $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสินค้าไม่สำเร็จ')));
    return false;
  }

  Future<void> _confirmAndDeleteProduct(Map<String, dynamic> product) async {
    // Mirror the ListAccountScreen._confirmAndDelete dialog behavior
    int countdown = 8;
    Timer? timer;
    bool started = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState2) {
          void startTimer() {
            timer?.cancel();
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              setState2(() {
                countdown -= 1;
              });
              if (countdown <= 0) {
                t.cancel();
                Navigator.of(ctx2).pop();
                // perform delete
                _deleteProductOnServer(product).then((ok) {
                  if (ok) {
                    setState(() => _products.removeWhere((x) => x['id'] == product['id']));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสินค้าเรียบร้อยแล้ว')));
                  }
                });
              }
            });
          }

          return AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!started) ...[
                    const Text('คุณแน่ใจหรือไม่ว่าต้องการลบสินค้านี้?'),
                    const SizedBox(height: 12),
                    Text('ชื่อ: ${product['name'] ?? ''}'),
                    Text('id: ${product['id'] ?? ''}'),
                  ] else ...[
                    Row(
                      children: [
                        const SizedBox(width: 6, height: 6),
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(width: 12),
                        Expanded(child: Text('ลบสินค้าใน $countdown วินาที...')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('คุณสามารถกด ยกเลิก เพื่อยกเลิกการลบได้'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (timer != null && timer!.isActive) timer!.cancel();
                  Navigator.of(ctx).pop();
                },
                child: const Text('ยกเลิก'),
              ),
              if (!started)
                TextButton(
                  onPressed: () {
                    setState2(() {
                      started = true;
                      countdown = 8;
                    });
                    startTimer();
                  },
                  child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
                )
              else
                TextButton(
                  onPressed: () {
                    if (timer != null && timer!.isActive) timer!.cancel();
                    Navigator.of(ctx).pop();
                    _deleteProductOnServer(product).then((ok) {
                      if (ok) {
                        setState(() => _products.removeWhere((x) => x['id'] == product['id']));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสินค้าเรียบร้อยแล้ว')));
                      }
                    });
                  },
                  child: const Text('ลบทันที', style: TextStyle(color: Colors.red)),
                ),
            ],
          );
        });
      },
    ).then((_) {
      if (timer != null && timer!.isActive) timer!.cancel();
    });
  }
}
