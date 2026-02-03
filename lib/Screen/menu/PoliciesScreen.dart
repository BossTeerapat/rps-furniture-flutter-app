import 'package:flutter/material.dart';
import 'package:rps_app/theme/app_theme.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

  Widget _buildPolicySection({
    required String title,
    required List<String> items,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              int index = entry.key;
              String item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
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
          'นโยบายและเงื่อนไข',
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
            // Header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.policy, color: Colors.blue[600], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'ร้านรุ่งประเสริฐเฟอร์นิเจอร์ ชัยนาท',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'นโยบายและเงื่อนไขการให้บริการ',
                    style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // เงื่อนไขการสั่งซื้อ
            _buildPolicySection(
              title: 'เงื่อนไขการสั่งซื้อ',
              icon: Icons.shopping_cart,
              items: [
                'ลูกค้าสามารถสั่งซื้อสินค้าผ่านแอปพลิเคชันได้ตลอด 24 ชั่วโมง',
                'กรุณาตรวจสอบข้อมูลสินค้า ราคา และที่อยู่จัดส่งให้ถูกต้องก่อนยืนยันคำสั่งซื้อ',
                'เมื่อยืนยันคำสั่งซื้อแล้ว จะไม่สามารถแก้ไขหรือยกเลิกได้',
                'ทางร้านขอสงวนสิทธิ์ในการยกเลิกคำสั่งซื้อในกรณีที่สินค้าหมด',
              ],
            ),

            // เงื่อนไขการชำระเงิน
            _buildPolicySection(
              title: 'เงื่อนไขการชำระเงิน',
              icon: Icons.payment,
              items: [
                'รับชำระเงินผ่าน QR Code และเก็บเงินปลายทาง (COD)',
                'สำหรับการชำระเงินผ่าน QR Code กรุณาแนบหลักฐานการโอนเงินภายใน 24 ชั่วโมง',
                'หากไม่ได้รับหลักฐานการโอนภายในเวลาที่กำหนด คำสั่งซื้อจะถูกยกเลิกอัตโนมัติ',
                'สำหรับ COD จะเก็บเงินเมื่อส่งมอบสินค้า (รับเฉพาะเงินสด)',
              ],
            ),

            // เงื่อนไขการจัดส่ง
            _buildPolicySection(
              title: 'เงื่อนไขการจัดส่ง',
              icon: Icons.local_shipping,
              items: [
                'ระยะเวลาจัดส่งภายในจังหวัดชัยนาท 1-2 วันทำการ',
                'ระยะเวลาจัดส่งต่างจังหวัด 3-5 วันทำการ',
                'ค่าจัดส่งขึ้นอยู่กับระยะทางและขนาดสินค้า',
                'ทางร้านจะติดต่อลูกค้าก่อนจัดส่งสินค้าทุกครั้ง',
                'กรณีไม่มีผู้รับสินค้า ทางร้านจะเก็บค่าใช้จ่ายในการจัดส่งซ้ำ',
              ],
            ),

            // เงื่อนไขการรับประกัน
            _buildPolicySection(
              title: 'เงื่อนไขการรับประกัน',
              icon: Icons.verified_user,
              items: [
                'รับประกันความชำรุดจากการผลิต 1 ปี',
                'รับประกันไม่ครอบคลุมความเสียหายจากการใช้งานผิดประเภท',
                'รับประกันไม่ครอบคลุมการสึกหรอตามธรรมชาติ',
                'กรณีต้องการใช้สิทธิ์รับประกัน กรุณาติดต่อร้านพร้อมหลักฐานการซื้อ',
              ],
            ),

            // เงื่อนไขการคืนสินค้า
            _buildPolicySection(
              title: 'เงื่อนไขการคืนสินค้า',
              icon: Icons.keyboard_return,
              items: [
                'สามารถคืนสินค้าได้ภายใน 7 วัน หากสินค้าไม่ตรงตามที่สั่ง',
                'สินค้าต้องอยู่ในสภาพเดิม ไม่ชำรุดจากการใช้งาน',
                'ลูกค้าเป็นผู้รับผิดชอบค่าจัดส่งในการส่งคืนสินค้า',
                'จะคืนเงินภายใน 7-14 วันทำการ หลังจากได้รับสินค้าคืน',
              ],
            ),

            // นโยบายความเป็นส่วนตัว
            _buildPolicySection(
              title: 'นโยบายความเป็นส่วนตัว',
              icon: Icons.privacy_tip,
              items: [
                'ทางร้านเก็บรักษาข้อมูลส่วนบุคคลของลูกค้าอย่างปลอดภัย',
                'ข้อมูลจะใช้เฉพาะการติดต่อเกี่ยวกับคำสั่งซื้อเท่านั้น',
                'ไม่นำข้อมูลลูกค้าไปใช้เพื่อการอื่นหรือให้บุคคลที่สาม',
                'ลูกค้าสามารถขอลบข้อมูลส่วนบุคคลได้ตามกฎหมาย',
              ],
            ),

            // Last Updated
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'ปรับปรุงล่าสุด: 7 สิงหาคม 2568',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
