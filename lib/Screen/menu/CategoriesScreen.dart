import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Service/API_Config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rps_app/Screen/product/ProductListScreen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(Uri.parse(ApiConfig.listCategories), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _categories = data['categories'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'ไม่สามารถโหลดหมวดหมู่ได้';
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

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'เตียงนอน':
        return Icons.bed;
      case 'ตู้เสื้อผ้า':
        return Icons.checkroom;
      case 'โต๊ะอาหาร':
        return Icons.table_restaurant;
      case 'ที่นอน':
        return Icons.hotel;
      case 'โซฟา':
        return Icons.chair;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('หมวดหมู่สินค้า'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        color: AppTheme.primaryColor,
        child: _isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 60),
                      Center(child: Text(_error!)),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final c = _categories[index] as Map<String, dynamic>;
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductListScreen(
                                categoryId: c['id'] ?? 0,
                                categoryName: c['name'] ?? '',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getIconForCategory(c['name'] ?? ''), color: AppTheme.primaryColor, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                c['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text('(${c['_count']?['products'] ?? 0})', style: TextStyle(color: AppTheme.textSecondaryColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
