import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import '../../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  int? _accountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountId = prefs.getInt('user_id');
      _firstnameController.text = prefs.getString('firstname') ?? '';
      _lastnameController.text = prefs.getString('lastname') ?? '';
      _phoneController.text = prefs.getString('phone') ?? '';
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      final headers = await ApiConfig.buildHeaders();
      final body = jsonEncode({
        'accountId': _accountId,
        'firstname': _firstnameController.text,
        'lastname': _lastnameController.text,
        'phone': _phoneController.text,
      });
      final resp = await http.post(Uri.parse(ApiConfig.updateProfile), headers: headers, body: body);
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200 && data['status'] == 200) {
        // Update shared_preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('firstname', _firstnameController.text);
        await prefs.setString('lastname', _lastnameController.text);
        await prefs.setString('phone', _phoneController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['msg'] ?? 'อัปเดตโปรไฟล์สำเร็จ'), backgroundColor: AppTheme.successColor),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pop(true);
          });
        }
      } else {
        throw Exception(data['msg'] ?? 'อัปเดตโปรไฟล์ไม่สำเร็จ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 48, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstnameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อจริง',
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกชื่อจริง' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastnameController,
                decoration: InputDecoration(
                  labelText: 'นามสกุล',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกนามสกุล' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _updateProfile,
                  label: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('บันทึกการเปลี่ยนแปลง', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
