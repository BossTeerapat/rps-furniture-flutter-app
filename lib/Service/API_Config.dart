import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String? get baseUrl => dotenv.env['BASE_URL'];

  // Authentication
  static String get register => "$baseUrl/api/Register";
  static String get loginApp => "$baseUrl/api/LoginApp";

  // Products
  static String get searchProduct => "$baseUrl/api/SearchProduct";
  static String get listProductsByStatus => "$baseUrl/api/ListProductsByStatus";
  static String get listCategories => "$baseUrl/api/ListCategories";
  static String get productDetail => "$baseUrl/api/ProductDetail";
  static String get productReview => "$baseUrl/api/ProductReview";
  static String get postProducts => "$baseUrl/api/PostProducts";
  static String get updateFaveriteProduct =>
      "$baseUrl/api/UpdateFaveriteProduct";
  static String get listFaveriteProduct => "$baseUrl/api/ListFaveriteProduct";
  static String get postReview => "$baseUrl/api/PostReview";

  // User Address
  static String get addUserAddress => "$baseUrl/api/AddUserAddress";
  static String get listLocation => "$baseUrl/api/ListLocation";
  static String get listUserAddress => "$baseUrl/api/ListUserAddress";
  static String get setDefaultAddress => "$baseUrl/api/SetDefaultAddress";
  static String get deleteUserAddress => "$baseUrl/api/DeleteUserAddress";
  static String get editUserAddress => "$baseUrl/api/EditUserAddress";

  // Cart
  static String get addToCart => "$baseUrl/api/AddToCart";
  static String get cart => "$baseUrl/api/Cart";
  static String get deleteProductInCart => "$baseUrl/api/DeleteProductInCart";
  static String get updateProductInCart => "$baseUrl/api/UpdateProductInCart";

  // Order & Payment
  static String get calculatePrice => "$baseUrl/api/CalculatePrice";
  static String get createOrder => "$baseUrl/api/CreateOrder";
  static String get listOrderBuyer => "$baseUrl/api/ListOrderBuyer";
  static String get payment => "$baseUrl/api/Payment";
  static String get postPayment => "$baseUrl/api/PostPayment";
  static String get editPayment => "$baseUrl/api/EditPayment";
  static String get uploadPayment => "$baseUrl/api/UploadPayment";
  static String get confirmOrder => "$baseUrl/api/ConfirmOrder";
  static String get listOrderAll => "$baseUrl/api/ListOrderAll";
  static String get shippingOrder => "$baseUrl/api/ShippingOrder";
  static String get completedOrder => "$baseUrl/api/CompletedOrder";
  static String get canceledOrder => "$baseUrl/api/CanceledOrder";
  static String get reviewHistory => "$baseUrl/api/ReviewHistory";

  // User Profile
  static String get profileDetail => "$baseUrl/api/ProfileDetail";
  static String get updateProfile => "$baseUrl/api/UpdateProfile";

  static String get saler => "$baseUrl/api/Saler";
  static String get stockProduct => "$baseUrl/api/StockProduct";
  static String get editProduct => "$baseUrl/api/EditProduct";
  static String get listAccount => "$baseUrl/api/ListAccount";
  static String get deleteAccount => "$baseUrl/api/DeleteAccount";
  static String get deleteProduct => "$baseUrl/api/DeleteProduct";
  
  // Employee
  static String get employeeOrders => "$baseUrl/api/EmployeeOrders";

  static Future<Map<String, String>> buildHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? '';
    return {
      'api-key': dotenv.env['API_KEY'] ?? '',
      'api-secret': dotenv.env['API_SECRET'] ?? '',
      'role': role,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}
