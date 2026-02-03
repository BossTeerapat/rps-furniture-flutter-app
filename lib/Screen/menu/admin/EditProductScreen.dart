
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:rps_app/Service/API_Config.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/widgets/image_helper.dart';

List<String> _encodeImages(List<List<int>> images) {
	return images.map((b) => 'data:image/jpeg;base64,${base64Encode(b)}').toList();
}

List<int> _compressImageIsolate(List<int> inputBytesList) {
	final inputBytes = Uint8List.fromList(inputBytesList);
	final image = img_lib.decodeImage(inputBytes);
	if (image == null) return inputBytesList;
	final resized = img_lib.copyResize(image, width: image.width > 1280 ? 1280 : image.width);
	return img_lib.encodeJpg(resized, quality: 70);
}

class EditProductScreen extends StatefulWidget {
	final Map<String, dynamic>? product;
	final dynamic productId;
	const EditProductScreen({super.key, this.product, this.productId}) : assert(product != null || productId != null, 'product or productId must be provided');

	@override
	State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
	final _formKey = GlobalKey<FormState>();
	late TextEditingController _nameCtrl;
	late TextEditingController _descCtrl;
	late TextEditingController _priceCtrl;
	late TextEditingController _saleCtrl;
	late TextEditingController _costCtrl;
	late TextEditingController _stockCtrl;
	late TextEditingController _sizeCtrl;

	List<Map<String, dynamic>> _categories = [];
	int? _selectedCategoryId;

	List<String> _existingImages = [];
	final List<Uint8List> _pickedImageBytes = [];

	List<Map<String, dynamic>> _options = [];

	bool _isSubmitting = false;

	@override
	void initState() {
		super.initState();
		// initialize controllers to avoid LateInitializationError
		_nameCtrl = TextEditingController();
		_descCtrl = TextEditingController();
		_priceCtrl = TextEditingController();
		_saleCtrl = TextEditingController();
		_costCtrl = TextEditingController();
		_stockCtrl = TextEditingController();
		_sizeCtrl = TextEditingController();

		final p = widget.product;
		if (p != null) {
			// populate controllers and local state from provided product
			_nameCtrl.text = p['name']?.toString() ?? '';
			_descCtrl.text = p['description']?.toString() ?? '';
			_priceCtrl.text = (p['price'] ?? '').toString();
			_saleCtrl.text = (p['salePrice'] ?? '').toString();
			_costCtrl.text = (p['cost'] ?? '').toString();
			_stockCtrl.text = (p['stock'] ?? '').toString();
			_sizeCtrl.text = p['size']?.toString() ?? '';
			_selectedCategoryId = p['categoryId'] ?? p['category']?['id'];

			final imgs = (p['images'] ?? []) as List<dynamic>;
			_existingImages = imgs.map((e) => e is Map ? (e['url']?.toString() ?? '') : e?.toString() ?? '').where((s) => s.isNotEmpty).toList();

			final opts = (p['options'] ?? []) as List<dynamic>;
			_options = opts.map((o) {
				if (o is Map) {
					return {'id': o['id'], 'type': o['type'] ?? 'COLOR', 'value': o['value'] ?? '', 'stock': o['stock'] ?? 0};
				}
				return {'type': 'COLOR', 'value': o.toString(), 'stock': 0};
			}).toList().cast<Map<String, dynamic>>();
		}

		_loadCategories();

		// if product wasn't provided, fetch from server and populate controllers there
		if (p == null) {
			_loadFromServer();
		}
	}

	@override
	void dispose() {
		_nameCtrl.dispose();
		_descCtrl.dispose();
		_priceCtrl.dispose();
		_saleCtrl.dispose();
		_costCtrl.dispose();
		_stockCtrl.dispose();
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
		setState(() => _stockCtrl.text = total.toString());
	}

	Future<void> _loadCategories() async {
		try {
			final headers = await ApiConfig.buildHeaders();
			final uri = Uri.parse(ApiConfig.listCategories);
			final resp = await http.post(uri, headers: headers, body: jsonEncode({}));
			if (resp.statusCode == 200) {
				final j = jsonDecode(resp.body);
				final data = j['data'] ?? j;
				final cats = (data['categories'] ?? j['categories'] ?? []) as List<dynamic>;
				setState(() {
					_categories = cats.map((e) => {'id': e['id'], 'name': e['name']}).toList().cast<Map<String, dynamic>>();
				});
			}
		} catch (_) {}
	}

	Future<void> _loadFromServer() async {
		final pid = widget.productId;
		if (pid == null) return;
		try {
			final headers = await ApiConfig.buildHeaders();
			final uri = Uri.parse(ApiConfig.productDetail);
			final resp = await http.post(uri, headers: headers, body: jsonEncode({'id': pid, 'action': 'edit'}));
			if (resp.statusCode == 200) {
				final decoded = jsonDecode(resp.body);
				final product = decoded is Map ? (decoded['product'] ?? decoded['data']?['product'] ?? decoded) : null;
				if (product is Map) {
					setState(() {
						// populate local widget.product-like structure
						// reuse existing init logic by assigning to local controllers
						_nameCtrl.text = product['name']?.toString() ?? '';
						_descCtrl.text = product['description']?.toString() ?? '';
						_priceCtrl.text = (product['price'] ?? '').toString();
						_saleCtrl.text = (product['salePrice'] ?? '').toString();
						_costCtrl.text = (product['cost'] ?? '').toString();
						_stockCtrl.text = (product['stock'] ?? '').toString();
						_sizeCtrl.text = product['size']?.toString() ?? '';
						_selectedCategoryId = product['categoryId'] ?? product['category']?['id'];
						final imgs = (product['images'] ?? []) as List<dynamic>;
						_existingImages = imgs.map((e) => e is Map ? (e['url']?.toString() ?? '') : e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
						final opts = (product['options'] ?? []) as List<dynamic>;
						_options = opts.map((o) {
							if (o is Map) return {'id': o['id'], 'type': o['type'] ?? 'COLOR', 'value': o['value'] ?? '', 'stock': o['stock'] ?? 0};
							return {'type': 'COLOR', 'value': o.toString(), 'stock': 0};
						}).toList().cast<Map<String, dynamic>>();
					});
				}
			}
		} catch (_) {}
	}

	Future<void> _pickImage() async {
		final ImagePicker picker = ImagePicker();
		final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
		if (file != null) {
			try {
				final inputBytes = await file.readAsBytes();
				final compressed = await compute(_compressImageIsolate, inputBytes.toList());
				setState(() => _pickedImageBytes.add(Uint8List.fromList(compressed)));
			} catch (_) {}
		}
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _isSubmitting = true);
		try {
			final headers = await ApiConfig.buildHeaders();

			final imagesForIsolate = _pickedImageBytes.map((b) => b.toList()).toList();
			final imagesBase64 = imagesForIsolate.isNotEmpty ? await compute(_encodeImages, imagesForIsolate) : <String>[];
			final imagesPayload = [..._existingImages, ...imagesBase64];

					final resolvedPid = widget.productId ?? widget.product?['id'];
					final body = <String, dynamic>{
						'productId': resolvedPid,
					};

			if (_nameCtrl.text.trim().isNotEmpty) body['name'] = _nameCtrl.text.trim();
			if (_descCtrl.text.trim().isNotEmpty) body['description'] = _descCtrl.text.trim();
			final price = double.tryParse(_priceCtrl.text.trim());
			if (price != null) body['price'] = price;
			final sale = double.tryParse(_saleCtrl.text.trim());
			if (sale != null) body['salePrice'] = sale;
			final cost = double.tryParse(_costCtrl.text.trim());
			if (cost != null) body['cost'] = cost;
			if (_selectedCategoryId != null) body['categoryId'] = _selectedCategoryId;
			final stock = int.tryParse(_stockCtrl.text.trim());
			if (stock != null) body['stock'] = stock;
			if (_sizeCtrl.text.trim().isNotEmpty) body['size'] = _sizeCtrl.text.trim();
			if (imagesPayload.isNotEmpty) body['images'] = imagesPayload;
					if (_options.isNotEmpty) {
					  body['options'] = _options.map((o) {
							final mapped = {'type': o['type'], 'value': o['value'], 'stock': o['stock'] ?? 0};
							if (o.containsKey('id') && o['id'] != null) mapped['id'] = o['id'];
							return mapped;
						}).toList();
					}

					// Log request body for debugging
					final requestJson = jsonEncode(body);
					debugPrint('EditProduct request -> ${ApiConfig.editProduct}');
					debugPrint('EditProduct request body: $requestJson');

					final resp = await http.post(Uri.parse(ApiConfig.editProduct), headers: headers, body: requestJson);
					debugPrint('EditProduct response status: ${resp.statusCode}');
					debugPrint('EditProduct response body: ${resp.body}');

					if (resp.statusCode == 200 || resp.statusCode == 201) {
						ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตสินค้าเรียบร้อย')));
						Navigator.of(context).pop(true);
						return;
					}

					// Try to show server error body to the user for debugging
					String errMsg = 'HTTP ${resp.statusCode}';
					try {
						final rb = jsonDecode(resp.body);
						if (rb is Map && rb.containsKey('message')) {
						  errMsg = rb['message'].toString();
						} else {
						  errMsg = resp.body.toString();
						}
					} catch (_) {
						errMsg = resp.body.toString();
					}

					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $errMsg')));
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
		} finally {
			if (mounted) setState(() => _isSubmitting = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('แก้ไขสินค้า', style: TextStyle(color: AppTheme.primaryWhite)),
				backgroundColor: AppTheme.primaryColor,
				centerTitle: true,
			),
			body: SingleChildScrollView(
				physics: const AlwaysScrollableScrollPhysics(),
				child: Padding(
					padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom),
					child: Form(
						key: _formKey,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อสินค้า'), validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อสินค้า' : null),
								const SizedBox(height: 12),
								TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'รายละเอียดสินค้า'), maxLines: 3),
								const SizedBox(height: 12),
								Text('ตัวเลือก (Options)', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
								const SizedBox(height: 8),
								for (int i = 0; i < _options.length; i++)
									Padding(
										padding: const EdgeInsets.only(bottom: 8.0),
										child: Row(
											children: [
												DropdownButton<String>(
													value: _options[i]['type'] ?? 'COLOR',
													items: const [DropdownMenuItem(value: 'COLOR', child: Text('COLOR')), DropdownMenuItem(value: 'SIZE', child: Text('SIZE'))],
													onChanged: (v) => setState(() {
														_options[i]['type'] = v;
														_recalculateStock();
													}),
												),
												const SizedBox(width: 8),
												Expanded(
													child: TextFormField(initialValue: _options[i]['value'] ?? '', decoration: const InputDecoration(labelText: 'ค่า (value)'), onChanged: (v) => setState(() => _options[i]['value'] = v)),
												),
												const SizedBox(width: 8),
												SizedBox(
													width: 80,
													child: TextFormField(initialValue: (_options[i]['stock'] ?? '').toString(), decoration: const InputDecoration(labelText: 'สต็อก'), keyboardType: TextInputType.number, onChanged: (v) => setState(() { _options[i]['stock'] = int.tryParse(v) ?? 0; _recalculateStock(); })),
												),
												IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { _options.removeAt(i); _recalculateStock(); })),
											],
										),
									),
								OutlinedButton.icon(onPressed: () => setState(() { _options.add({'type': 'COLOR', 'value': '', 'stock': null}); _recalculateStock(); }), icon: const Icon(Icons.add), label: const Text('เพิ่มตัวเลือก')),
								const SizedBox(height: 12),
								Row(children: [ Expanded(child: TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'ราคาปกติ'), keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _saleCtrl, decoration: const InputDecoration(labelText: 'ราคาขาย'), keyboardType: TextInputType.number)), ]),
								const SizedBox(height: 12),
								Row(children: [ Expanded(child: TextFormField(controller: _costCtrl, decoration: const InputDecoration(labelText: 'ต้นทุน'), keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'สต็อก (คำนวณจากตัวเลือก)'), readOnly: true)), ]),
								const SizedBox(height: 12),
								TextFormField(controller: _sizeCtrl, decoration: const InputDecoration(labelText: 'ขนาด/ขนาดสินค้า')),
								const SizedBox(height: 12),
								DropdownButtonFormField<int>( value: _selectedCategoryId, items: _categories.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] ?? '-'))).toList(), onChanged: (v) => setState(() => _selectedCategoryId = v), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)), hint: const Text('เลือกหมวดหมู่')),
								const SizedBox(height: 12),
								Wrap(spacing: 8, runSpacing: 8, children: [
									for (int i = 0; i < _existingImages.length; i++) Stack(children: [ ClipRRect(borderRadius: BorderRadius.circular(8), child: buildProductImageWidget(_existingImages[i], width: 80, height: 80, fit: BoxFit.cover)), Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _existingImages.removeAt(i)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))) ]),
									for (int i = 0; i < _pickedImageBytes.length; i++) Stack(children: [ ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_pickedImageBytes[i], width: 80, height: 80, fit: BoxFit.cover)), Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _pickedImageBytes.removeAt(i)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))) ]),
									OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo), label: const Text('เพิ่มรูป')),
								]),
								const SizedBox(height: 20),
								Row(children: [ Expanded(child: ElevatedButton(onPressed: _isSubmitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor), child: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('บันทึก', style: TextStyle(color: Colors.white)), ),), ],),
							],
						),
					),
				),
			),
		);
	}
}
