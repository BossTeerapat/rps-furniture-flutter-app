import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:rps_app/Screen/cart/ThankYouScreen.dart';
import 'package:rps_app/Screen/menu/buyer/ListAddressScreen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<int> cartItemIds;
  final List<Map<String, dynamic>> selectedItems;

  const CheckoutScreen({
    super.key,
    required this.cartItemIds,
    required this.selectedItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _priceCalculation;
  bool _isLoadingAddresses = true;
  bool _isLoadingPrice = false;
  String? _error;
  int? _accountId;
  int _selectedPaymentType = 1; // Default to cash on delivery
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadAccountId();
    await _loadAddresses();
    if (_selectedAddress != null) {
      await _calculatePrice();
    }
  }

  Future<void> _loadAccountId() async {
    final prefs = await SharedPreferences.getInstance();

    // Get user_id (accountId)
    _accountId = prefs.getInt('user_id');
    if (_accountId == null) {
      final userIdString = prefs.getString('user_id');
      if (userIdString != null && userIdString.isNotEmpty) {
        _accountId = int.tryParse(userIdString);
      }
    }
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _error = null;
    });

    try {
      if (_accountId == null) {
        throw Exception('กรุณาเข้าสู่ระบบ');
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listUserAddress),
        headers: headers,
        body: jsonEncode({'accountId': _accountId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _addresses = List<Map<String, dynamic>>.from(
              data['addresses'] ?? [],
            );
            // If no addresses returned, keep selectedAddress null so UI prompts to add
            if (_addresses.isEmpty) {
              _selectedAddress = null;
            } else {
              // Set default address as selected
              _selectedAddress = _addresses.firstWhere(
                (address) => address['isDefault'] == true,
                orElse: () => _addresses.first,
              );
            }
            _isLoadingAddresses = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลที่อยู่ได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingAddresses = false;
      });
    }
  }

  Future<void> _calculatePrice() async {
    if (_selectedAddress == null || _accountId == null) return;

    setState(() {
      _isLoadingPrice = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final requestBody = {
        'accountId': _accountId,
        'addressId': _selectedAddress!['id'],
        'cartItemIds': widget.cartItemIds,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.calculatePrice),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _priceCalculation = data;
            _isLoadingPrice = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถคำนวณราคาได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      setState(() {
        _isLoadingPrice = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _createOrder() async {
    if (_selectedAddress == null ||
        _accountId == null ||
        _priceCalculation == null) {
      return;
    }

    // ถ้าเลือกชำระผ่าน QR Code ให้แสดง QR Code ก่อน
    if (_selectedPaymentType == 2) {
      await _showQRPayment();
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final requestBody = {
        'accountId': _accountId,
        'addressId': _selectedAddress!['id'],
        'cartItemIds': widget.cartItemIds,
        'productTotal': _priceCalculation!['productTotal'],
        'shipping': _priceCalculation!['shipping'],
        'total': _priceCalculation!['total'],
        'paymentTypeId': _selectedPaymentType,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.createOrder),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
            if (data['status'] == 200 || data['status'] == 201) {
          // Order created successfully
          if (mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(data['msg'] ?? 'สร้างคำสั่งซื้อสำเร็จ'),
            //     backgroundColor: Colors.green,
            //   ),
            // );

                // Navigate to Thank You screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => ThankYouScreen(
                            orderId: data['order']?['id'],
                          )),
                  (route) => false,
                );
          }
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถสร้างคำสั่งซื้อได้');
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
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _createOrderAndGetId() async {
    if (_selectedAddress == null ||
        _accountId == null ||
        _priceCalculation == null) {
      return null;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final requestBody = {
        'accountId': _accountId,
        'addressId': _selectedAddress!['id'],
        'cartItemIds': widget.cartItemIds,
        'productTotal': _priceCalculation!['productTotal'],
        'shipping': _priceCalculation!['shipping'],
        'total': _priceCalculation!['total'],
        'paymentTypeId': _selectedPaymentType,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.createOrder),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200 || data['status'] == 201) {
          return {'orderId': data['order']?['id'], 'orderData': data};
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถสร้างคำสั่งซื้อได้');
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
      return null;
    }
  }

  Future<void> _showQRPayment() async {
    try {
      // สร้าง order ก่อน
      final orderData = await _createOrderAndGetId();
      if (orderData == null || orderData['orderId'] == null) {
        throw Exception('ไม่สามารถสร้างคำสั่งซื้อได้');
      }

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
            _showQRCodeModal(qrCode, orderId: orderData['orderId']);
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

  void _showQRCodeModal(Map<String, dynamic> qrCode, {int? orderId}) {
    File? selectedImage;
    String? imageBase64;
    bool isUploading = false;
    // สำหรับแสดงภาพสลิปแบบเต็มหน้าจอ
    void showSlipFullscreen(File imageFile) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.black.withOpacity(0.6),
            insetPadding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: Image.file(imageFile, fit: BoxFit.contain),
              ),
            ),
          );
        },
      );
    }

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
                    borderRadius: BorderRadius.circular(
                      16,
                    ), // ปรับขอบมนเป็น 16px
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
                      // Header แบบ AppBar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
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
                                fontSize: 18,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const ThankYouScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('จ่ายภายหลัง'),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // QR Code Image
                              Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: buildProductImageWidget(
                                    qrCode['imageUrl'],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Account Info
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
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
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(qrCode['bankName'] ?? ''),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Price Info
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
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
                                      '฿${(_priceCalculation!['total'] ?? 0).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'กรุณาสแกน QR Code เพื่อชำระเงิน\nหลังจากชำระเงินแล้วกดปุ่ม "อัปโหลดหลักฐานการชำระเงิน"',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              // เลือกไฟล์สลิป
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
                                      ? 'เลือกไฟล์สลิป'
                                      : 'เปลี่ยนไฟล์สลิป',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              if (selectedImage != null) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap:
                                      () => showSlipFullscreen(selectedImage!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      selectedImage!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // ปุ่มยืนยันอัปโหลด
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
                                            final data = jsonDecode(
                                              response.body,
                                            );
                                            if (response.statusCode == 200 ||
                                                response.statusCode == 201) {
                                              if (mounted) {
                                                // ScaffoldMessenger.of(
                                                //   context,
                                                // ).showSnackBar(
                                                //   // SnackBar(
                                                //   //   content: Text(
                                                //   //     data['msg'] ??
                                                //   //         'อัปโหลดสลิปสำเร็จ',
                                                //   //   ),
                                                //   //   backgroundColor:
                                                //   //       Colors.green,
                                                //   // ),
                                                // );
                                                Navigator.of(context)
                                                    .pushAndRemoveUntil(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ThankYouScreen(
                                                      orderId:
                                                          orderId, // pass orderId
                                                    ),
                                                  ),
                                                  (route) => false,
                                                );
                                              }
                                            } else {
                                              throw Exception(
                                                data['msg'] ??
                                                    'อัปโหลดสลิปไม่สำเร็จ',
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child:
                                    isUploading
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Text('ยืนยันการอัปโหลด'),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'หลังอัปโหลดสลิปรอการตรวจสอบจากร้านค้า',
                                style: TextStyle(color: Colors.grey),
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

  void _showAddressSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'เลือกที่อยู่จัดส่ง',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    final isSelected = _selectedAddress?['id'] == address['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Radio<int>(
                          value: address['id'],
                          groupValue: _selectedAddress?['id'],
                          onChanged: (value) {
                            setState(() {
                              _selectedAddress = address;
                            });
                            Navigator.pop(context);
                            _calculatePrice();
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                        title: Text(
                          address['fullName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('โทร: ${address['phone'] ?? ''}'),
                            const SizedBox(height: 4),
                            Text(
                              '${address['address'] ?? ''}\n'
                              '${address['subdistrict']?['name'] ?? ''} '
                              '${address['district']?['name'] ?? ''} '
                              '${address['province']?['name'] ?? ''}',
                            ),
                            if (address['isDefault'] == true)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ที่อยู่หลัก',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedAddress = address;
                          });
                          Navigator.pop(context);
                          _calculatePrice();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressCard() {
    // If there are no addresses at all, show CTA to add one
    if (_addresses.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(child: Text('ยังไม่มีที่อยู่จัดส่ง')),
              ElevatedButton(
                onPressed: () async {
                  // Navigate to address list/add screen and wait for return
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ListAddressScreen()),
                  );
                  // After returning, reload addresses and recalculate price if an address was selected
                  await _loadAddresses();
                  if (_selectedAddress != null) {
                    await _calculatePrice();
                  }
                },
                child: const Text('เพิ่มที่อยู่จัดส่ง'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedAddress == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(child: Text('กรุณาเลือกที่อยู่จัดส่ง')),
              TextButton(
                onPressed: _showAddressSelection,
                child: const Text('เลือก'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ที่อยู่จัดส่ง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _showAddressSelection,
                  child: const Text('เปลี่ยน'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _selectedAddress!['fullName'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_selectedAddress!['phone'] ?? ''),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedAddress!['address'] ?? ''}\n'
                    '${_selectedAddress!['subdistrict']?['name'] ?? ''} '
                    '${_selectedAddress!['district']?['name'] ?? ''} '
                    '${_selectedAddress!['province']?['name'] ?? ''}',
                  ),
                ),
              ],
            ),
            if (_selectedAddress!['isDefault'] == true)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ที่อยู่หลัก',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สรุปคำสั่งซื้อ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Selected Items
            ...widget.selectedItems.map((item) {
              final product = item['product'];
              final quantity = item['quantity'] ?? 1;
              final price =
                  (product['salePrice'] ?? product['price'] ?? 0).toDouble();
              final options = item['options'] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Product Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child:
                          product['images']?.isNotEmpty == true
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: buildProductImageWidget(
                                  product['images'][0]['url'],
                                  fit: BoxFit.cover,
                                ),
                              )
                              : const Icon(Icons.image_not_supported),
                    ),
                    const SizedBox(width: 12),

                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (options.isNotEmpty)
                            ...options.map(
                              (option) => Text(
                                '${option['productOption']['type']}: ${option['productOption']['value']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          Text(
                            '฿${price.toStringAsFixed(0)} x $quantity',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      '฿${(price * quantity).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildPriceBreakdown() {
    if (_priceCalculation == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              _isLoadingPrice
                  ? const Center(child: CircularProgressIndicator())
                  : const Text('กำลังคำนวณราคา...'),
        ),
      );
    }

    final productTotal = (_priceCalculation!['productTotal'] ?? 0).toDouble();
    final shipping = (_priceCalculation!['shipping'] ?? 0).toDouble();
    final total = (_priceCalculation!['total'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายละเอียดการชำระเงิน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ราคาสินค้า'),
                Text('฿${productTotal.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ค่าจัดส่ง'),
                Text(
                  shipping == 0 ? 'ฟรี' : '฿${shipping.toStringAsFixed(0)}',
                  style: TextStyle(
                    color:
                        shipping == 0
                            ? Colors.green
                            : AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ยอดรวมทั้งสิ้น',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '฿${total.toStringAsFixed(0)}',
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
    );
  }

  Widget _buildPaymentMethod() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'วิธีการชำระเงิน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Cash on Delivery Option
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      _selectedPaymentType == 1
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                  width: _selectedPaymentType == 1 ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Radio<int>(
                  value: 1,
                  groupValue: _selectedPaymentType,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentType = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                title: const Row(
                  children: [
                    Icon(Icons.money, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'เก็บเงินปลายทาง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'ชำระเงินเมื่อได้รับสินค้า',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    _selectedPaymentType = 1;
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // QR Code Payment Option
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      _selectedPaymentType == 2
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                  width: _selectedPaymentType == 2 ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Radio<int>(
                  value: 2,
                  groupValue: _selectedPaymentType,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentType = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                title: const Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'ชำระผ่าน QR Code',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'สแกน QR Code เพื่อชำระเงิน',
                  style: TextStyle(fontSize: 12),
                ),
                trailing:
                    _selectedPaymentType == 2
                        ? const Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                        )
                        : null,
                onTap: () {
                  setState(() {
                    _selectedPaymentType = 2;
                  });
                },
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
        title: const Text(
          'สรุปคำสั่งซื้อ',
          style: TextStyle(color: AppTheme.primaryWhite),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: AppTheme.primaryWhite),
      ),
      body:
          _isLoadingAddresses
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
                      onPressed: _initializeData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: AppTheme.primaryWhite,
                      ),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildAddressCard(),
                          _buildOrderSummary(),
                          _buildPaymentMethod(),
                          _buildPriceBreakdown(),
                        ],
                      ),
                    ),
                  ),

                  // Checkout Button
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
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedAddress != null &&
                                  _priceCalculation != null &&
                                  !_isCreatingOrder
                              ? () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('ยืนยันคำสั่งซื้อ'),
                                      content: const Text(
                                        'คุณต้องการยืนยันการสั่งซื้อนี้หรือไม่?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: const Text('ยกเลิก'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            foregroundColor:
                                                AppTheme.primaryWhite,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                          child: const Text('ยืนยัน'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await _createOrder();
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: AppTheme.primaryWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isCreatingOrder
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    _priceCalculation != null
                                        ? '${_selectedPaymentType == 1 ? 'สั่งซื้อ' : 'ชำระเงิน'} ฿${(_priceCalculation!['total'] ?? 0).toStringAsFixed(0)}'
                                        : 'กำลังคำนวณราคา...',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
