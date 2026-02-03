import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  final String? title;
  const RegisterScreen({super.key, this.title});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  // password strength: 0 = none/invalid, 1..4 levels
  int _passwordStrength = 0;
  bool _isConfirmMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  _confirmPasswordController.addListener(_onConfirmChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
  _confirmPasswordController.removeListener(_onConfirmChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final pw = _passwordController.text;
    final strength = _calculatePasswordStrength(pw);
    if (mounted) {
      setState(() {
        _passwordStrength = strength;
        _isConfirmMatch = _confirmPasswordController.text.isNotEmpty && _confirmPasswordController.text == pw;
      });
    }
  }

  void _onConfirmChanged() {
    final confirm = _confirmPasswordController.text;
    if (mounted) {
      setState(() {
        _isConfirmMatch = confirm.isNotEmpty && confirm == _passwordController.text;
      });
    }
  }

  int _calculatePasswordStrength(String pw) {
  if (pw.isEmpty) return 0;
  final hasDigits = RegExp(r'\d').hasMatch(pw);
  final hasLower = RegExp(r'[a-z]').hasMatch(pw);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(pw);
  final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);

  // Count how many of the 4 categories are present
  int count = 0;
  if (hasDigits) count += 1;
  if (hasLower) count += 1;
  if (hasUpper) count += 1;
  if (hasSpecial) count += 1;

  // return 0 if none matched, otherwise 1..4
  return count;
  }

  Color _colorForStrength(int level) {
    switch (level) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  String _labelForStrength(int level) {
    switch (level) {
      case 1:
        return 'อ่อนมาก';
      case 2:
        return 'อ่อน';
      case 3:
        return 'ปานกลาง';
      case 4:
        return 'แข็งแรง';
      default:
        return 'กรุณากรอกรหัสผ่านที่มีตัวเลข';
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Prepare request body
        final body = {
          "firstname": _firstNameController.text.trim(),
          "lastname": _lastNameController.text.trim(),
          "phone": _phoneController.text.trim(),
          "username": _usernameController.text.trim(),
          "password": _passwordController.text,
        };

        // Get headers
        final headers = await ApiConfig.buildHeaders();

        // Make API call
        final response = await http.post(
          Uri.parse(ApiConfig.register),
          headers: headers,
          body: json.encode(body),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['msg'] ?? 'สมัครสมาชิกสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate back to login
            Navigator.pop(context);
          } else {
            // Handle error
            final responseData = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['msg'] ?? 'เกิดข้อผิดพลาด'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCheckItem(bool ok, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.green : AppTheme.textSecondaryColor,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ok ? Colors.green : AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title ?? localizations?.register ?? 'สมัครสมาชิก',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Logo or Brand Name
                  Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            size: 40,
                            color: AppTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations?.register ?? 'สมัครสมาชิก',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // First Name Field
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ',
                      hintText: 'กรอกชื่อจริง',
                      prefixIcon: Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกชื่อ';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Last Name Field
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'นามสกุล',
                      hintText: 'กรอกนามสกุล',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกนามสกุล';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทรศัพท์',
                      hintText: 'กรอกเบอร์โทรศัพท์',
                      prefixIcon: Icon(
                        Icons.phone,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกเบอร์โทรศัพท์';
                      }
                      if (value.length < 10) {
                        return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'username',
                      hintText: 'กรอก username',
                      prefixIcon: Icon(
                        Icons.account_circle,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกชื่อผู้ใช้';
                      }
                      if (value.length < 4) {
                        return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 4 ตัวอักษร';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "password",
                      hintText: 'กรอกรหัสผ่าน',
                      prefixIcon: Icon(
                        Icons.lock,
                        color: AppTheme.primaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppTheme.textSecondaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกรหัสผ่าน';
                      }
                      if (value.length < 8) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                      }
                      if (_passwordStrength < 3) {
                        return 'รหัสผ่านต้องมีความปลอดภัยอย่างน้อยระดับปานกลาง';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),
                  // Password strength indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(4, (i) {
                          final level = i + 1;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                              height: 6,
                              decoration: BoxDecoration(
                                color: _passwordStrength >= level
                                    ? _colorForStrength(level)
                                    : AppTheme.textSecondaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _labelForStrength(_passwordStrength),
                        style: TextStyle(
                          color: _passwordStrength > 0
                              ? _colorForStrength(_passwordStrength)
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                      // checklist for categories
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCheckItem(_passwordController.text.contains(RegExp(r'\d')), 'ตัวเลข'),
                          const SizedBox(width: 8),
                          _buildCheckItem(_passwordController.text.contains(RegExp(r'[a-z]')), 'พิมพ์เล็ก'),
                          const SizedBox(width: 8),
                          _buildCheckItem(_passwordController.text.contains(RegExp(r'[A-Z]')), 'พิมพ์ใหญ่'),
                          const SizedBox(width: 8),
                          _buildCheckItem(_passwordController.text.contains(RegExp(r'[^A-Za-z0-9]')), 'ตัวพิเศษ'),
                        ],
                      ),
                      if (_passwordController.text.length < 8)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            'คำเตือน: รหัสผ่านควรมีอย่างน้อย 8 ตัวอักษรเพื่อความปลอดภัยสูงสุด',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'ยืนยันรหัสผ่าน',
                      hintText: 'กรอกรหัสผ่านอีกครั้ง',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppTheme.primaryColor,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isConfirmMatch)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppTheme.textSecondaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryWhite,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณายืนยันรหัสผ่าน';
                      }
                      if (value != _passwordController.text) {
                        return 'รหัสผ่านไม่ตรงกัน';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Register Button
                  ElevatedButton(
                    onPressed: (_isLoading || _passwordStrength < 3) ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.primaryWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryWhite,
                                ),
                              ),
                            )
                            : Text(
                              localizations?.register ?? 'สมัครสมาชิก',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),

                  const SizedBox(height: 16),

                  // Back to Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'มีบัญชีแล้ว?',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          localizations?.login ?? 'เข้าสู่ระบบ',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
