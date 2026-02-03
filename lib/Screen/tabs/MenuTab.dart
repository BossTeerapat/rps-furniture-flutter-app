import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rps_app/Screen/menu/admin/QRCodeScreen.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/providers/language_provider.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/LoginScreen.dart';
import 'package:rps_app/Screen/menu/buyer/ListAddressScreen.dart';
import 'package:rps_app/Screen/menu/ProfileScreen.dart';
import 'package:rps_app/Screen/menu/admin/ManageProductsScreen.dart';
import 'package:rps_app/Screen/menu/buyer/HistoryOrderScreen.dart';
import 'package:rps_app/Screen/menu/buyer/ReviewHistoryScreen.dart';
import 'package:rps_app/Screen/menu/ContactUsScreen.dart';
import 'package:rps_app/Screen/menu/PoliciesScreen.dart';
import 'package:rps_app/Screen/menu/admin/StockProductScreen.dart';
import 'package:rps_app/Screen/menu/admin/ListAccountScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RoleChangedCallback = void Function();

class MenuTab extends StatefulWidget {
  final RoleChangedCallback? onRoleChanged;
  const MenuTab({super.key, this.onRoleChanged});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  String? _firstname;
  String? _lastname;
  String? _username;
  bool _isLoggedIn = false;
  String? _previousRole;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // โหลดข้อมูล user ทุกครั้งที่เข้าหน้า MenuTab เพื่อให้แสดงข้อมูลล่าสุด
    _loadUserData();
  }

  Future<void> _loadUserData({bool checkRoleChange = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? currentRole = prefs.getString('role');
    setState(() {
      _firstname = prefs.getString('firstname');
      _lastname = prefs.getString('lastname');
      _username = prefs.getString('username');
      _isLoggedIn = _firstname != null && _lastname != null;
      _role = currentRole;
    });
    // แจ้ง MainScreen เฉพาะเมื่อ role เปลี่ยนแปลงจริงๆ
    if (checkRoleChange && widget.onRoleChanged != null) {
      if (_previousRole != currentRole) {
        _previousRole = currentRole;
        widget.onRoleChanged!();
      }
    } else {
      _previousRole = currentRole;
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ลบข้อมูลทั้งหมด

    setState(() {
      _firstname = null;
      _lastname = null;
      _username = null;
      _isLoggedIn = false;
    });

    // แจ้ง MainScreen ให้เปลี่ยน tab เป็น buyer หลัง logout
    if (widget.onRoleChanged != null) {
      _previousRole = null; // รีเซ็ต previous role
      widget.onRoleChanged!();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ออกจากระบบเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // สร้างเมนูตาม role
    List<Widget> menuSections = [];

    // User Profile Card (เหมือนเดิม)
    menuSections.add(
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(
                Icons.person,
                size: 35,
                color: AppTheme.primaryWhite,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoggedIn
                        ? '${_firstname ?? ''} ${_lastname ?? ''}'.trim()
                        : 'ผู้เยี่ยมชม',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoggedIn
                        ? _username ?? ''
                        : 'เข้าสู่ระบบเพื่อใช้งาน',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoggedIn)
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                  if (result == true) {
                    await _loadUserData(checkRoleChange: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.primaryWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  minimumSize: const Size(80, 36),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.login,
                      size: 16,
                      color: AppTheme.primaryWhite,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      localizations?.login ?? 'เข้าสู่ระบบ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    menuSections.add(const SizedBox(height: 20));

    // เมนูสำหรับ admin
    if (_role == 'admin') {
      menuSections.add(
        _buildMenuSection(
          title: 'บัญชีผู้ดูแล',
          items: [
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'โปรไฟล์',
              subtitle: 'จัดการข้อมูลส่วนตัว',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'จัดการสินค้า',
          items: [
            _buildMenuItem(
              icon: Icons.add_box_outlined,
              title: 'จัดการสินค้า',
              subtitle: 'เพิ่ม/ลบ/แก้ไขสินค้า',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageProductsScreen(),
                  ),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.edit,
              title: 'คลังสินค้า',
              subtitle: 'ดูสต๊อกสินค้า',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StockProductScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'จัดการบัญชี',
          items: [
            _buildMenuItem(
              icon: Icons.people_outline,
              title: 'บัญชีพนักงาน',
              subtitle: 'จัดการบัญชีพนักงาน',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            const ListAccountScreen(action: 'employee'),
                  ),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.people_outline,
              title: 'บัญชีลูกค้า',
              subtitle: 'จัดการบัญชีลูกค้า',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const ListAccountScreen(action: 'buyer'),
                  ),
                );
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'การชำระเงิน',
          items: [
            _buildMenuItem(
              icon: Icons.qr_code,
              title: 'Qr Code',
              subtitle: 'อัปโหลด QR Code ของร้านค้า',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentQRCodeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'ตั้งค่า',
          items: [
            _buildMenuItem(
              icon: Icons.language,
              title: 'ภาษา',
              subtitle: 'เปลี่ยนภาษาแอป',
              onTap: () {
                _showLanguageDialog(context);
              },
            ),
            _buildMenuItem(
              icon: Icons.security_outlined,
              title: 'ช่วยเหลือ',
              subtitle: 'ช่วยเหลือเกี่ยวกับแอป',
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('กำลังพัฒนา'),
                        content: const Text(
                          'ฟีเจอร์นี้กำลังอยู่ระหว่างการพัฒนา',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('ตกลง'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      );
    }
    // เมนูสำหรับ employee
    else if (_role == 'employee') {
      menuSections.add(
        _buildMenuSection(
          title: 'บัญชีพนักงาน',
          items: [
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'โปรไฟล์',
              subtitle: 'จัดการข้อมูลส่วนตัว',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'ประวัติการส่งของ',
          items: [
            _buildMenuItem(
              icon: Icons.history,
              title: 'ประวัติการส่งของ',
              subtitle: 'ดูประวัติการส่งของทั้งหมด',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                int? empId = prefs.getInt('user_id');
                if (empId == null) {
                  final s = prefs.getString('user_id');
                  if (s != null && s.isNotEmpty) empId = int.tryParse(s);
                }
                if (empId == null) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ไม่พบรหัสพนักงาน')),
                    );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => HistoryOrderScreen(
                          employeeMode: true,
                          employeeId: empId,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: 'ตั้งค่า',
          items: [
            _buildMenuItem(
              icon: Icons.language,
              title: 'ภาษา',
              subtitle: 'เปลี่ยนภาษาแอป',
              onTap: () {
                _showLanguageDialog(context);
              },
            ),
            _buildMenuItem(
              icon: Icons.security_outlined,
              title: 'ช่วยเหลือ',
              subtitle: 'ช่วยเหลือเกี่ยวกับแอป',
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('กำลังพัฒนา'),
                        content: const Text(
                          'ฟีเจอร์นี้กำลังอยู่ระหว่างการพัฒนา',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('ตกลง'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      );
    }
    // เมนูสำหรับ buyer หรือไม่มี role
    else {
      // ...existing code...
      menuSections.add(
        _buildMenuSection(
          title: localizations?.userAccount ?? 'บัญชีผู้ใช้',
          items: [
            _buildMenuItem(
              icon: Icons.person_outline,
              title: localizations?.profile ?? 'โปรไฟล์',
              subtitle: localizations?.profileSubtitle ?? 'จัดการข้อมูลส่วนตัว',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
            _buildMenuItem(
              icon: Icons.location_on_outlined,
              title: localizations?.address ?? 'ที่อยู่',
              subtitle: localizations?.addressSubtitle ?? 'จัดการที่อยู่จัดส่ง',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ListAddressScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: localizations?.shopping ?? 'การซื้อขาย',
          items: [
            _buildMenuItem(
              icon: Icons.history,
              title: localizations?.orderHistory ?? 'ประวัติการสั่งซื้อ',
              subtitle:
                  localizations?.orderHistorySubtitle ??
                  'ดูประวัติการสั่งซื้อทั้งหมด',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryOrderScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
            _buildMenuItem(
              icon: Icons.star_outline,
              title: localizations?.reviews ?? 'รีวิวของฉัน',
              subtitle:
                  localizations?.reviewsSubtitle ?? 'รีวิวสินค้าที่ซื้อแล้ว',
              onTap: () {
                if (_isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReviewHistoryScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเข้าสู่ระบบก่อน'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: localizations?.customerService ?? 'บริการลูกค้า',
          items: [
            _buildMenuItem(
              icon: Icons.support_agent_outlined,
              title: localizations?.contactUs ?? 'ติดต่อเรา',
              subtitle:
                  localizations?.contactUsSubtitle ?? 'แชท หรือโทรหาทีมงาน',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactUsScreen(),
                  ),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.policy_outlined,
              title: localizations?.policies ?? 'นโยบายและเงื่อนไข',
              subtitle:
                  localizations?.policiesSubtitle ?? 'นโยบายความเป็นส่วนตัว',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PoliciesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
      menuSections.add(
        _buildMenuSection(
          title: localizations?.appSettings ?? 'ตั้งค่า',
          items: [
            _buildMenuItem(
              icon: Icons.language,
              title: localizations?.language ?? 'ภาษา',
              subtitle: 'เปลี่ยนภาษาแอป',
              onTap: () {
                _showLanguageDialog(context);
              },
            ),
            _buildMenuItem(
              icon: Icons.security_outlined,
              title: localizations?.security ?? 'ช่วยเหลือ',
              subtitle:
                  localizations?.securitySubtitle ?? 'ช่วยเหลือเกี่ยวกับแอป',
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('กำลังพัฒนา'),
                        content: const Text(
                          'ฟีเจอร์นี้กำลังอยู่ระหว่างการพัฒนา',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('ตกลง'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      );
    }

    menuSections.add(const SizedBox(height: 20));

    // Logout Button - แสดงเฉพาะเมื่อ login แล้ว
    if (_isLoggedIn) {
      menuSections.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
          ),
          child: InkWell(
            onTap: () {
              _showLogoutDialog(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: AppTheme.errorColor),
                const SizedBox(width: 8),
                Text(
                  localizations?.logout ?? 'ออกจากระบบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      menuSections.add(const SizedBox(height: 20));
    }

    // App Version
    menuSections.add(
      Text(
        '${localizations?.version ?? 'เวอร์ชัน'} 1.0.0',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          localizations?.menu ?? 'เมนู',
          style: const TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: AppTheme.primaryWhite),
            onSelected: (String value) {
              final languageProvider = Provider.of<LanguageProvider>(
                context,
                listen: false,
              );
              if (value == 'th') {
                languageProvider.setThai();
              } else if (value == 'en') {
                languageProvider.setEnglish();
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'th',
                    child: Row(
                      children: [
                        const Text('🇹🇭'),
                        const SizedBox(width: 8),
                        Text(localizations?.thai ?? 'ไทย'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'en',
                    child: Row(
                      children: [
                        const Text('🇺🇸'),
                        const SizedBox(width: 8),
                        Text(localizations?.english ?? 'English'),
                      ],
                    ),
                  ),
                ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUserData(checkRoleChange: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(children: menuSections),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryWhite,
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
          child: Column(children: items),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textSecondaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations?.changeLanguage ?? 'เปลี่ยนภาษา'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇹🇭'),
                title: Text(localizations?.thai ?? 'ไทย'),
                onTap: () {
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).setThai();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Text('🇺🇸'),
                title: Text(localizations?.english ?? 'English'),
                onTap: () {
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).setEnglish();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations?.logout ?? 'ออกจากระบบ'),
          content: Text(
            localizations?.logoutQuestion ?? 'คุณต้องการออกจากระบบหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations?.cancel ?? 'ยกเลิก'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
              child: Text(
                localizations?.logoutConfirm ?? 'ออกจากระบบ',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        );
      },
    );
  }
}
