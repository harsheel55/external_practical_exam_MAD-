import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../services/database_helper.dart';

class InvoiceProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _invoices = await _dbHelper.getInvoices();
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Invoice?> getInvoiceById(String id) async {
    try {
      return await _dbHelper.getInvoiceById(id);
    } catch (e) {
      debugPrint('Error getting invoice: $e');
      return null;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    try {
      await _dbHelper.deleteInvoice(id);
      _invoices.removeWhere((invoice) => invoice.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }
}
