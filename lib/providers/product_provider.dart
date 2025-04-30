import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/database_helper.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Product> _products = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _dbHelper.getProducts();
      
      // If no products exist, add sample products
      if (_products.isEmpty) {
        await _addSampleProducts();
        _products = await _dbHelper.getProducts();
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _addSampleProducts() async {
    // Add some sample products for testing
    final sampleProducts = [
      Product(
        id: const Uuid().v4(),
        name: 'Laptop',
        price: 45000,
        gstPercentage: 18,
      ),
      Product(
        id: const Uuid().v4(),
        name: 'Mobile Phone',
        price: 15000,
        gstPercentage: 12,
      ),
      Product(
        id: const Uuid().v4(),
        name: 'Headphones',
        price: 2000,
        gstPercentage: 28,
      ),
      Product(
        id: const Uuid().v4(),
        name: 'Notebook',
        price: 100,
        gstPercentage: 5,
      ),
    ];
    
    for (var product in sampleProducts) {
      await _dbHelper.insertProduct(product);
    }
  }

  Future<bool> addProduct(String name, double price, double gstPercentage) async {
    try {
      final product = Product(
        id: const Uuid().v4(),
        name: name,
        price: price,
        gstPercentage: gstPercentage,
      );

      final result = await _dbHelper.insertProduct(product);
      if (result > 0) {
        _products.add(product);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final result = await _dbHelper.updateProduct(product);
      if (result > 0) {
        final index = _products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _products[index] = product;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final result = await _dbHelper.deleteProduct(id);
      if (result > 0) {
        _products.removeWhere((product) => product.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }
}
