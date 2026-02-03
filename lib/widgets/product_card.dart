import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/product/ProductDetailScreen.dart';
import 'package:rps_app/widgets/image_helper.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final price = product['price']?.toDouble() ?? 0.0;
    final salePrice = product['salePrice']?.toDouble() ?? 0.0;
    final hasDiscount = salePrice > 0 && salePrice < price;
    final imageUrl = product['images']?.isNotEmpty == true
        ? product['images'][0]['url']
        : null;
    final statusLabel = product['status']?['label'] ?? '';
    final statusName = product['status']?['name'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: product['id'] ?? 0),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: imageUrl != null
                          ? buildProductImageWidget(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                            ),
                    ),
                    // Status badge
                    if (statusLabel.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getStatusColor(statusName),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: AppTheme.primaryWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Discount badge
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${(((price - salePrice) / price) * 100).round()}%',
                            style: const TextStyle(
                              color: AppTheme.primaryWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Price
                    if (hasDiscount) ...[
                      // Original price (crossed out)
                      Text(
                        '฿${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Sale price
                      Text(
                        '฿${salePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ] else ...[
                      // Regular price
                      Text(
                        '฿${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
