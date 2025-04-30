import 'package:flutter/foundation.dart';
import '../models/invoice.dart';

class InvoiceProvider with ChangeNotifier {
  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      // For now, we'll just use an empty list
      _invoices = [];
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addInvoice(Invoice invoice) {
    _invoices.add(invoice);
    notifyListeners();
  }

  Future<Invoice?> getInvoiceById(String id) async {
    try {
      return _invoices.firstWhere((invoice) => invoice.id == id);
    } catch (e) {
      debugPrint('Error getting invoice: $e');
      return null;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    try {
      _invoices.removeWhere((invoice) => invoice.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }
}
