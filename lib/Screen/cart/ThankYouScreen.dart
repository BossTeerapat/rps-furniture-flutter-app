import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';
import 'package:rps_app/Screen/MainScreen.dart';

class ThankYouScreen extends StatefulWidget {
  final int? orderId;
  const ThankYouScreen({super.key, this.orderId});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final Animation<double> _introScale;
  late final Animation<double> _introOpacity;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _introScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.elasticOut),
    );
    _introOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeIn),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _introController.forward();
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // start gentle repeating pulse
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successColor.withOpacity(0.12),
                  ),
                  child: FadeTransition(
                    opacity: _introOpacity,
                    child: ScaleTransition(
                      scale: _introScale,
                      child: ScaleTransition(
                        scale: _pulseScale,
                        child: Icon(
                          Icons.check_circle,
                          size: 96,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ขอบคุณสำหรับคำสั่งซื้อ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.orderId != null
                      ? 'คำสั่งซื้อ: #${widget.orderId}'
                      : 'คำสั่งซื้อของคุณได้รับการบันทึกแล้ว',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'ร้านค้าจะติดต่อคุณเพื่อยืนยันรายละเอียดการจัดส่ง\nหากมีคำถามสามารถติดต่อร้านค้าผ่านเมนู ติดต่อเรา',
                  style: const TextStyle(color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainScreen(refreshHomeOnInit: true)),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.primaryWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'กลับสู่หน้าหลัก',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const MainScreen(initialIndex: 2)),
                      (route) => false,
                    );
                  },
                  child: const Text('ดูคำสั่งซื้อของฉัน'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
