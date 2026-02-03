import 'package:flutter/material.dart';
import 'package:rps_app/Screen/tabs/ListOrderAll.dart';
import 'package:rps_app/Screen/tabs/SalesScreen.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/tabs/HomeTab.dart';
import 'package:rps_app/Screen/tabs/FavoriteTab.dart';
import 'package:rps_app/Screen/tabs/StatusOrderTab.dart';
import 'package:rps_app/Screen/tabs/MenuTab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final bool refreshHomeOnInit;
  const MainScreen({super.key, this.initialIndex = 0, this.refreshHomeOnInit = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _role;
  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();

  @override
  void initState() {
    super.initState();
    // Apply initial index from widget if provided
    _currentIndex = widget.initialIndex;
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role');
    });
    // If caller requested a refresh of Home on init, trigger it after role is known
    if (widget.refreshHomeOnInit && _homeKey.currentState != null) {
      _homeKey.currentState!.refreshAllData();
    }
  }

  // Handle role change callback from MenuTab
  void _handleRoleChanged() async {
    await _loadRole();
    // รีเซ็ต index ให้เหมาะสมกับ role ใหม่
    setState(() {
      _currentIndex = 0; // เริ่มต้นที่หน้าแรกเสมอ
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // กำหนด Tab และ Menu ตาม role
    final List<Widget> pages =
        _role == null || _role == 'buyer'
            ? [
  HomeTab(key: _homeKey),
    FavoriteTab(active: _currentIndex == 1),
                StatusOrderTab(active: _currentIndex == 2),
                MenuTab(onRoleChanged: _handleRoleChanged),
              ]
            : _role == 'employee'
                ? [
                    const HomeTab(),
                    const ListOrderAll(),
                    MenuTab(onRoleChanged: _handleRoleChanged),
                  ]
                : _role == 'admin'
                    ? [
                        const HomeTab(),
                        const ListOrderAll(),
                        const SalesScreen(),
                        MenuTab(onRoleChanged: _handleRoleChanged),
                      ]
                    : [];

    // Ensure current index is within bounds for the active pages
    int safeIndex = _currentIndex;
    if (pages.isNotEmpty && safeIndex >= pages.length) {
      safeIndex = pages.length - 1;
    }

    return Scaffold(
      // Use IndexedStack to preserve state of each tab and avoid rebuild issues
      body: pages.isNotEmpty
          ? IndexedStack(
              index: safeIndex,
              children: pages,
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: pages.isNotEmpty
          ? BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
                backgroundColor: AppTheme.primaryWhite,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: AppTheme.textSecondaryColor,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                ),
                showUnselectedLabels: true,
                items:
                    _role == null || _role == 'buyer'
                        ? [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.home),
                              label: localizations?.home ?? 'หน้าหลัก',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.favorite),
                              label: localizations?.favorite ?? 'รายการโปรด',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.assignment),
                              label: localizations?.order ?? 'คำสั่งซื้อ',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.menu),
                              label: localizations?.menu ?? 'เมนู',
                            ),
                          ]
                        : _role == 'employee'
                        ? [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.home),
                              label: localizations?.home ?? 'หน้าหลัก',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.list),
                              label: 'คำสั่งซื้อ',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.menu),
                              label: localizations?.menu ?? 'เมนู',
                            ),
                          ]
                        : _role == 'admin'
                        ? [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.home),
                              label: localizations?.home ?? 'หน้าหลัก',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.list),
                              label: 'คำสั่งซื้อ',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.bar_chart),
                              label: localizations?.sales ?? 'ยอดขาย',
                            ),
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.menu),
                              label: localizations?.menu ?? 'เมนู',
                            ),
                          ]
                        : [],
              )
              : null,
    );
  }
}
