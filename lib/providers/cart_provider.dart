import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../services/database_helper.dart';

class CartProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Product> _cartItems = [];
  String _customerName = '';
  String _customerPhone = '';

  List<Product> get cartItems => _cartItems;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;

  // Calculate subtotal (sum of all product prices without GST)
  double get subtotal {
    return _cartItems.fold(0, (sum, product) => sum + (product.price * product.quantity));
  }

  // Calculate total CGST
  double get totalCGST {
    return _cartItems.fold(0, (sum, product) => sum + (product.cgst * product.quantity));
  }

  // Calculate total SGST
  double get totalSGST {
    return _cartItems.fold(0, (sum, product) => sum + (product.sgst * product.quantity));
  }

  // Calculate total GST
  double get totalGST {
    return totalCGST + totalSGST;
  }

  // Calculate grand total
  double get grandTotal {
    return _cartItems.fold(0, (sum, product) => sum + product.totalPriceWithQuantity);
  }

  void setCustomerInfo(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void addToCart(Product product) {
    final existingIndex = _cartItems.indexWhere((item) => item.id == product.id);
    
    if (existingIndex != -1) {
      // If product already exists in cart, increment quantity
      _cartItems[existingIndex].quantity += 1;
    } else {
      // Otherwise add new product to cart
      _cartItems.add(product.copyWith(quantity: 1));
    }
    
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    
    final index = _cartItems.indexWhere((item) => item.id == productId);
    if (index != -1) {
      _cartItems[index].quantity = quantity;
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems = [];
    _customerName = '';
    _customerPhone = '';
    notifyListeners();
  }

  Future<Invoice> generateInvoice() {
    final invoice = Invoice(
      products: List.from(_cartItems),
      customerName: _customerName.isEmpty ? 'Walk-in Customer' : _customerName,
      customerPhone: _customerPhone,
    );
    
    return Future.value(invoice);
  }

  Future<String> saveInvoice() async {
    try {
      final invoice = await generateInvoice();
      final invoiceId = await _dbHelper.insertInvoice(invoice);
      return invoiceId;
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      rethrow;
    }
  }
}
