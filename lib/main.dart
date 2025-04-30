import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/invoice_provider.dart';
import 'screens/home_screen.dart';

void main() {
  // Initialize FFI for desktop platforms
  if (!kIsWeb) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory for desktop
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
      ],
      child: MaterialApp(
        title: 'TATA Retail GST Billing App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
