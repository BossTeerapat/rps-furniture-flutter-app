import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';

class CartNotifier extends ChangeNotifier {
  int _count = 0;
  bool _loading = false;

  int get count => _count;
  bool get loading => _loading;

  Future<void> loadCount() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();

      int? accountId = prefs.getInt('user_id');
      if (accountId == null) {
        final userIdString = prefs.getString('user_id');
        if (userIdString != null && userIdString.isNotEmpty) {
          accountId = int.tryParse(userIdString);
        }
      }

      if (accountId == null) {
        _count = 0;
        _loading = false;
        notifyListeners();
        return;
      }

      final headers = await ApiConfig.buildHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.cart),
        headers: headers,
        body: jsonEncode({'accountId': accountId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          int totalCount = 0;
          for (var item in items) {
            totalCount += (item['quantity'] ?? 0) as int;
          }
          _count = totalCount;
        } else {
          _count = 0;
        }
      } else {
        _count = 0;
      }
    } catch (e) {
      _count = 0;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
