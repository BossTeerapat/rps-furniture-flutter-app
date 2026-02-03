import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/widgets/image_helper.dart';

class OrderCardWidget extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;
  final double imageSize;

  const OrderCardWidget({super.key, required this.order, this.onTap, this.imageSize = 60});

  String _buildOptionsText(Map<String, dynamic> item) {
    final dynamic optionsRaw = item['selectedOptions'] ?? item['options'] ?? item['productOptions'] ?? item['selected_options'] ?? [];
    final List<Map<String, dynamic>> selectedOptions = [];
    if (optionsRaw is List) {
      for (var o in optionsRaw) {
        if (o is Map) {
          selectedOptions.add(Map<String, dynamic>.from(o));
        } else {
          selectedOptions.add({'value': o.toString()});
        }
      }
    }

    if (selectedOptions.isEmpty) return '';

    final parts = selectedOptions.map((o) {
      final type = (o['type'] ?? o['productOption']?['type'] ?? o['name'] ?? '').toString();
      final value = (o['value'] ?? o['productOption']?['value'] ?? o['label'] ?? '').toString();
      if (type.isNotEmpty && value.isNotEmpty) return '$type: $value';
      if (value.isNotEmpty) return value;
      return '';
    }).where((s) => s.isNotEmpty).toList();

    return parts.join(' • ');
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final product = item['product'] ?? {};
    final quantity = item['quantity'] ?? 0;
    final price = (item['price'] ?? 0).toDouble();
    final images = List<Map<String, dynamic>>.from(product['images'] ?? []);
    final imageUrl = images.isNotEmpty ? images[0]['url'] : '';
    final optionsText = _buildOptionsText(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl.isNotEmpty
                ? buildProductImageWidget(imageUrl, width: imageSize, height: imageSize, fit: BoxFit.cover)
                : Container(width: imageSize, height: imageSize, color: Colors.grey[200]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (optionsText.isNotEmpty) ...[
                  Text(optionsText, style: TextStyle(color: Colors.grey[700], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('จำนวน: $quantity  ·  ฿${price.toStringAsFixed(0)}/ชิ้น', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ] else
                  Text('จำนวน: $quantity  ·  ฿${price.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text('฿${(price * quantity).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  String _customerLine() {
    final acc = order['account'];
    if (acc != null) {
      final fn = (acc['firstname'] ?? '').toString();
      final ln = (acc['lastname'] ?? '').toString();
      final phone = (acc['phone'] ?? '').toString();
      final name = ('$fn $ln').trim();
      if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
      if (name.isNotEmpty) return name;
      if (phone.isNotEmpty) return phone;
    }

    final addr = order['address'];
    if (addr != null) {
      final name = (addr['fullName'] ?? '').toString();
      final phone = (addr['phone'] ?? '').toString();
      if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
      if (name.isNotEmpty) return name;
      if (phone.isNotEmpty) return phone;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    int totalQuantity = 0;
    for (var item in items) {
      totalQuantity += (item['quantity'] ?? 0) as int;
    }
    final totalPrice = (order['totalPrice'] ?? 0).toDouble();
    final shippingPrice = (order['shippingPrice'] ?? 0).toDouble();
    final status = order['status'] ?? {};

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('คำสั่งซื้อ #${order['id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.getStatusColor(status['name'] ?? '').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(order['status']?['label'] ?? '', style: TextStyle(color: AppTheme.getStatusColor(status['name'] ?? ''), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer info
              Builder(builder: (ctx) {
                final cust = _customerLine();
                if (cust.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cust, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }),

              // Items preview
              ...items.take(2).map(_buildItemRow),

              if (items.length > 2) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('และอีก ${items.length - 2} รายการ...', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic))),

              const Divider(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ทั้งหมด $totalQuantity ชิ้น (${items.length} รายการ)', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (shippingPrice > 0) ...[
                        Text('ค่าจัดส่ง: ฿${shippingPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 2),
                      ],
                      Text('รวม: ฿${(totalPrice + shippingPrice).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
