import 'package:flutter/material.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/RegisterScreen.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Prepare request body
        final body = {
          "username": _usernameController.text.trim(),
          "password": _passwordController.text,
        };

        // Get headers
        final headers = await ApiConfig.buildHeaders();

        // Make API call
        final response = await http.post(
          Uri.parse(ApiConfig.loginApp),
          headers: headers,
          body: json.encode(body),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            
            // Save user data to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', responseData['user']['id']); // เก็บเป็น int
            await prefs.setString('firstname', responseData['user']['firstname']);
            await prefs.setString('lastname', responseData['user']['lastname']);
            await prefs.setString('phone', responseData['user']['phone']);
            await prefs.setString('username', responseData['user']['username']);
            await prefs.setString('role', responseData['user']['role']['name']);
            await prefs.setBool('isLoggedIn', true); // เพิ่มสถานะ login
            
            // Show success message
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(responseData['msg'] ?? 'เข้าสู่ระบบสำเร็จ'),
            //     backgroundColor: Colors.green,
            //   ),
            // );

            // Navigate back with success result
            Navigator.pop(context, true);
            
          } else {
            // Handle error
            final responseData = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['msg'] ?? 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'),
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          localizations?.login ?? 'เข้าสู่ระบบ',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo or Brand Name
                  Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.chair,
                            size: 60,
                            color: AppTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'รุ่งประเสริฐเฟอร์นิเจอร์',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations?.login ?? 'เข้าสู่ระบบ',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: localizations?.username ?? 'ชื่อผู้ใช้',
                      hintText: localizations?.usernameHint ?? 'กรอกชื่อผู้ใช้ของคุณ',
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
                        return localizations?.usernameRequired ?? 'กรุณากรอกชื่อผู้ใช้';
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
                      labelText: localizations?.password ?? 'รหัสผ่าน',
                      hintText:
                          localizations?.passwordHint ?? 'กรอกรหัสผ่านของคุณ',
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
                        return localizations?.passwordRequired ??
                            'กรุณากรอกรหัสผ่าน';
                      }
                      if (value.length < 8) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ฟีเจอร์นี้จะเปิดใช้งานเร็วๆ นี้'),
                          ),
                        );
                      },
                      child: Text(
                        localizations?.forgotPassword ?? 'ลืมรหัสผ่าน?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                              localizations?.login ?? 'เข้าสู่ระบบ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),

                  const SizedBox(height: 16),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localizations?.noAccount ?? 'ยังไม่มีบัญชี?',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          localizations?.register ?? 'สมัครสมาชิก',
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
