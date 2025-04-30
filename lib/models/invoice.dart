import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'product.dart';

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime dateTime;
  final List<Product> products;
  final String customerName;
  final String? customerPhone;

  Invoice({
    String? id,
    String? invoiceNumber,
    DateTime? dateTime,
    required this.products,
    required this.customerName,
    this.customerPhone,
  })  : id = id ?? const Uuid().v4(),
        invoiceNumber = invoiceNumber ?? 'INV-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}',
        dateTime = dateTime ?? DateTime.now();

  // Calculate subtotal (sum of all product prices without GST)
  double get subtotal {
    return products.fold(0, (sum, product) => sum + (product.price * product.quantity));
  }

  // Calculate total CGST
  double get totalCGST {
    return products.fold(0, (sum, product) => sum + (product.cgst * product.quantity));
  }

  // Calculate total SGST
  double get totalSGST {
    return products.fold(0, (sum, product) => sum + (product.sgst * product.quantity));
  }

  // Calculate total GST
  double get totalGST {
    return totalCGST + totalSGST;
  }

  // Calculate grand total
  double get grandTotal {
    return products.fold(0, (sum, product) => sum + product.totalPriceWithQuantity);
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'dateTime': dateTime.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'subtotal': subtotal,
      'totalCGST': totalCGST,
      'totalSGST': totalSGST,
      'grandTotal': grandTotal,
    };
  }

  // Create Invoice from Map
  factory Invoice.fromMap(Map<String, dynamic> map, List<Product> products) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'],
      dateTime: DateTime.parse(map['dateTime']),
      products: products,
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
    );
  }
}
