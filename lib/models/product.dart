class Product {
  final String id;
  final String name;
  final double price;
  final double gstPercentage;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.gstPercentage,
    this.quantity = 1,
  });

  
  double get cgst => (price * gstPercentage / 100) / 2;
  double get sgst => (price * gstPercentage / 100) / 2;
  double get totalPrice => price + cgst + sgst;
  double get totalPriceWithQuantity => totalPrice * quantity;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? gstPercentage,
    int? quantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      quantity: quantity ?? this.quantity,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'gstPercentage': gstPercentage,
    };
  }

  // Create Product from Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: map['price'] as double,
      gstPercentage: map['gstPercentage'] as double,
      quantity: map['quantity'] != null ? map['quantity'] as int : 1,
    );
  }
}
