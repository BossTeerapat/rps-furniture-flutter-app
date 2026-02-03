import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/Screen/cart/CheckoutScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/widgets/image_helper.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  Set<int> _selectedItems = <int>{};
  bool _isLoading = true;
  bool _selectAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get user_id (accountId)
      int? accountId = prefs.getInt('user_id');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      if (accountId == null) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _error = localizations?.pleaseLogin ?? 'กรุณาเข้าสู่ระบบ';
            _isLoading = false;
          });
        }
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.cart),
        headers: headers,
        body: jsonEncode({'accountId': accountId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _cartItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
            _isLoading = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลตะกร้าได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(int cartItemId, String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get user_id (accountId)
      int? accountId = prefs.getInt('user_id');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      if (accountId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบ')));
        }
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.updateProductInCart),
        headers: headers,
        body: jsonEncode({
          'cartItemId': cartItemId,
          'accountId': accountId,
          'action': action,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          _loadCartItems(); // Reload cart items
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถอัปเดตจำนวนสินค้าได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteItem(int cartItemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get user_id (accountId)
      int? accountId = prefs.getInt('user_id');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      if (accountId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบ')));
        }
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.deleteProductInCart),
        headers: headers,
        body: jsonEncode({'cartItemId': cartItemId, 'accountId': accountId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          // Remove from selected items if it was selected
          _selectedItems.remove(cartItemId);
          _loadCartItems(); // Reload cart items
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถลบสินค้าได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedItems = _cartItems.map((item) => item['id'] as int).toSet();
      } else {
        _selectedItems.clear();
      }
    });
  }

  void _toggleSelectItem(int itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
      _selectAll = _selectedItems.length == _cartItems.length;
    });
  }

  double _getSelectedItemsTotal() {
    double total = 0;
    for (var item in _cartItems) {
      if (_selectedItems.contains(item['id'])) {
        final product = item['product'];
        final price =
            (product['salePrice'] ?? product['price'] ?? 0).toDouble();
        final quantity = item['quantity'] ?? 1;
        total += price * quantity;
      }
    }
    return total;
  }

  int _getSelectedItemsCount() {
    return _selectedItems.length;
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final product = item['product'];
    final productName = product['name'] ?? 'Unknown Product';
    final price = (product['salePrice'] ?? product['price'] ?? 0).toDouble();
    final quantity = item['quantity'] ?? 1;
    final cartItemId = item['id']; // ใช้ cartItemId แทน cartId
    final options =
        item['options'] ?? []; // เปลี่ยนจาก productOptions เป็น options
    final imageUrl =
        product['images']?.isNotEmpty == true
            ? product['images'][0]['url']
            : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: _selectedItems.contains(cartItemId),
              onChanged: (bool? value) {
                _toggleSelectItem(cartItemId);
              },
              activeColor: AppTheme.primaryColor,
            ),

            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child:
                  imageUrl.isNotEmpty
                      ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: buildProductImageWidget(imageUrl, fit: BoxFit.cover),
                              )
                      : Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
            ),

            const SizedBox(width: 12),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AppTheme.errorColor,
                        ),
                        onPressed: () {
                          final localizations = AppLocalizations.of(context);
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(localizations?.deleteConfirmTitle ?? 'ยืนยันการลบ'),
                                content: Text(
                                  localizations?.deleteConfirmContent ?? 'คุณต้องการลบสินค้านี้จากตะกร้าหรือไม่?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: Text(localizations?.cancel ?? 'ยกเลิก'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _deleteItem(cartItemId);
                                    },
                                    child: Text(localizations?.delete ?? 'ลบ'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  if (options != null && options.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var option in options)
                            Text(
                              '${option['productOption']['type']}: ${option['productOption']['value']} (${AppLocalizations.of(context)?.remaining ?? 'เหลือ'} ${option['productOption']['stock']} ${AppLocalizations.of(context)?.piece ?? 'ชิ้น'})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '฿${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),

                      // Quantity Controls
                      Row(
                        children: [
                          IconButton(
                            onPressed:
                                quantity > 1
                                    ? () {
                                      _updateQuantity(cartItemId, 'decrease');
                                    }
                                    : null,
                            icon: const Icon(Icons.remove),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quantity.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _updateQuantity(cartItemId, 'increase');
                            },
                            icon: const Icon(Icons.add),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.cart ?? 'ตะกร้าสินค้า',
          style: const TextStyle(color: AppTheme.primaryWhite),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: AppTheme.primaryWhite),
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child:
            _isLoading
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
                        onPressed: _loadCartItems,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.primaryWhite,
                        ),
                        child: Text(AppLocalizations.of(context)?.retry ?? 'ลองใหม่'),
                      ),
                    ],
                  ),
                )
                : _cartItems.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 80,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context)?.cartEmptyTitle ?? 'ตะกร้าสินค้าว่าง',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context)?.cartEmptySubtitle ?? 'เพิ่มสินค้าลงในตะกร้าเพื่อเริ่มซื้อของ',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    // Select All Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectAll,
                            onChanged: (bool? value) {
                              _toggleSelectAll();
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                          Text(
                            AppLocalizations.of(context)?.selectAll ?? 'เลือกทั้งหมด',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_cartItems.length} ${AppLocalizations.of(context)?.items ?? 'รายการ'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cart Items List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          return _buildCartItem(_cartItems[index]);
                        },
                      ),
                    ),

                    // Bottom Bar with Total and Checkout
                    if (_selectedItems.isNotEmpty)
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
                        child: SafeArea(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${AppLocalizations.of(context)?.select ?? 'เลือก'} ${_getSelectedItemsCount()} ${AppLocalizations.of(context)?.items ?? 'รายการ'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${AppLocalizations.of(context)?.totalLabel ?? 'รวม'} ฿${_getSelectedItemsTotal().toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Get selected items data
                                  final selectedItemsData = _cartItems
                                      .where((item) => _selectedItems.contains(item['id']))
                                      .toList();
                                  
                                  // Navigate to checkout screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        cartItemIds: _selectedItems.toList(),
                                        selectedItems: selectedItemsData,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.primaryWhite,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)?.checkoutLabel ?? 'สั่งซื้อ',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
