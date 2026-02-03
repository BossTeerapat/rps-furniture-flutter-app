import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/providers/cart_notifier.dart';
import 'package:rps_app/Screen/cart/CartScreen.dart';

/// Reusable cart button with badge.
/// - [count]: number displayed in badge. If zero or null, badge is hidden.
/// - [onPressed]: tap handler (navigate to cart, etc.).
class CartButton extends StatelessWidget {
  /// If [countOverride] is provided it will be used instead of provider value.
  final int? countOverride;
  final double iconSize;
  const CartButton({super.key, this.countOverride, this.iconSize = 28});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<CartNotifier>(context);
    final count = countOverride ?? notifier.count;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.shopping_cart,
            color: AppTheme.primaryWhite,
            size: iconSize,
          ),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
            // refresh after returning
            await notifier.loadCount();
          },
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: AppTheme.primaryWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
