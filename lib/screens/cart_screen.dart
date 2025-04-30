import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../providers/cart_provider.dart';
import '../providers/invoice_provider.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'home_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Your cart is empty',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add products from the Products tab',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: cartProvider.cartItems.length,
                itemBuilder: (context, index) {
                  final product = cartProvider.cartItems[index];
                  return CartItemCard(product: product);
                },
              ),
            ),
            _buildCartSummary(context, cartProvider),
          ],
        );
      },
    );
  }

  Widget _buildCartSummary(BuildContext context, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text('₹${cartProvider.subtotal.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CGST:'),
              Text('₹${cartProvider.totalCGST.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SGST:'),
              Text('₹${cartProvider.totalSGST.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '₹${cartProvider.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCustomerInfoDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('GENERATE INVOICE'),
          ),
        ],
      ),
    );
  }

  void _showCustomerInfoDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String customerName = '';
    String customerPhone = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Information'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
                onSaved: (value) => customerName = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                keyboardType: TextInputType.phone,
                onSaved: (value) => customerPhone = value ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                
                final cartProvider = Provider.of<CartProvider>(context, listen: false);
                cartProvider.setCustomerInfo(customerName, customerPhone);
                
                final invoice = await cartProvider.generateInvoice();
                final invoiceId = await cartProvider.saveInvoice();
                
                if (!context.mounted) return;
                Navigator.pop(context);
                
                _showInvoiceGeneratedDialog(context, invoice);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceGeneratedDialog(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice Number: ${invoice.invoiceNumber}'),
            Text('Customer: ${invoice.customerName}'),
            Text('Total Amount: ₹${invoice.grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('What would you like to do next?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<CartProvider>(context, listen: false).clearCart();
            },
            child: const Text('New Bill'),
          ),
          TextButton(
            onPressed: () async {
              await _sharePdf(context);
            },
            child: const Text('Share PDF'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add the invoice to the provider before navigating
              Provider.of<InvoiceProvider>(context, listen: false).addInvoice(invoice);
              
              Navigator.pop(context);
              Provider.of<CartProvider>(context, listen: false).clearCart();
              
              // Navigate to invoices tab - use a more reliable method
              final scaffoldContext = ScaffoldMessenger.of(context).context;
              if (scaffoldContext != null) {
                Navigator.of(scaffoldContext).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(initialTabIndex: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('View All Invoices'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final invoiceId = await cartProvider.saveInvoice();
      
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final invoice = await invoiceProvider.getInvoiceById(invoiceId);
      
      if (invoice != null) {
        final pdfFile = await PdfService.generateInvoice(invoice);
        
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generation on web is not supported in this demo')),
          );
        } else if (Platform.isWindows) {
          // For Windows, just show a success message
          // We don't use Share.shareXFiles as it may not work reliably on Windows
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice saved successfully. PDF preview opened.'),
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Try to open the file with the default application
          try {
            // This is handled by the printing package in PdfService
            debugPrint('PDF generated at: ${pdfFile.path}');
          } catch (e) {
            debugPrint('Error opening PDF: $e');
          }
        } else {
          // For mobile platforms
          await Share.shareXFiles(
            [XFile(pdfFile.path)],
            subject: 'Invoice ${invoice.invoiceNumber}',
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice saved and shared successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class CartItemCard extends StatelessWidget {
  final Product product;

  const CartItemCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Price: ₹${product.price.toStringAsFixed(2)}'),
                  Text('GST: ${product.gstPercentage.toStringAsFixed(0)}%'),
                  Row(
                    children: [
                      Text('CGST: ₹${product.cgst.toStringAsFixed(2)}'),
                      const SizedBox(width: 8),
                      Text('SGST: ₹${product.sgst.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (product.quantity > 1) {
                          Provider.of<CartProvider>(context, listen: false)
                              .updateQuantity(product.id, product.quantity - 1);
                        } else {
                          _showRemoveItemConfirmation(context, product);
                        }
                      },
                    ),
                    Text(
                      '${product.quantity}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false)
                            .updateQuantity(product.id, product.quantity + 1);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${product.totalPriceWithQuantity.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showRemoveItemConfirmation(context, product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveItemConfirmation(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${product.name} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false)
                  .removeFromCart(product.id);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
