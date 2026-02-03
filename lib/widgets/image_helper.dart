import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rps_app/Service/API_Config.dart';

/// Builds a widget for a product image entry.
/// Supports:
/// - Absolute http(s) URLs (String)
/// - Relative paths starting with '/' (resolved via ApiConfig.baseUrl)
/// - Data-URL base64 strings (data:image/..;base64,...)
/// - Raw base64 strings
Widget buildProductImageWidget(dynamic imageEntry,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  try {
    if (imageEntry == null) return _placeholder(width, height);

    String? url;
    String? base64Data;

    if (imageEntry is String) {
      final s = imageEntry.trim();
      if (s.startsWith('data:')) {
        base64Data = s;
      } else if (s.startsWith('/')) {
        final base = ApiConfig.baseUrl ?? '';
        if (base.isNotEmpty) {
          final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
          url = b + s;
        } else {
          // cannot resolve relative path without a base URL -> leave url null so placeholder is used
        }
      } else if (s.startsWith('http')) {
        url = s;
      } else {
        // treat as raw base64
        base64Data = 'data:image/jpeg;base64,$s';
      }
    } else if (imageEntry is Map) {
      // common shapes: {"url": "/uploads/..."} or {"data":"data:..."} or {"base64":"..."}
      if (imageEntry.containsKey('data')) {
        base64Data = imageEntry['data']?.toString();
      } else if (imageEntry.containsKey('base64')) {
        base64Data = imageEntry['base64']?.toString();
      } else if (imageEntry.containsKey('url')) {
        final v = imageEntry['url'];
        if (v is String) {
          if (v.startsWith('/')) {
            final base = ApiConfig.baseUrl ?? '';
            if (base.isNotEmpty) {
              final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
              url = b + v;
            } else {
              // unresolved relative path -> skip network load
            }
          } else {
            url = v;
          }
        }
      }
    }

    if (base64Data != null && base64Data.isNotEmpty) {
      String b = base64Data;
      if (b.startsWith('data:')) {
        final comma = b.indexOf(',');
        if (comma >= 0) b = b.substring(comma + 1);
      }

      try {
        final bytes = base64Decode(b);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (c, e, st) => _placeholder(width, height),
        );
      } catch (e) {
        // fallthrough to try url
      }
    }

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (c, e, st) => _placeholder(width, height),
      );
    }
  } catch (e) {
    // ignore and show placeholder
  }

  return _placeholder(width, height);
}

Widget _placeholder(double? width, double? height) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey[200],
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'ไม่สามารถโหลดรูปภาพ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
