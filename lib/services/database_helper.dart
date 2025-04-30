import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/invoice.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static bool _isWeb = kIsWeb;

  // In-memory storage for web platform
  static final Map<String, dynamic> _webStorage = {
    'products': <Map<String, dynamic>>[],
    'invoices': <Map<String, dynamic>>[],
    'invoice_items': <Map<String, dynamic>>[],
  };

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      // For web platform, we need a different approach
      if (_isWeb) {
        // Use a dummy database for web
        return await openDatabase(
          ':memory:',
          version: 1,
          onCreate: _onCreate,
        );
      } else {
        // For mobile/desktop platforms
        String path = join(await getDatabasesPath(), 'gst_billing_app.db');
        return await openDatabase(
          path,
          version: 1,
          onCreate: _onCreate,
          onConfigure: _onConfigure,
        );
      }
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      // Create products table
      await db.execute('''
        CREATE TABLE products(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          gstPercentage REAL NOT NULL
        )
      ''');

      // Create invoices table
      await db.execute('''
        CREATE TABLE invoices(
          id TEXT PRIMARY KEY,
          invoiceNumber TEXT NOT NULL,
          dateTime TEXT NOT NULL,
          customerName TEXT NOT NULL,
          customerPhone TEXT,
          subtotal REAL NOT NULL,
          totalCGST REAL NOT NULL,
          totalSGST REAL NOT NULL,
          grandTotal REAL NOT NULL
        )
      ''');

      // Create invoice_items table to store products in each invoice
      await db.execute('''
        CREATE TABLE invoice_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoiceId TEXT NOT NULL,
          productId TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          price REAL NOT NULL,
          gstPercentage REAL NOT NULL,
          name TEXT NOT NULL,
          FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE,
          FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
      
      debugPrint('Database tables created successfully');
    } catch (e) {
      debugPrint('Error creating database tables: $e');
      rethrow;
    }
  }

  // Product CRUD operations
  Future<int> insertProduct(Product product) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final products = _webStorage['products'] as List<Map<String, dynamic>>;
        final existingIndex = products.indexWhere((p) => p['id'] == product.id);
        
        if (existingIndex != -1) {
          products[existingIndex] = product.toMap();
        } else {
          products.add(product.toMap());
        }
        
        debugPrint('Product inserted in web storage: ${product.name}');
        return 1; // Success
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        debugPrint('Inserting product: ${product.name}');
        final result = await db.insert(
          'products', 
          product.toMap(), 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
        debugPrint('Product inserted with result: $result');
        return result;
      }
    } catch (e) {
      debugPrint('Error inserting product: $e');
      return 0;
    }
  }

  Future<List<Product>> getProducts() async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final products = _webStorage['products'] as List<Map<String, dynamic>>;
        debugPrint('Retrieved ${products.length} products from web storage');
        return products.map((map) => Product.fromMap(map)).toList();
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        final List<Map<String, dynamic>> maps = await db.query('products');
        debugPrint('Retrieved ${maps.length} products from database');
        return List.generate(maps.length, (i) {
          return Product.fromMap(maps[i]);
        });
      }
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  Future<int> updateProduct(Product product) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final products = _webStorage['products'] as List<Map<String, dynamic>>;
        final index = products.indexWhere((p) => p['id'] == product.id);
        
        if (index != -1) {
          products[index] = product.toMap();
          return 1; // Success
        }
        return 0; // Not found
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        return await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
      return 0;
    }
  }

  Future<int> deleteProduct(String id) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final products = _webStorage['products'] as List<Map<String, dynamic>>;
        final initialLength = products.length;
        products.removeWhere((p) => p['id'] == id);
        return initialLength - products.length; // Return number of items removed
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        return await db.delete(
          'products',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return 0;
    }
  }

  // Invoice CRUD operations
  Future<String> insertInvoice(Invoice invoice) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final invoices = _webStorage['invoices'] as List<Map<String, dynamic>>;
        final invoiceItems = _webStorage['invoice_items'] as List<Map<String, dynamic>>;
        
        // Add invoice
        invoices.add(invoice.toMap());
        
        // Add invoice items
        for (var product in invoice.products) {
          invoiceItems.add({
            'invoiceId': invoice.id,
            'productId': product.id,
            'quantity': product.quantity,
            'price': product.price,
            'gstPercentage': product.gstPercentage,
            'name': product.name,
          });
        }
        
        return invoice.id;
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        await db.transaction((txn) async {
          // Insert invoice
          await txn.insert('invoices', invoice.toMap());

          // Insert invoice items
          for (var product in invoice.products) {
            await txn.insert('invoice_items', {
              'invoiceId': invoice.id,
              'productId': product.id,
              'quantity': product.quantity,
              'price': product.price,
              'gstPercentage': product.gstPercentage,
              'name': product.name,
            });
          }
        });
        return invoice.id;
      }
    } catch (e) {
      debugPrint('Error inserting invoice: $e');
      return '';
    }
  }

  Future<List<Invoice>> getInvoices() async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final invoices = _webStorage['invoices'] as List<Map<String, dynamic>>;
        final invoiceItems = _webStorage['invoice_items'] as List<Map<String, dynamic>>;
        
        List<Invoice> result = [];
        
        for (var invoiceMap in invoices) {
          final items = invoiceItems.where((item) => item['invoiceId'] == invoiceMap['id']).toList();
          
          List<Product> products = items.map((itemMap) {
            return Product(
              id: itemMap['productId'] as String,
              name: itemMap['name'] as String,
              price: itemMap['price'] as double,
              gstPercentage: itemMap['gstPercentage'] as double,
              quantity: itemMap['quantity'] as int,
            );
          }).toList();
          
          result.add(Invoice.fromMap(invoiceMap, products));
        }
        
        return result;
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        final List<Map<String, dynamic>> invoiceMaps = await db.query('invoices', orderBy: 'dateTime DESC');
        
        List<Invoice> invoices = [];
        
        for (var invoiceMap in invoiceMaps) {
          final List<Map<String, dynamic>> itemMaps = await db.query(
            'invoice_items',
            where: 'invoiceId = ?',
            whereArgs: [invoiceMap['id']],
          );
          
          List<Product> products = itemMaps.map((itemMap) {
            return Product(
              id: itemMap['productId'] as String,
              name: itemMap['name'] as String,
              price: itemMap['price'] as double,
              gstPercentage: itemMap['gstPercentage'] as double,
              quantity: itemMap['quantity'] as int,
            );
          }).toList();
          
          invoices.add(Invoice.fromMap(invoiceMap, products));
        }
        
        return invoices;
      }
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  Future<Invoice?> getInvoiceById(String id) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final invoices = _webStorage['invoices'] as List<Map<String, dynamic>>;
        final invoiceItems = _webStorage['invoice_items'] as List<Map<String, dynamic>>;
        
        final invoiceMap = invoices.firstWhere((inv) => inv['id'] == id, orElse: () => {});
        if (invoiceMap.isEmpty) return null;
        
        final items = invoiceItems.where((item) => item['invoiceId'] == id).toList();
        
        List<Product> products = items.map((itemMap) {
          return Product(
            id: itemMap['productId'] as String,
            name: itemMap['name'] as String,
            price: itemMap['price'] as double,
            gstPercentage: itemMap['gstPercentage'] as double,
            quantity: itemMap['quantity'] as int,
          );
        }).toList();
        
        return Invoice.fromMap(invoiceMap, products);
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        final List<Map<String, dynamic>> invoiceMaps = await db.query(
          'invoices',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        if (invoiceMaps.isEmpty) {
          return null;
        }
        
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'invoice_items',
          where: 'invoiceId = ?',
          whereArgs: [id],
        );
        
        List<Product> products = itemMaps.map((itemMap) {
          return Product(
            id: itemMap['productId'] as String,
            name: itemMap['name'] as String,
            price: itemMap['price'] as double,
            gstPercentage: itemMap['gstPercentage'] as double,
            quantity: itemMap['quantity'] as int,
          );
        }).toList();
        
        return Invoice.fromMap(invoiceMaps.first, products);
      }
    } catch (e) {
      debugPrint('Error getting invoice by id: $e');
      return null;
    }
  }

  Future<int> deleteInvoice(String id) async {
    try {
      if (_isWeb) {
        // For web, use in-memory storage
        final invoices = _webStorage['invoices'] as List<Map<String, dynamic>>;
        final invoiceItems = _webStorage['invoice_items'] as List<Map<String, dynamic>>;
        
        // Remove invoice items first
        invoiceItems.removeWhere((item) => item['invoiceId'] == id);
        
        // Then remove the invoice
        final initialLength = invoices.length;
        invoices.removeWhere((inv) => inv['id'] == id);
        return initialLength - invoices.length; // Return number of items removed
      } else {
        // For mobile/desktop, use SQLite
        Database db = await database;
        return await db.delete(
          'invoices',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return 0;
    }
  }
}
