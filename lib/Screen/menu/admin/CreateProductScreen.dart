import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_lib;

// Runs in background isolate to convert list of bytes to data-URL base64 strings (JPEG)
List<String> _encodeImages(List<List<int>> images) {
  return images.map((b) => 'data:image/jpeg;base64,${base64Encode(b)}').toList();
}

// Compress image bytes in a background isolate using `image` package.
List<int> _compressImageIsolate(List<int> inputBytesList) {
  final inputBytes = Uint8List.fromList(inputBytesList);
  final image = img_lib.decodeImage(inputBytes);
  if (image == null) return inputBytesList;
  // Resize if large (max width 1280) while keeping aspect ratio
  final resized = img_lib.copyResize(image, width: image.width > 1280 ? 1280 : image.width);
  return img_lib.encodeJpg(resized, quality: 70);
}

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _saleCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  final List<Uint8List> _pickedImageBytes = [];
  final List<Map<String, dynamic>> _options = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _saleCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  void _recalculateStock() {
    final total = _options.fold<int>(0, (sum, o) {
      final s = o['stock'];
      if (s is int) return sum + s;
      if (s is String) return sum + (int.tryParse(s) ?? 0);
      return sum;
    });
    setState(() {
      _stockCtrl.text = total.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.listCategories);
      final resp = await http.post(uri, headers: headers, body: jsonEncode({}));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        final data = j['data'] ?? j;
        final cats =
            (data['categories'] ?? j['categories'] ?? []) as List<dynamic>;
        setState(() {
          _categories =
              cats
                  .map((e) => {'id': e['id'], 'name': e['name']})
                  .toList()
                  .cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  // Encode single image bytes to data-URL base64 string (JPEG)
  String _encodeSingleImage(List<int> bytes) => 'data:image/jpeg;base64,${base64Encode(bytes)}';

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file != null) {
      try {
        final inputBytes = await file.readAsBytes();
        // compress using compute to avoid main-isolate work
        final compressed = await compute(_compressImageIsolate, inputBytes.toList());
        setState(() {
          _pickedImageBytes.add(Uint8List.fromList(compressed));
        });
  // Encode the image to data-URL in background
  await compute(_encodeSingleImage, compressed);
  // we don't need to keep a separate list; the POST body will be generated from _pickedImageBytes
      } catch (_) {
        // ignore read error
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่')));
      return;
    }
    // Additional validations
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกรายละเอียดสินค้า')));
      return;
    }
    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มตัวเลือกอย่างน้อย 1 ตัว')));
      return;
    }
    // Validate each option: value must be present and stock must be a non-negative integer
    for (var o in _options) {
      final val = (o['value'] ?? '').toString().trim();
      if (val.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกค่า (value) ของตัวเลือก')));
        return;
      }
      final s = o['stock'];
      if (s == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกสต็อกของตัวเลือก')));
        return;
      }
      int stockNum = -1;
      if (s is int) stockNum = s;
      else if (s is String) stockNum = int.tryParse(s) ?? -1;
      if (stockNum < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกสต็อกของตัวเลือกเป็นจำนวนเต็ม >= 0')));
        return;
      }
    }
    if (_pickedImageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มรูปสินค้าอย่างน้อย 1 รูป')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final headers = await ApiConfig.buildHeaders();
      final uri = Uri.parse(ApiConfig.postProducts);
  // Offload base64 encoding to background isolate to avoid UI freezes
  final imagesForIsolate = _pickedImageBytes.map((b) => b.toList()).toList();
  final imagesBase64 = await compute(_encodeImages, imagesForIsolate);
      final body = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'cost': double.tryParse(_costCtrl.text) ?? 0,
  'salePrice': _saleCtrl.text.trim().isEmpty ? null : double.tryParse(_saleCtrl.text),
        'categoryId': _selectedCategoryId,
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
        'size': _sizeCtrl.text.trim(),
  'images': imagesBase64,
        'options':
            _options
                .map(
                  (o) => {
                    'type': o['type'],
                    'value': o['value'],
                    'stock': o['stock'] ?? 0,
                  },
                )
                .toList(),
        'statusId': 1,
      };
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        if (j['status'] == 200 || j['msg'] == 'success') {
          Navigator.of(context).pop(true);
          return;
        }
      }
      // fallback: show error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างสินค้าล้มเหลว')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'เพิ่มสินค้า',
          style: TextStyle(color: AppTheme.primaryWhite),
        ),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'กรุณากรอกชื่อสินค้า'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียดสินค้า',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Options (dynamic)
                Text(
                  'ตัวเลือก (Options)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        DropdownButton<String>(
                          value: _options[i]['type'] ?? 'COLOR',
                          items: const [
                            DropdownMenuItem(
                              value: 'COLOR',
                              child: Text('COLOR'),
                            ),
                            DropdownMenuItem(
                              value: 'SIZE',
                              child: Text('SIZE'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() {
                                _options[i]['type'] = v;
                                _recalculateStock();
                              }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _options[i]['value'] ?? '',
                            decoration: const InputDecoration(
                              labelText: 'ค่า (value)',
                            ),
                            onChanged:
                                (v) => setState(() {
                                  _options[i]['value'] = v;
                                }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue:
                                (_options[i]['stock'] ?? '').toString(),
                            decoration: const InputDecoration(
                              labelText: 'สต็อก',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged:
                                    (v) => setState(() {
                                      final trimmed = v.trim();
                                      _options[i]['stock'] = trimmed.isEmpty ? null : (int.tryParse(trimmed) ?? -1);
                                      _recalculateStock();
                                    }),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => setState(() {
                                _options.removeAt(i);
                                _recalculateStock();
                              }),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      () => setState(() {
                        _options.add({
                          'type': 'COLOR',
                          'value': '',
                          'stock': null,
                        });
                        _recalculateStock();
                      }),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มตัวเลือก'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ราคาปกติ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'กรุณากรอกราคาปกติ';
                          final n = double.tryParse(v);
                          if (n == null) return 'รูปแบบราคาปกติไม่ถูกต้อง';
                          if (n <= 0) return 'ราคาต้องมากกว่า 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _saleCtrl,
                        decoration: const InputDecoration(labelText: 'ราคาลด'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        decoration: const InputDecoration(labelText: 'ต้นทุน'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'กรุณากรอกต้นทุน';
                          final n = double.tryParse(v);
                          if (n == null) return 'รูปแบบต้นทุนไม่ถูกต้อง';
                          if (n < 0) return 'ต้นทุนต้องเป็นจำนวนเต็มบวกหรือศูนย์';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        decoration: const InputDecoration(
                          labelText: 'สต็อก (คำนวณอัตโนมัติจากตัวเลือก)',
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ขนาด/ขนาดสินค้า',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  items:
                      _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as int,
                              child: Text(c['name'] ?? '-'),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  hint: const Text('เลือกหมวดหมู่'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _pickedImageBytes.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _pickedImageBytes[i],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (i < _pickedImageBytes.length) _pickedImageBytes.removeAt(i);
                                // no extra base64 list to remove
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text('เพิ่มรูป'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('บันทึก', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ), // Column
          ), // Form
        ), // Padding
      ), // SingleChildScrollView
    ); // Scaffold
  }
}
