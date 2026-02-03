import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/RegisterScreen.dart';

class ListAccountScreen extends StatefulWidget {
  final String action; // 'employee' or 'buyer'
  const ListAccountScreen({super.key, this.action = 'employee'});

  @override
  State<ListAccountScreen> createState() => _ListAccountScreenState();
}

class _ListAccountScreenState extends State<ListAccountScreen> {
  bool _isLoading = false;
  String? _error;
  List<dynamic> _items = [];
  // pagination
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    const threshold = 200; // px before reaching bottom to prefetch
    final pos = _scrollController.position;
    if (pos.pixels + threshold >= pos.maxScrollExtent) {
      _fetch(loadMore: true);
    }
  }

  Future<void> _fetch({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() { _isLoadingMore = true; });
      _page += 1;
    } else {
      setState(() { _isLoading = true; _error = null; });
      _page = 1;
      _hasMore = true;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.listAccount);
      final resp = await http.post(uri,
        headers: headers,
        body: jsonEncode({ 'action': widget.action, 'page': _page, 'pageSize': _pageSize }),
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        final data = j is Map ? (j['data'] ?? j) : j;
        final List<dynamic> items = List<dynamic>.from(data['items'] ?? j['items'] ?? []);
        final int serverPage = data['page'] ?? _page;
        final int? totalPages = data['totalPages'];

        setState(() {
          if (loadMore) {
            _items.addAll(items);
          } else {
            _items = items;
          }

          if (totalPages != null) {
            _hasMore = serverPage < totalPages;
          } else {
            _hasMore = items.length >= _pageSize;
          }
        });
      } else {
        if (loadMore) _page = (_page > 1) ? _page - 1 : 1;
        setState(() { _error = 'API error: ${resp.statusCode}'; });
      }
    } catch (e) {
      if (loadMore) _page = (_page > 1) ? _page - 1 : 1;
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.action == 'buyer' ? 'บัญชีลูกค้า' : 'บัญชีพนักงาน'),
        backgroundColor: AppTheme.primaryColor,
        actions: widget.action == 'buyer'
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen(title: 'สร้างบัญชีพนักงาน')));
                  },
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red)))])
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final it = _items[i] as Map<String, dynamic>;
                  final role = it['role'] is Map ? (it['role']['name'] ?? '') : (it['role']?.toString() ?? '');
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('${it['firstname'] ?? ''} ${it['lastname'] ?? ''}'),
                    subtitle: Text('${it['username'] ?? ''} • $role'),
                    onTap: () {},
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: widget.action == 'buyer' ? 'ลบบัญชีลูกค้า' : 'ลบบัญชี',
                          onPressed: () {
                            _confirmAndDelete(it, i);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _confirmAndDelete(Map<String, dynamic> account, int index) {
    int countdown = 8;
    Timer? timer;
    bool started = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void startTimer() {
              // start countdown
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                setStateDialog(() {
                  countdown -= 1;
                });
                if (countdown <= 0) {
                  t.cancel();
                  Navigator.of(context).pop();
            _deleteAccount(account, index);
                }
              });
            }

            return AlertDialog(
              title: const Text('ยืนยันการลบ'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!started) ...[
                      const Text('คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีนี้?'),
                      const SizedBox(height: 12),
                      Text('ชื่อ: ${account['firstname'] ?? ''} ${account['lastname'] ?? ''}'),
                      Text('username: ${account['username'] ?? ''}'),
                    ] else ...[
                      Row(
                        children: [
                          const SizedBox(width: 6, height: 6),
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(width: 12),
                          Expanded(child: Text('ลบบัญชีใน $countdown วินาที...')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('คุณสามารถกด ยกเลิก เพื่อยกเลิกการลบได้'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (timer != null && timer!.isActive) timer!.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('ยกเลิก'),
                ),
                if (!started)
                  TextButton(
                    onPressed: () {
                      // start countdown
                      setStateDialog(() {
                        started = true;
                        countdown = 8;
                      });
                      startTimer();
                    },
                    child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
                  )
                else
                  TextButton(
                    onPressed: () {
                      if (timer != null && timer!.isActive) timer!.cancel();
                      Navigator.of(context).pop();
              _deleteAccount(account, index);
                    },
                    child: const Text('ลบทันที', style: TextStyle(color: Colors.red)),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (timer != null && timer!.isActive) timer!.cancel();
    });
  }

  Future<void> _deleteAccount(Map<String, dynamic> employee, int index) async {
    final id = employee['id'] ?? employee['userId'] ?? employee['employeeId'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบ id ของบัญชี'), backgroundColor: Colors.red));
      return;
    }

    try {
      final headers = await ApiConfig.buildHeaders();
  final uri = Uri.parse(ApiConfig.deleteAccount);
  final actionName = widget.action == 'buyer' ? 'deleteBuyer' : 'deleteEmployee';
  final body = jsonEncode({ 'id': id, 'action': actionName });
      final resp = await http.post(uri, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        // Expecting { msg: 'Account deleted', id: 4, action: 'deleteEmployee' }
        setState(() {
          _items.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(j['msg'] ?? 'บัญชีถูกลบ'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API error: ${resp.statusCode}'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }
}
