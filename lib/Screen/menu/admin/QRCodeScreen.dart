import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/widgets/image_helper.dart';

class PaymentQRCodeScreen extends StatefulWidget {
  const PaymentQRCodeScreen({super.key});

  @override
  State<PaymentQRCodeScreen> createState() => _PaymentQRCodeScreenState();
}

class _PaymentQRCodeScreenState extends State<PaymentQRCodeScreen> {
  bool _loading = true;
  Map<String, dynamic>? _qr;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.payment);
      final res = await http.post(uri, headers: headers, body: jsonEncode({}));
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      if (res.statusCode == 200 || res.statusCode == 201) {
        Map<String, dynamic>? found;
        if (body is Map) {
          if (body['qrCode'] is Map) {
            found = Map<String, dynamic>.from(body['qrCode']);
          } else if (body['qrCodes'] is List && (body['qrCodes'] as List).isNotEmpty) {
            final first = (body['qrCodes'] as List).first;
            if (first is Map) found = Map<String, dynamic>.from(first);
          }
        }
        setState(() {
          _qr = found;
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              body is Map && body['msg'] != null
                  ? body['msg'].toString()
                  : 'Server error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _absoluteImageUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    final base = ApiConfig.baseUrl?.trim() ?? '';
    if (base.isEmpty) return null;
    // ensure base doesn't end with slash if url starts with slash
    if (base.endsWith('/') && url.startsWith('/')) {
      return base + url.substring(1);
    }
    return base + url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qr Code'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: _loadQr,
        child:
            _loading
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
                : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Text(
                        'เกิดข้อผิดพลาด: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadQr,
                        child: const Text('ลองใหม่'),
                      ),
                    ] else if (_qr == null) ...[
                      SizedBox(
                        height:
                            MediaQuery.of(context).size.height -
                            kToolbarHeight -
                            MediaQuery.of(context).padding.top -
                            120,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.qr_code,
                                size: 96,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'ยังไม่มี QR code',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showUploadDialog(),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('อัปโหลด QR code'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // image
                              Builder(
                                builder: (ctx) {
                                  final imgEntry = _qr!['imageUrl'] ?? _qr!['imageBase64'] ?? null;
                                  return SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: buildProductImageWidget(imgEntry, width: 200, height: 200, fit: BoxFit.contain),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _qr!['accountName']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_qr!['bankName']?.toString() ?? '-'),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showUploadDialog(),
                                icon: const Icon(Icons.edit),
                                label: const Text('แก้ไข QR code'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }

  Future<void> _showUploadDialog() async {
    final accountCtrl = TextEditingController(
      text: _qr?['accountName']?.toString() ?? '',
    );
    final bankCtrl = TextEditingController(
      text: _qr?['bankName']?.toString() ?? '',
    );
    Uint8List? pickedBytes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            Future<void> pickImageLocal() async {
              final ImagePicker picker = ImagePicker();
              try {
                final XFile? img = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 85,
                );
                if (img != null) {
                  final bytes = await img.readAsBytes();
                  pickedBytes = bytes;
                  setState2(() {});
                }
              } catch (e) {
                debugPrint('pick image error: $e');
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: const Text('อัปโหลด QR code'),
              content: SizedBox(
                width: MediaQuery.of(ctx2).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: accountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อบัญชี',
                          hintText: 'ชื่อบัญชีธนาคาร',

                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bankCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อธนาคาร / เลขที่บัญชี',
                          hintText: 'กรุงเทพ xxx-x-xxxxx-x',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          children: [
                            if (pickedBytes != null) ...[
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    pickedBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ] else if (_qr != null &&
                                (_qr!['imageUrl'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                              Builder(
                                builder: (ctx3) {
                                  final url = _absoluteImageUrl(
                                    _qr!['imageUrl']?.toString(),
                                  );
                                  if (url == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'รูปภาพปัจจุบัน',
                                style: TextStyle(fontSize: 14),
                              ),
                            ] else ...[
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'ยังไม่ได้เลือกภาพ',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await pickImageLocal();
                                  },
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('เลือกรูป'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed:
                      sending
                          ? null
                          : () async {
                            final acc = accountCtrl.text.trim();
                            final bank = bankCtrl.text.trim();
                            if (acc.isEmpty || bank.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'กรุณากรอกชื่อบัญชีและชื่อธนาคาร',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (pickedBytes == null &&
                                (_qr == null ||
                                    (_qr?['imageUrl'] == null &&
                                        _qr?['imageBase64'] == null))) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('กรุณาเลือกภาพ QR code'),
                                ),
                              );
                              return;
                            }
                            if (ctx2.mounted) setState2(() => sending = true);
                            try {
                              String? imageBase64;
                              if (pickedBytes != null) {
                                imageBase64 =
                                    'data:image/jpeg;base64,${base64Encode(pickedBytes!)}';
                              }
                              final headers = await ApiConfig.buildHeaders();
                              // If editing an existing QR (has id), call editPayment endpoint; otherwise create with postPayment
                              final bool isEdit = _qr != null && _qr!['id'] != null;
                              final String endpoint = isEdit ? ApiConfig.editPayment : ApiConfig.postPayment;
                              final uri = Uri.parse(endpoint);
                              final Map<String, dynamic> payload = {
                                if (isEdit) 'id': _qr!['id'],
                                'accountName': acc,
                                'bankName': bank,
                                if (imageBase64 != null) 'imageBase64': imageBase64,
                                if (imageBase64 == null && _qr != null) 'imageUrl': _qr!['imageUrl'],
                              };
                              final body = jsonEncode(payload);
                              final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
                              debugPrint('$endpoint request: $body');
                              debugPrint('$endpoint response: ${resp.statusCode} ${resp.body}');
                              if (resp.statusCode == 200 || resp.statusCode == 201) {
                                final j = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
                                if (j is Map && j['qrCode'] is Map) {
                                  final updated = Map<String, dynamic>.from(j['qrCode']);
                                  if (mounted) setState(() => _qr = updated);
                                } else {
                                  if (mounted) await _loadQr();
                                }
                                if (ctx2.mounted) Navigator.of(ctx2).pop();
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('อัปโหลด QR code สำเร็จ'), backgroundColor: Colors.green),
                                );
                                return;
                              }
                              final j = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(j['msg']?.toString() ?? 'Upload failed')));
                            } catch (e) {
                              debugPrint('upload error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                              );
                            } finally {
                              if (ctx2.mounted) setState2(() => sending = false);
                            }
                          },
                  child: const Text('อัปโหลด'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
