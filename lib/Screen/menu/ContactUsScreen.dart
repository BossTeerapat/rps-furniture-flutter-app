import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rps_app/theme/app_theme.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('คัดลอก $label แล้ว: $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ติดต่อเรา',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.store,
                    color: AppTheme.primaryWhite,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ร้านรุ่งประเสริฐเฟอร์นิเจอร์ ชัยนาท',
                    style: TextStyle(
                      color: AppTheme.primaryWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'เปิดทุกวัน 8:00-17:00 น.',
                      style: TextStyle(
                        color: AppTheme.primaryWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Contact Methods
            _buildContactCard(
              icon: Icons.phone,
              title: 'โทรศัพท์',
              content: '084-621-5217',
              subtitle: 'แตะเพื่อคัดลอกหมายเลข',
              iconColor: Colors.green,
              onTap:
                  () => _copyToClipboard(
                    context,
                    '0846215217',
                    'หมายเลขโทรศัพท์',
                  ),
            ),

            _buildContactCard(
              icon: Icons.facebook,
              title: 'Facebook',
              content: 'ร้านรุ่งประเสริฐเฟอร์นิเจอร์ ชัยนาท',
              subtitle: 'แตะเพื่อคัดลอกลิงก์',
              iconColor: const Color(0xFF1877F2),
              onTap:
                  () => _copyToClipboard(
                    context,
                    'https://www.facebook.com/profile.php?id=100028295635591',
                    'ลิงก์ Facebook',
                  ),
            ),

            _buildContactCard(
              icon: Icons.chat,
              title: 'Line',
              content: '@RPSFurniture',
              subtitle: 'แตะเพื่อคัดลอก Line ID',
              iconColor: const Color(0xFF00C300),
              onTap:
                  () => _copyToClipboard(context, '@RPSFurniture', 'Line ID'),
            ),

            _buildContactCard(
              icon: Icons.location_on,
              title: 'พิกัดร้านค้า',
              content: 'Google Maps',
              subtitle: 'แตะเพื่อคัดลอกลิงก์แผนที่',
              iconColor: Colors.red,
              onTap:
                  () => _copyToClipboard(
                    context,
                    'https://maps.app.goo.gl/2c3Lp2HEYm7kg26r8',
                    'ลิงก์ Google Maps',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
