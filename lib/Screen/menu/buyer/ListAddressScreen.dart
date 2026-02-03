import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/Screen/menu/buyer/AddAddressScreen.dart';
import 'package:rps_app/Screen/menu/buyer/EditAddressScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ListAddressScreen extends StatefulWidget {
  const ListAddressScreen({super.key});

  @override
  State<ListAddressScreen> createState() => _ListAddressScreenState();
}

class _ListAddressScreenState extends State<ListAddressScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

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
        setState(() {
          _isLoading = false;
          _error = 'กรุณาเข้าสู่ระบบ';
        });
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listUserAddress),
        headers: headers,
        body: jsonEncode({
          'accountId': accountId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _addresses = List<Map<String, dynamic>>.from(data['addresses'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['msg'] ?? 'ไม่สามารถโหลดข้อมูลที่อยู่ได้';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultAddress(int addressId) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.setDefaultAddress),
        headers: headers,
        body: jsonEncode({
          'accountId': accountId,
          'addressId': addressId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('ตั้งเป็นที่อยู่หลักแล้ว'),
          //     backgroundColor: Colors.green,
          //   ),
          // );
          _loadAddresses(); // Reload data
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถตั้งเป็นที่อยู่หลักได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _deleteAddress(int addressId) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.deleteUserAddress),
        headers: headers,
        body: jsonEncode({
          'addressId': addressId,
          'accountId': accountId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('ลบที่อยู่แล้ว'),
          //     backgroundColor: Colors.green,
          //   ),
          // );
          _loadAddresses(); // Reload data
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถลบที่อยู่ได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddAddressScreen(),
      ),
    );
    
    // If address was added successfully, reload the list
    if (result == true) {
      _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          localizations?.address ?? 'ที่อยู่',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error,
                          size: 80,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.errorColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadAddresses,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          child: const Text(
                            'ลองอีกครั้ง',
                            style: TextStyle(color: AppTheme.primaryWhite),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAddresses,
                    color: AppTheme.primaryColor,
                    child: _addresses.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _addresses.length,
                            itemBuilder: (context, index) {
                              final address = _addresses[index];
                              return _buildAddressCard(address);
                            },
                          ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAddress,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(
          Icons.add,
          color: AppTheme.primaryWhite,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.location_off,
                size: 80,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 20),
              const Text(
                'ยังไม่มีที่อยู่',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'เพิ่มที่อยู่เพื่อจัดส่งสินค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _addNewAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.primaryWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มที่อยู่'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final isDefault = address['isDefault'] ?? false;
    final fullName = address['fullName'] ?? '';
    final phone = address['phone'] ?? '';
    final addressText = address['address'] ?? '';
    final province = address['province']?['name'] ?? '';
    final district = address['district']?['name'] ?? '';
    final subdistrict = address['subdistrict']?['name'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and default badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ที่อยู่หลัก',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Phone
            Row(
              children: [
                const Icon(
                  Icons.phone,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$addressText\n$subdistrict, $district, $province',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                if (!isDefault)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _setDefaultAddress(address['id']),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.home,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      label: Text(
                        'ตั้งเป็นหลัก',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                if (!isDefault) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditAddressScreen(address: address),
                        ),
                      );
                      
                      // Reload data if address was updated
                      if (result == true) {
                        _loadAddresses();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.edit,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    label: const Text(
                      'แก้ไข',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showDeleteDialog(address['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete,
                    size: 16,
                    color: AppTheme.errorColor,
                  ),
                  label: const Text(
                    'ลบ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorColor,
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

  void _showDeleteDialog(int addressId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ลบที่อยู่'),
          content: const Text('คุณต้องการลบที่อยู่นี้หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAddress(addressId);
              },
              child: const Text(
                'ลบ',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        );
      },
    );
  }
}
