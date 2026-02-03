import 'package:flutter/material.dart';

abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('th', 'TH'),
    Locale('en', 'US'),
  ];

  // App Name and Brand
  String get appName;
  String get appNameEng;
  String get brandSlogan;

  // Sales
  String get sales;
  // Navigation
  String get home;
  String get favorite;
  String get order;
  String get menu;

  // Welcome Messages
  String get welcome;

  // Common Actions
  String get search;
  String get cancel;

  // Menu Items
  String get userAccount;
  String get profile;
  String get profileSubtitle;
  String get address;
  String get addressSubtitle;
  String get shopping;
  String get orderHistory;
  String get orderHistorySubtitle;
  String get reviews;
  String get reviewsSubtitle;
  String get customerService;
  String get contactUs;
  String get contactUsSubtitle;
  String get policies;
  String get policiesSubtitle;
  String get appSettings;
  String get security;
  String get securitySubtitle;
  String get logout;
  String get logoutConfirm;
  String get logoutQuestion;
  String get version;

  // Login & Authentication
  String get login;
  String get username;
  String get usernameHint;
  String get usernameRequired;
  String get password;
  String get passwordHint;
  String get passwordRequired;
  String get forgotPassword;
  String get noAccount;
  String get register;

  // Settings
  String get language;
  String get thai;
  String get english;
  String get changeLanguage;

  // Additional common keys used across the app
  String get products;
  String get cart;
  String get settings;
  String get notifications;
  String get notificationsSubtitle;
  String get paymentMethods;
  String get paymentMethodsSubtitle;
  String get shipping;
  String get shippingSubtitle;
  String get faq;
  String get faqSubtitle;
  String get aboutUs;
  String get aboutUsSubtitle;
  String get welcomeMessage;
  String get confirm;
  String get save;
  String get delete;
  String get edit;
  String get appTheme;
  String get pleaseLogin;
  String get deleteConfirmTitle;
  String get deleteConfirmContent;
  String get retry;
  String get cartEmptyTitle;
  String get cartEmptySubtitle;
  String get selectAll;
  String get items;
  String get remaining;
  String get piece;
  String get select;
  String get selectedItems;
  String get totalLabel;
  String get checkoutLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'th':
        return AppLocalizationsTh();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool isSupported(Locale locale) {
    return ['en', 'th'].contains(locale.languageCode);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Thai Localization
class AppLocalizationsTh extends AppLocalizations {
  @override
  String get appName => 'รุ่งประเสริฐเฟอร์นิเจอร์';

  @override
  String get sales => 'ยอดขาย';
  @override
  String get appNameEng => 'RPS Furniture';

  @override
  String get brandSlogan => 'เฟอร์นิเจอร์คุณภาพ ราคาเป็นกันเอง';

  @override
  String get home => 'หน้าหลัก';

  String get products => 'สินค้า';

  String get cart => 'ตะกร้า';

  @override
  String get profile => 'โปรไฟล์';

  String get settings => 'ตั้งค่า';

  @override
  String get favorite => 'รายการโปรด';

  @override
  String get order => 'คำสั่งซื้อ';

  @override
  String get menu => 'เมนู';

  // Menu Items - Thai
  @override
  String get userAccount => 'บัญชีผู้ใช้';

  @override
  String get profileSubtitle => 'จัดการข้อมูลส่วนตัว';

  @override
  String get address => 'ที่อยู่';

  @override
  String get addressSubtitle => 'จัดการที่อยู่จัดส่ง';

  String get notifications => 'การแจ้งเตือน';

  String get notificationsSubtitle => 'ตั้งค่าการแจ้งเตือน';

  @override
  String get shopping => 'การซื้อขาย';

  @override
  String get orderHistory => 'ประวัติการสั่งซื้อ';

  @override
  String get orderHistorySubtitle => 'ดูประวัติการสั่งซื้อทั้งหมด';

  String get paymentMethods => 'วิธีการชำระเงิน';

  String get paymentMethodsSubtitle => 'จัดการบัตรเครดิต/เดบิต';

  String get shipping => 'การจัดส่ง';

  String get shippingSubtitle => 'ติดตามสถานะการจัดส่ง';

  @override
  String get reviews => 'รีวิวของฉัน';

  @override
  String get reviewsSubtitle => 'รีวิวสินค้าที่ซื้อแล้ว';

  @override
  String get customerService => 'บริการลูกค้า';

  @override
  String get contactUs => 'ติดต่อเรา';

  @override
  String get contactUsSubtitle => 'แชท หรือโทรหาทีมงาน';

  String get faq => 'คำถามที่พบบ่อย';

  String get faqSubtitle => 'คำตอบสำหรับคำถามทั่วไป';

  @override
  String get policies => 'นโยบายและเงื่อนไข';

  @override
  String get policiesSubtitle => 'นโยบายความเป็นส่วนตัว';

  String get aboutUs => 'เกี่ยวกับเรา';

  String get aboutUsSubtitle => 'รุ่งประเสริฐเฟอร์นิเจอร์';

  @override
  String get appSettings => 'ตั้งค่า';

  String get appTheme => 'ธีมแอป';

  @override
  String get security => 'ช่วยเหลือ';

  @override
  String get securitySubtitle => 'ช่วยเหลือเกี่ยวกับแอป';

  @override
  String get logout => 'ออกจากระบบ';

  @override
  String get logoutConfirm => 'ออกจากระบบ';

  @override
  String get logoutQuestion => 'คุณต้องการออกจากระบบหรือไม่?';

  @override
  String get version => 'เวอร์ชัน';

  @override
  String get welcome => 'ยินดีต้อนรับสู่';

  String get welcomeMessage => 'ร้านรุ่งประเสริฐเฟอร์นิเจอร์';

  @override
  String get pleaseLogin => 'กรุณาเข้าสู่ระบบ';

  @override
  String get deleteConfirmTitle => 'ยืนยันการลบ';

  @override
  String get deleteConfirmContent => 'คุณต้องการลบสินค้านี้จากตะกร้าหรือไม่?';

  @override
  String get retry => 'ลองใหม่';

  @override
  String get cartEmptyTitle => 'ตะกร้าสินค้าว่าง';

  @override
  String get cartEmptySubtitle => 'เพิ่มสินค้าลงในตะกร้าเพื่อเริ่มซื้อของ';

  @override
  String get selectAll => 'เลือกทั้งหมด';

  @override
  String get items => 'รายการ';

  @override
  String get selectedItems => 'เลือก {count} รายการ';

  @override
  String get totalLabel => 'รวม';

  @override
  String get checkoutLabel => 'สั่งซื้อ';

  @override
  String get remaining => 'เหลือ';

  @override
  String get piece => 'ชิ้น';

  @override
  String get select => 'เลือก';

  @override
  String get search => 'ค้นหา';

  @override
  String get cancel => 'ยกเลิก';

  String get confirm => 'ยืนยัน';

  String get save => 'บันทึก';

  String get delete => 'ลบ';

  String get edit => 'แก้ไข';

  @override
  String get language => 'ภาษา';

  @override
  String get thai => 'ไทย';

  @override
  String get english => 'อังกฤษ';

  @override
  String get changeLanguage => 'เปลี่ยนภาษา';

  // Login & Authentication - Thai
  @override
  String get login => 'เข้าสู่ระบบ';

  @override
  String get username => 'ชื่อผู้ใช้';

  @override
  String get usernameHint => 'กรอกชื่อผู้ใช้ของคุณ';

  @override
  String get usernameRequired => 'กรุณากรอกชื่อผู้ใช้';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get passwordHint => 'กรอกรหัสผ่านของคุณ';

  @override
  String get passwordRequired => 'กรุณากรอกรหัสผ่าน';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get noAccount => 'ยังไม่มีบัญชี?';

  @override
  String get register => 'สมัครสมาชิก';
}

// English Localization
class AppLocalizationsEn extends AppLocalizations {
  @override
  String get appName => 'Rung Prasert Furniture';

  @override
  String get sales => 'Sales';
  @override
  String get appNameEng => 'RPS Furniture';

  @override
  String get brandSlogan => 'Quality Furniture, Affordable Price';

  @override
  String get home => 'Home';

  @override
  String get favorite => 'Favorites';

  @override
  String get order => 'Order';

  @override
  String get menu => 'Menu';

  @override
  String get products => 'Products';

  @override
  String get cart => 'Cart';

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Notification settings';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get paymentMethodsSubtitle => 'Manage credit/debit cards';

  @override
  String get shipping => 'Shipping';

  @override
  String get shippingSubtitle => 'Track delivery status';

  @override
  String get faq => 'FAQ';

  @override
  String get faqSubtitle => 'Answers to common questions';

  @override
  String get aboutUs => 'About Us';

  @override
  String get aboutUsSubtitle => 'Rung Prasert Furniture';

  @override
  String get welcomeMessage => 'Rung Prasert Furniture Store';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get appTheme => 'App Theme';

  // Menu Items - English
  @override
  String get userAccount => 'User Account';

  @override
  String get profile => 'Profile';

  @override
  String get profileSubtitle => 'Manage personal information';

  @override
  String get address => 'Address';

  @override
  String get addressSubtitle => 'Manage delivery addresses';

  @override
  String get shopping => 'Shopping';

  @override
  String get orderHistory => 'Order History';

  @override
  String get orderHistorySubtitle => 'View all order history';

  @override
  String get reviews => 'Reviews & Ratings';

  @override
  String get reviewsSubtitle => 'Review purchased products';

  @override
  String get customerService => 'Customer Service';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get contactUsSubtitle => 'Chat or call our team';

  @override
  String get policies => 'Policies & Terms';

  @override
  String get policiesSubtitle => 'Privacy policy';

  @override
  String get appSettings => 'Settings';

  @override
  String get security => 'Help';

  @override
  String get securitySubtitle => 'Help with the app';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Logout';

  @override
  String get logoutQuestion => 'Do you want to logout?';

  @override
  String get version => 'Version';

  @override
  String get welcome => 'Welcome to';

  @override
  String get search => 'Search';

  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';

  @override
  String get thai => 'Thai';

  @override
  String get english => 'English (Beta)';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get pleaseLogin => 'Please login';

  @override
  String get deleteConfirmTitle => 'Confirm Delete';

  @override
  String get deleteConfirmContent => 'Do you want to remove this item from cart?';

  @override
  String get retry => 'Retry';

  @override
  String get cartEmptyTitle => 'Cart is empty';

  @override
  String get cartEmptySubtitle => 'Add products to your cart to start shopping';

  @override
  String get selectAll => 'Select All';

  @override
  String get items => 'items';

  @override
  String get selectedItems => 'Selected {count} items';

  @override
  String get totalLabel => 'Total';

  @override
  String get checkoutLabel => 'Checkout';

  @override
  String get remaining => 'remaining';

  @override
  String get piece => 'piece';

  @override
  String get select => 'Select';

  // Login & Authentication - English
  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Enter your username';

  @override
  String get usernameRequired => 'Please enter username';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordRequired => 'Please enter password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get register => 'Register';
}
