import 'package:flutter/material.dart';

class AppTheme {

  static Color getStatusColor(String statusName) {
    switch (statusName.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'sale':
        return errorColor;
      case 'bestseller':
        return Colors.purple;
      case 'recommend':
        return infoColor;
      case 'pending':
        return warningColor;
      case 'verifying':
        return infoColor;
      case 'preparing':
        return Colors.purple;
      case 'shipping':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'canceled':
        return errorColor;
      default:
        return primaryColor;
    }
  }
  // Primary Colors
  static const Color primaryColor = Color.fromARGB(255, 108, 0, 0); // Red
  static const Color primaryWhite = Colors.white;
  
  // Background Colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  
  // Text Colors
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textHintColor = Color(0xFF9E9E9E);
  
  // Status Colors
  static const Color successColor = Color(0xFF38A169); // Green for success
  static const Color warningColor = Color(0xFFED8936); // Orange for warning
  static const Color errorColor = Color(0xFFE53E3E); // Red for error
  static const Color infoColor = Color(0xFF3182CE); // Blue for info
  
  
}
