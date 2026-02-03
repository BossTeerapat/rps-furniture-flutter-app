import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic> address;

  const EditAddressScreen({super.key, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isDefault = false;

  // Location data
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subdistricts = [];

  int? _selectedProvinceId;
  int? _selectedDistrictId;
  int? _selectedSubdistrictId;

  String? _selectedProvinceName;
  String? _selectedDistrictName;
  String? _selectedSubdistrictName;

  bool _isLoadingProvinces = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingSubdistricts = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadProvinces();
  }

  void _initializeData() {
    // Initialize form fields with existing data
    _fullNameController.text = widget.address['fullName'] ?? '';
    _phoneController.text = widget.address['phone'] ?? '';
    _addressController.text = widget.address['address'] ?? '';
    _isDefault = widget.address['isDefault'] ?? false;

    // Initialize location data
    _selectedProvinceId = widget.address['provinceId'];
    _selectedDistrictId = widget.address['districtId'];
    _selectedSubdistrictId = widget.address['subdistrictId'];

    _selectedProvinceName = widget.address['province']?['name'];
    _selectedDistrictName = widget.address['district']?['name'];
    _selectedSubdistrictName = widget.address['subdistrict']?['name'];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _isLoadingProvinces = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listLocation),
        headers: headers,
        body: jsonEncode({'type': 'provinces'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _provinces = List<Map<String, dynamic>>.from(
              data['provinces'] ?? [],
            );
          });

          // Auto-load districts if province is already selected
          if (_selectedProvinceId != null) {
            _loadDistricts(_selectedProvinceId!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดจังหวัด: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() {
      _isLoadingProvinces = false;
    });
  }

  Future<void> _loadDistricts(int provinceId) async {
    setState(() {
      _isLoadingDistricts = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listLocation),
        headers: headers,
        body: jsonEncode({'type': 'districts', 'provinceId': provinceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _districts = List<Map<String, dynamic>>.from(
              data['districts'] ?? [],
            );
          });

          // Auto-load subdistricts if district is already selected
          if (_selectedDistrictId != null) {
            _loadSubdistricts(_selectedDistrictId!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดอำเภอ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() {
      _isLoadingDistricts = false;
    });
  }

  Future<void> _loadSubdistricts(int districtId) async {
    setState(() {
      _isLoadingSubdistricts = true;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.listLocation),
        headers: headers,
        body: jsonEncode({'type': 'subdistricts', 'districtId': districtId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          setState(() {
            _subdistricts = List<Map<String, dynamic>>.from(
              data['subdistricts'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดตำบล: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() {
      _isLoadingSubdistricts = false;
    });
  }

  Future<void> _updateAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProvinceId == null ||
        _selectedDistrictId == null ||
        _selectedSubdistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกจังหวัด อำเภอ และตำบล'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
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
        Uri.parse(ApiConfig.editUserAddress),
        headers: headers,
        body: jsonEncode({
          'addressId': widget.address['id'],
          'accountId': accountId,
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'provinceId': _selectedProvinceId,
          'districtId': _selectedDistrictId,
          'subdistrictId': _selectedSubdistrictId,
          'isDefault': _isDefault,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          if (mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('แก้ไขที่อยู่สำเร็จ'),
            //     backgroundColor: Colors.green,
            //   ),
            // );
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถแก้ไขที่อยู่ได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'แก้ไขที่อยู่',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Full Name
              _buildInputCard(
                title: 'ชื่อ-นามสกุล',
                child: TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'กรุณาใส่ชื่อ-นามสกุล',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณาใส่ชื่อ-นามสกุล';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Phone
              _buildInputCard(
                title: 'เบอร์โทรศัพท์',
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    hintText: 'กรุณาใส่เบอร์โทรศัพท์',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณาใส่เบอร์โทรศัพท์';
                    }
                    if (value.length < 10) {
                      return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Address
              _buildInputCard(
                title: 'ที่อยู่',
                child: TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'กรุณาใส่ที่อยู่ เช่น เลขที่ หมู่บ้าน ถนน',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณาใส่ที่อยู่';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Province Dropdown
              _buildLocationCard(
                title: 'จังหวัด',
                isLoading: _isLoadingProvinces,
                selectedValue: _selectedProvinceName,
                hintText: 'เลือกจังหวัด',
                onTap: () => _showProvinceSelector(),
              ),

              const SizedBox(height: 16),

              // District Dropdown
              _buildLocationCard(
                title: 'อำเภอ',
                isLoading: _isLoadingDistricts,
                selectedValue: _selectedDistrictName,
                hintText: 'เลือกอำเภอ',
                onTap:
                    _selectedProvinceId != null
                        ? () => _showDistrictSelector()
                        : null,
              ),

              const SizedBox(height: 16),

              // Subdistrict Dropdown
              _buildLocationCard(
                title: 'ตำบล',
                isLoading: _isLoadingSubdistricts,
                selectedValue: _selectedSubdistrictName,
                hintText: 'เลือกตำบล',
                onTap:
                    _selectedDistrictId != null
                        ? () => _showSubdistrictSelector()
                        : null,
              ),

              const SizedBox(height: 16),

              // Default Address Switch
              _buildInputCard(
                title: 'ตั้งเป็นที่อยู่หลัก',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ตั้งเป็นที่อยู่หลักสำหรับการจัดส่ง',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.primaryWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryWhite,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'บันทึกการแก้ไข',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required bool isLoading,
    required String? selectedValue,
    required String hintText,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color:
                      onTap == null ? Colors.grey[100] : AppTheme.primaryWhite,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                selectedValue ?? hintText,
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      selectedValue != null
                                          ? AppTheme.textPrimaryColor
                                          : AppTheme.textSecondaryColor,
                                ),
                              ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color:
                          onTap != null
                              ? AppTheme.textSecondaryColor
                              : Colors.grey[400],
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

  void _showProvinceSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'เลือกจังหวัด',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _provinces.length,
                  itemBuilder: (context, index) {
                    final province = _provinces[index];
                    return ListTile(
                      title: Text(province['name']),
                      onTap: () {
                        setState(() {
                          _selectedProvinceId = province['id'];
                          _selectedProvinceName = province['name'];
                          // Reset dependent selections
                          _selectedDistrictId = null;
                          _selectedSubdistrictId = null;
                          _selectedDistrictName = null;
                          _selectedSubdistrictName = null;
                          _districts = [];
                          _subdistricts = [];
                        });
                        Navigator.pop(context);
                        _loadDistricts(province['id']);
                      },
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

  void _showDistrictSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'เลือกอำเภอ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _districts.length,
                  itemBuilder: (context, index) {
                    final district = _districts[index];
                    return ListTile(
                      title: Text(district['name']),
                      onTap: () {
                        setState(() {
                          _selectedDistrictId = district['id'];
                          _selectedDistrictName = district['name'];
                          // Reset dependent selections
                          _selectedSubdistrictId = null;
                          _selectedSubdistrictName = null;
                          _subdistricts = [];
                        });
                        Navigator.pop(context);
                        _loadSubdistricts(district['id']);
                      },
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

  void _showSubdistrictSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'เลือกตำบล',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _subdistricts.length,
                  itemBuilder: (context, index) {
                    final subdistrict = _subdistricts[index];
                    return ListTile(
                      title: Text(subdistrict['name']),
                      onTap: () {
                        setState(() {
                          _selectedSubdistrictId = subdistrict['id'];
                          _selectedSubdistrictName = subdistrict['name'];
                        });
                        Navigator.pop(context);
                      },
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
}
