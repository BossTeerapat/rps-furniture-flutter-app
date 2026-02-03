import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import '../../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
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
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('รหัสผ่านใหม่และยืนยันรหัสผ่านไม่ตรงกัน'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final headers = await ApiConfig.buildHeaders();
      final body = jsonEncode({
        'accountId': _accountId,
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      });
      final resp = await http.post(Uri.parse(ApiConfig.updateProfile), headers: headers, body: body);
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200 && data['status'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['msg'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ'), backgroundColor: AppTheme.successColor),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception(data['msg'] ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
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
        title: const Text('เปลี่ยนรหัสผ่าน'),
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
                  child: const Icon(Icons.lock_outline, size: 48, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
                validator: (val) => val == null || val.isEmpty ? 'กรุณากรอกรหัสผ่านใหม่' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  prefixIcon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
                validator: (val) => val == null || val.isEmpty ? 'กรุณายืนยันรหัสผ่านใหม่' : null,
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
                  onPressed: _isLoading ? null : _updatePassword,
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
