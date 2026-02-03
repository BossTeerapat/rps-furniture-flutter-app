import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../product/ProductReviewScreen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int? _accountId;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadAccountId();
    _loadRole();
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
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role');
    });
  }

  Future<void> _cancelOrder() async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยกเลิกคำสั่งซื้อ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คุณแน่ใจหรือไม่ที่จะยกเลิกคำสั่งซื้อนี้?'),
              const SizedBox(height: 12),
              // Check if order has payment slip
              if (widget.order['slips'] != null &&
                  (widget.order['slips'] as List).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'คำสั่งซื้อนี้ได้ชำระเงินแล้ว ทางร้านจะดำเนินการคืนเงินให้',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ไม่ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ยืนยันยกเลิก'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final headers = await ApiConfig.buildHeaders();
      final requestBody = {
        'orderId': widget.order['id'],
        'accountId': _accountId,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.canceledOrder),
        headers: headers,
        body: jsonEncode(requestBody),
      );

  if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200 || data['status'] == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['msg'] ?? 'ยกเลิกคำสั่งซื้อสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );
    // Go back to previous screen and request refresh
    Navigator.of(context).pop({'refresh': true});
          }
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถยกเลิกคำสั่งซื้อได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showQRPayment() async {
    try {
      final headers = await ApiConfig.buildHeaders();
      final requestBody = {'paymentTypeId': 2};

      final response = await http.post(
        Uri.parse(ApiConfig.payment),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200 || data['status'] == 201) {
          final qrCode = data['qrCode'];
          if (qrCode == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ไม่พบ QR Code กรุณาติดต่อร้านค้า'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          if (mounted) {
            final order = widget.order;
            final shippingPrice = (order['shippingPrice'] ?? 0).toDouble();
            final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
            double actualTotal = 0;
            for (var item in items) {
              final quantity = (item['quantity'] ?? 0) as int;
              final price = (item['price'] ?? 0).toDouble();
              actualTotal += (price * quantity);
            }
            _showQRCodeModal(
              qrCode,
              orderId: widget.order['id'],
              actualTotal: actualTotal,
              shippingPrice: shippingPrice,
            );
          }
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลด QR Code ได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQRCodeModal(
    Map<String, dynamic> qrCode, {
    int? orderId,
    required double actualTotal,
    required double shippingPrice,
  }) {
    File? selectedImage;
    String? imageBase64;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AppBar style header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ชำระเงินผ่าน QR Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 28,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: buildProductImageWidget(
                                    qrCode['imageUrl'],
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_circle,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            qrCode['accountName'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            qrCode['bankName'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'ยอดที่ต้องชำระ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '฿${(actualTotal + shippingPrice).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'กรุณาสแกน QR Code เพื่อชำระเงิน\nหลังจากชำระเงินแล้วกดปุ่ม "อัปโหลดหลักฐานการชำระเงิน"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      selectedImage = File(picked.path);
                                    });
                                    final bytes = await picked.readAsBytes();
                                    setState(() {
                                      imageBase64 =
                                          'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.upload_file),
                                label: Text(
                                  selectedImage == null
                                      ? 'อัปโหลดหลักฐานการชำระเงิน'
                                      : 'เปลี่ยนไฟล์สลิป',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              if (selectedImage != null) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    selectedImage!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton(
                                onPressed:
                                    (selectedImage != null && !isUploading)
                                        ? () async {
                                          if (orderId == null ||
                                              _accountId == null ||
                                              imageBase64 == null ||
                                              imageBase64!.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'กรุณาเลือกไฟล์สลิปและตรวจสอบข้อมูลให้ครบถ้วน',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          setState(() {
                                            isUploading = true;
                                          });
                                          try {
                                            final headers =
                                                await ApiConfig.buildHeaders();
                                            final uploadBody = jsonEncode({
                                              'orderId': orderId,
                                              'accountId': _accountId,
                                              'imageBase64': imageBase64,
                                            });
                                            final response = await http.post(
                                              Uri.parse(
                                                ApiConfig.uploadPayment,
                                              ),
                                              headers: headers,
                                              body: uploadBody,
                                            );
                                            String message =
                                                'อัปโหลดสลิปสำเร็จ';
                                            if (response.statusCode == 200 ||
                                                response.statusCode == 201) {
                                              try {
                                                final data = jsonDecode(
                                                  response.body,
                                                );
                                                message =
                                                    data['msg'] ??
                                                    data['message'] ??
                                                    message;
                                              } catch (_) {
                                                message =
                                                    response.body.isNotEmpty
                                                        ? response.body
                                                        : message;
                                              }
                                              if (mounted) {
                                                Navigator.of(context).pop();
                                                Navigator.of(
                                                  context,
                                                ).pop({'refresh': true});
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(message),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } else {
                                              String errorMessage =
                                                  'อัปโหลดสลิปไม่สำเร็จ';
                                              try {
                                                final data = jsonDecode(
                                                  response.body,
                                                );
                                                errorMessage =
                                                    data['msg'] ??
                                                    data['message'] ??
                                                    errorMessage;
                                              } catch (_) {
                                                errorMessage =
                                                    response.body.isNotEmpty
                                                        ? response.body
                                                        : errorMessage;
                                              }
                                              throw Exception(errorMessage);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              String errorMsg = e.toString();
                                              if (errorMsg.contains(
                                                    'Slip uploaded successfully',
                                                  ) ||
                                                  errorMsg.contains(
                                                    'You order is under review',
                                                  ) ||
                                                  errorMsg.contains(
                                                    'uploaded successfully',
                                                  )) {
                                                Navigator.of(context).pop();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      errorMsg.replaceAll(
                                                        'Exception: ',
                                                        '',
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'เกิดข้อผิดพลาด: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          } finally {
                                            setState(() {
                                              isUploading = false;
                                            });
                                          }
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child:
                                    isUploading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Text(
                                          'ยืนยันการอัปโหลด',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'หลังอัปโหลดสลิปรอการตรวจสอบจากร้านค้า',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildProductItem(Map<String, dynamic> item) {
    final product = item['product'] ?? {};
    final images = List<Map<String, dynamic>>.from(product['images'] ?? []);
    final imageUrl = images.isNotEmpty ? images[0]['url'] : '';
    final quantity = item['quantity'] ?? 0;
    final price = (item['price'] ?? 0).toDouble();

    // parse selected options tolerant to multiple shapes
    final dynamic optionsRaw = item['selectedOptions'] ?? item['options'] ?? item['productOptions'] ?? item['selected_options'] ?? [];
    final List<Map<String, dynamic>> selectedOptions = [];
    if (optionsRaw is List) {
      for (var o in optionsRaw) {
        if (o is Map) {
          selectedOptions.add(Map<String, dynamic>.from(o));
        } else {
          selectedOptions.add({'value': o.toString()});
        }
      }
    }

    String optionsText = '';
    if (selectedOptions.isNotEmpty) {
      final parts = selectedOptions.map((o) {
        final type = (o['type'] ?? o['productOption']?['type'] ?? o['name'] ?? '').toString();
        final value = (o['value'] ?? o['productOption']?['value'] ?? o['label'] ?? '').toString();
        if (type.isNotEmpty && value.isNotEmpty) return '$type: $value';
        if (value.isNotEmpty) return value;
        return '';
      }).where((s) => s.isNotEmpty).toList();
      optionsText = parts.join(' • ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    imageUrl.isNotEmpty
                        ? buildProductImageWidget(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                        : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 40,
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
                  ),
                  const SizedBox(height: 4),
                  // show selected options (if any) otherwise fallback to product size
                  if (optionsText.isNotEmpty)
                    Text(optionsText, style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                  else if ((product['size'] ?? '').toString().trim().isNotEmpty)
                    Text('ขนาด: ${product['size']}', style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                  else
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'จำนวน: $quantity',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '฿${price.toStringAsFixed(0)}',
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final shippingPrice = (order['shippingPrice'] ?? 0).toDouble();

    // Calculate actual total from items (real prices paid by customer)
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    double actualTotal = 0;
    for (var item in items) {
      final quantity = (item['quantity'] ?? 0) as int;
      final price = (item['price'] ?? 0).toDouble();
      actualTotal += (price * quantity);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'รายละเอียดคำสั่งซื้อ #${order['id']}',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'สถานะคำสั่งซื้อ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getStatusColor(
                              order['status']?['name'] ?? '',
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order['status']?['label'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.getStatusColor(
                                order['status']?['name'] ?? '',
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'วันที่สั่งซื้อ: ${_formatDate(order['createdAt'] ?? '')}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Address
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ที่อยู่จัดส่ง',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['address']?['fullName'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['address']?['phone'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.home,
                                color: Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${order['address']?['address'] ?? ''}\n'
                                  '${order['address']?['subdistrict']?['name'] ?? ''} '
                                  '${order['address']?['district']?['name'] ?? ''} '
                                  '${order['address']?['province']?['name'] ?? ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Employee (only show if exists)
            if (order['deliveryEmployee'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'พนักงานจัดส่ง',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${order['deliveryEmployee']?['firstname'] ?? ''} ${order['deliveryEmployee']?['lastname'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order['deliveryEmployee']?['phone'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Products
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'รายการสินค้า',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List<Map<String, dynamic>>.from(
                      order['items'] ?? [],
                    ).map((item) => _buildProductItem(item)).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment & Total
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ข้อมูลการชำระเงิน',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          order['paymentType']?['name'] == 'QR'
                              ? Icons.qr_code
                              : Icons.money,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order['paymentType']?['label'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ราคาสินค้า'),
                        Text('฿${actualTotal.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ค่าจัดส่ง'),
                        Text('฿${shippingPrice.toStringAsFixed(0)}'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ยอดรวมทั้งสิ้น',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '฿${(actualTotal + shippingPrice).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Payment Button for pending payment orders (buyer only)
            if (order['status']?['name'] == 'pending' && _role == 'buyer')
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showQRPayment(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code, size: 20),
                      label: const Text(
                        'ชำระเงินผ่าน QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Payment Slip for QR code payment
            if (order['paymentType']?['name'] == 'QR' &&
                (order['slips'] != null && (order['slips'] as List).isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'สลิปการชำระเงิน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List<Map<String, dynamic>>.from(order['slips']).map(
                          (slip) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return Dialog(
                                        backgroundColor: Colors.black
                                            .withOpacity(0.6),
                                        insetPadding: const EdgeInsets.all(0),
                                        shape: null,
                                        child: GestureDetector(
                                          onTap:
                                              () => Navigator.of(context).pop(),
                                          child: InteractiveViewer(
                                            child: buildProductImageWidget(
                                              slip['imageUrl'],
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: buildProductImageWidget(
                                  slip['imageUrl'],
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'อัปโหลดเมื่อ: ${_formatDate(slip['uploadedAt'] ?? '')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Admin: verifying order - show confirm button
            if (order['status']?['name'] == 'verifying' && _role == 'admin')
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('ยืนยันคำสั่งซื้อ'),
                                content: Text(
                                  'กรุณาตรวจสอบยอดเงินให้ถูกต้องก่อนยืนยัน\nยอดรวมทั้งสิ้น: ฿${(actualTotal + shippingPrice).toStringAsFixed(0)}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('ตกลง'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm != true) return;
                        try {
                          final headers = await ApiConfig.buildHeaders();
                          final response = await http.post(
                            Uri.parse(ApiConfig.confirmOrder),
                            headers: headers,
                            body: jsonEncode({'orderId': order['id']}),
                          );
                          if (response.statusCode == 200 ||
                              response.statusCode == 201) {
                            final data = jsonDecode(response.body);
                            if (data['status'] == 200 ||
                                data['status'] == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      data['msg'] ??
                                          'ยืนยันคำสั่งซื้อเรียบร้อย',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop({'refresh': true});
                              }
                            } else {
                              throw Exception(
                                data['msg'] ?? 'ไม่สามารถยืนยันคำสั่งซื้อได้',
                              );
                            }
                          } else {
                            throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20, color: Colors.white),
                      label: const Text(
                        'ยืนยันคำสั่งซื้อ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

      // Cancel Button for pending/verifying orders (all users)
      // and admins can also cancel when order is preparing or shipping
      if (order['status']?['name'] == 'pending' ||
        order['status']?['name'] == 'verifying' ||
        (_role == 'admin' && (order['status']?['name'] == 'preparing' || order['status']?['name'] == 'shipping')))
              Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _cancelOrder(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.white),
                      label: const Text(
                        'ยกเลิกคำสั่งซื้อ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Review Button for completed orders (only show to buyers)
            if (order['status']?['name'] == 'completed' && _role == 'buyer')
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProductReviewScreen(order: order),
                          ),
                        );

                        // If review was successful, you might want to refresh or show a message
                        if (result == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ขอบคุณสำหรับการรีวิว!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.star, size: 20),
                      label: const Text(
                        'รีวิวสินค้า',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Employee: preparing order - show 'เตรียมสินค้าสำเร็จ' button
            if (order['status']?['name'] == 'preparing' && _role == 'employee')
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('เตรียมสินค้าสำเร็จ'),
                                content: const Text(
                                  'คุณต้องการยืนยันว่าเตรียมสินค้าสำเร็จหรือไม่?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('ตกลง'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm != true) return;
                        try {
                          final headers = await ApiConfig.buildHeaders();
                          final response = await http.post(
                            Uri.parse(ApiConfig.shippingOrder),
                            headers: headers,
                            body: jsonEncode({
                              'orderId': order['id'],
                              'employeeId': _accountId,
                            }),
                          );
                          if (response.statusCode == 200 ||
                              response.statusCode == 201) {
                            final data = jsonDecode(response.body);
                            if (data['status'] == 200 ||
                                data['status'] == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      data['msg'] ?? 'เตรียมสินค้าสำเร็จ',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop({'refresh': true});
                              }
                            } else {
                              throw Exception(
                                data['msg'] ?? 'ไม่สามารถอัปเดตสถานะได้',
                              );
                            }
                          } else {
                            throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'เตรียมสินค้าสำเร็จ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Employee: shipping order - show 'นำส่งสำเร็จ' button
            if (order['status']?['name'] == 'shipping' && _role == 'employee')
              Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('นำส่งสำเร็จ'),
                                content: const Text(
                                  'คุณต้องการยืนยันว่านำส่งสินค้าสำเร็จหรือไม่?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('ตกลง'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm != true) return;
                        try {
                          final headers = await ApiConfig.buildHeaders();
                          final response = await http.post(
                            Uri.parse(ApiConfig.completedOrder),
                            headers: headers,
                            body: jsonEncode({'orderId': order['id']}),
                          );
                          if (response.statusCode == 200 ||
                              response.statusCode == 201) {
                            final data = jsonDecode(response.body);
                            if (data['status'] == 200 ||
                                data['status'] == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(data['msg'] ?? 'นำส่งสำเร็จ'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop({'refresh': true});
                              }
                            } else {
                              throw Exception(
                                data['msg'] ?? 'ไม่สามารถอัปเดตสถานะได้',
                              );
                            }
                          } else {
                            throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'นำส่งสำเร็จ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
