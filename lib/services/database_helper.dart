import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/invoice.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'gst_billing_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  // Product CRUD operations
  Future<int> insertProduct(Product product) async {
    Database db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<int> updateProduct(Product product) async {
    Database db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    Database db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Invoice CRUD operations
  Future<String> insertInvoice(Invoice invoice) async {
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

  Future<List<Invoice>> getInvoices() async {
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
          id: itemMap['productId'],
          name: itemMap['name'],
          price: itemMap['price'],
          gstPercentage: itemMap['gstPercentage'],
          quantity: itemMap['quantity'],
        );
      }).toList();
      
      invoices.add(Invoice.fromMap(invoiceMap, products));
    }
    
    return invoices;
  }

  Future<Invoice?> getInvoiceById(String id) async {
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
        id: itemMap['productId'],
        name: itemMap['name'],
        price: itemMap['price'],
        gstPercentage: itemMap['gstPercentage'],
        quantity: itemMap['quantity'],
      );
    }).toList();
    
    return Invoice.fromMap(invoiceMaps.first, products);
  }

  Future<int> deleteInvoice(String id) async {
    Database db = await database;
    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
