import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/widgets/search_field.dart';
import 'package:rps_app/Screen/product/ProductDetailScreen.dart';
import 'package:rps_app/widgets/image_helper.dart';
import 'package:rps_app/Screen/product/ProductListScreen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSuggestLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  Future<void> _performSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _results = [];
      _suggestions = [];
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.searchProduct);
      final body = {
        'q': q,
        'mode': 'products',
        'limit': 50,
        'includeOutOfStock': true,
      };
      final resp = await http.post(uri, headers: headers, body: json.encode(body));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final products = List<Map<String, dynamic>>.from(
          (jsonResp['products'] ?? jsonResp['data'] ?? jsonResp['suggestions'] ?? []).map((p) => Map<String, dynamic>.from(p)),
        );

        // If we have product results, navigate to ProductListScreen showing them
        if (products.isNotEmpty) {
          FocusScope.of(context).unfocus();
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductListScreen(
                initialProducts: products,
                initialQuery: q,
              ),
            ),
          );
          return;
        } else {
          // no products found, leave results empty so UI can show no-results
          setState(() {
            _results = [];
          });
        }
      } else {
        setState(() {
          _results = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSuggestions(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSuggestLoading = false;
      });
      return;
    }
    setState(() {
      _isSuggestLoading = true;
    });
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.searchProduct);
      final body = {
        'q': q,
        'mode': 'suggest',
        'limit': 12,
        'includeOutOfStock': true,
      };
      final resp = await http.post(uri, headers: headers, body: json.encode(body));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final products = jsonResp['products'] ?? jsonResp['data'] ?? jsonResp['suggestions'] ?? [];
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(
            products.map((p) => Map<String, dynamic>.from(p)),
          );
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
      });
    } finally {
      if (mounted) setState(() => _isSuggestLoading = false);
    }
  }

  Future<void> _openProductsForSelected(String selected) async {
    if (selected.trim().isEmpty) return;
    // show a small loading state while fetching then navigate
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.searchProduct);
      final body = {
        'q': selected,
        'mode': 'products',
        'limit': 50,
        'includeOutOfStock': true,
      };
      final resp = await http.post(uri, headers: headers, body: json.encode(body));
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final products = List<Map<String, dynamic>>.from(
          (jsonResp['products'] ?? jsonResp['data'] ?? []).map((p) => Map<String, dynamic>.from(p)),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListScreen(
              initialProducts: products,
              initialQuery: selected,
            ),
          ),
        );
      }
    } catch (e) {
      // ignore errors here; fallback handled elsewhere if needed
    }
  }

  @override
  void dispose() {
  _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: SearchField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (v) => _performSearch(v),
          onChanged: (v) {
            // debounce rapid typing
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              _fetchSuggestions(v);
            });
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_isLoading || _isSuggestLoading) const LinearProgressIndicator(),
          Expanded(
            child: _suggestions.isNotEmpty
                ? ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(item['name'] ?? item['q'] ?? '-'),
                        onTap: () async {
                          final selected = item['name'] ?? item['q'] ?? item.toString();
                          // reflect selection in the search field
                          _controller.text = selected;
                          await _openProductsForSelected(selected);
                        },
                      );
                    },
                  )
                : (_results.isEmpty
                    ? Center(child: Text(_isLoading ? 'กำลังค้นหา...' : 'ไม่มีผลลัพธ์'))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: item['images'] != null && item['images'].isNotEmpty
                                ? buildProductImageWidget(item['images'][0]['url'] ?? item['image'], width: 56, height: 56, fit: BoxFit.cover)
                                : const Icon(Icons.image_not_supported),
                            title: Text(item['name'] ?? '-'),
                            subtitle: Text('฿${(item['salePrice'] ?? item['price'] ?? 0).toString()}'),
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProductDetailScreen(productId: item['id'] ?? 0)),
                              );
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
