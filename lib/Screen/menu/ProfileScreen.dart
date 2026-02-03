import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Service/API_Config.dart';
import '../../theme/app_theme.dart';
import './UpdateProfileScreen.dart';
import './UpdatePasswordScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getInt('user_id');

      if (accountId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final headers = await ApiConfig.buildHeaders();
      final body = {"accountId": accountId};

      final response = await http.post(
        Uri.parse(ApiConfig.profileDetail),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['user'] != null) {
          setState(() {
            _userProfile = data['user'];
            _isLoading = false;
          });
        } else {
          throw Exception(data['msg'] ?? 'ไม่สามารถโหลดข้อมูลได้');
        }
      } else {
        throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UpdateProfileScreen()),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userProfile == null
              ? _buildErrorState()
              : _buildProfileContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'ไม่สามารถโหลดข้อมูลโปรไฟล์ได้',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final user = _userProfile!;
    final addresses = List<Map<String, dynamic>>.from(user['addresses'] ?? []);
    final defaultAddress = addresses.isNotEmpty
        ? addresses.firstWhere(
            (addr) => addr['isDefault'] == true,
            orElse: () => addresses[0],
          )
        : null;
    final counts = user['_count'] ?? {};
    final role = user['role']?['name'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user['username'] ?? ''}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role == 'buyer'
                        ? 'ลูกค้า'
                        : role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Statistics Cards (show only for buyer)
          if (role == 'buyer')
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'คำสั่งซื้อ',
                    '${counts['orders'] ?? 0}',
                    Icons.shopping_bag_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'รีวิว',
                    '${counts['reviews'] ?? 0}',
                    Icons.star_outline,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'ถูกใจ',
                    '${counts['Favorite'] ?? 0}',
                    Icons.favorite_outline,
                    Colors.red,
                  ),
                ),
              ],
            ),

          if (role == 'buyer') const SizedBox(height: 20),

          // Personal Information
          _buildInfoSection('ข้อมูลส่วนตัว', [
            _buildInfoItem(
              'ชื่อ',
              '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim(),
            ),
            _buildInfoItem('ชื่อผู้ใช้', user['username'] ?? ''),
            _buildInfoItem('เบอร์โทรศัพท์', user['phone'] ?? ''),
          ]),

          const SizedBox(height: 20),

          // Default Address
          if (defaultAddress != null)
            _buildInfoSection('ที่อยู่หลัก', [
              _buildInfoItem('ชื่อผู้รับ', defaultAddress['fullName'] ?? ''),
              _buildInfoItem('เบอร์โทรศัพท์', defaultAddress['phone'] ?? ''),
              _buildInfoItem(
                'ที่อยู่',
                '${defaultAddress['address'] ?? ''}\n'
                    '${defaultAddress['subdistrict']?['name'] ?? ''} '
                    '${defaultAddress['district']?['name'] ?? ''} '
                    '${defaultAddress['province']?['name'] ?? ''}',
              ),
            ]),

          const SizedBox(height: 20),

          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdatePasswordScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text(
                    'เปลี่ยนรหัสผ่าน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
