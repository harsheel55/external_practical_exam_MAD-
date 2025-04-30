import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import 'package:printing/printing.dart';
import 'logo_util.dart';

class PdfService {
  static Future<File> generateInvoice(Invoice invoice) async {
    final pdf = pw.Document();

    // Load a standard font that supports Rupee symbol
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    
    // Get the TATA logo
    final logo = LogoUtil.getTataLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(invoice, fontBold, font, logo),
          pw.SizedBox(height: 20),
          _buildInvoiceInfo(invoice, fontBold, font),
          pw.SizedBox(height: 20),
          _buildItemsTable(invoice, fontBold, font),
          pw.SizedBox(height: 20),
          _buildTotal(invoice, fontBold, font),
          pw.SizedBox(height: 20),
          _buildFooter(font),
        ],
      ),
    );

    try {
      // For web platform, we need a different approach
      if (kIsWeb) {
        // For web, we can't use File, so we'll return a dummy file
        // In a real app, you would use a different approach for web
        throw UnsupportedError('PDF generation on web is not supported in this demo');
      } else {
        // For mobile/desktop platforms
        Directory appDocDir;
        
        try {
          if (Platform.isWindows) {
            // For Windows, use a more reliable directory
            final tempDir = await getTemporaryDirectory();
            appDocDir = Directory(tempDir.path);
          } else if (Platform.isLinux || Platform.isMacOS) {
            // For other desktop platforms
            appDocDir = await getApplicationDocumentsDirectory();
          } else {
            // For mobile platforms
            appDocDir = await getTemporaryDirectory();
          }
          
          // Ensure the directory exists
          if (!await appDocDir.exists()) {
            await appDocDir.create(recursive: true);
          }
        } catch (e) {
          // Fallback to temp directory if there's an issue
          appDocDir = await getTemporaryDirectory();
          debugPrint('Using fallback directory: ${appDocDir.path}');
        }
        
        final fileName = 'invoice_${invoice.invoiceNumber.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(':', '_')}.pdf';
        final pdfPath = '${appDocDir.path}${Platform.pathSeparator}$fileName';
        
        debugPrint('Saving PDF to: $pdfPath');
        
        final file = File(pdfPath);
        await file.writeAsBytes(await pdf.save());
        
        // Open the PDF for preview on desktop platforms
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdf.save(),
          );
        }
        
        return file;
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }

  static pw.Widget _buildHeader(Invoice invoice, pw.Font fontBold, pw.Font font, pw.Widget logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TATA RETAIL SOLUTIONS',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 24,
                  ),
                ),
                pw.Text(
                  'GST Billing System',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 16,
                  ),
                ),
                pw.Text(
                  'GSTIN: 27AABCT3518Q1ZX',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            pw.Container(
              height: 80,
              width: 80,
              child: pw.Center(
                child: logo,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildInvoiceInfo(Invoice invoice, pw.Font fontBold, pw.Font font) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Invoice To:', style: pw.TextStyle(font: font)),
                pw.Text(
                  invoice.customerName,
                  style: pw.TextStyle(
                    font: fontBold,
                  ),
                ),
                if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                  pw.Text('Phone: ${invoice.customerPhone}', style: pw.TextStyle(font: font)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Invoice Number:', style: pw.TextStyle(font: font)),
                pw.Text(
                  invoice.invoiceNumber,
                  style: pw.TextStyle(
                    font: fontBold,
                  ),
                ),
                pw.Text('Date: ${dateFormat.format(invoice.dateTime)}', style: pw.TextStyle(font: font)),
                pw.Text('Time: ${timeFormat.format(invoice.dateTime)}', style: pw.TextStyle(font: font)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(Invoice invoice, pw.Font fontBold, pw.Font font) {
    final headers = [
      'Item',
      'Price',
      'GST %',
      'CGST',
      'SGST',
      'Qty',
      'Total',
    ];

    final data = invoice.products.map((product) {
      return [
        product.name,
        '₹${product.price.toStringAsFixed(2)}',
        '${product.gstPercentage.toStringAsFixed(0)}%',
        '₹${product.cgst.toStringAsFixed(2)}',
        '₹${product.sgst.toStringAsFixed(2)}',
        '${product.quantity}',
        '₹${product.totalPriceWithQuantity.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(font: fontBold),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellHeight: 30,
      cellStyle: pw.TextStyle(font: font),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
        6: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildTotal(Invoice invoice, pw.Font fontBold, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        children: [
          pw.Spacer(flex: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:', style: pw.TextStyle(font: font)),
                    pw.Text('₹${invoice.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CGST:', style: pw.TextStyle(font: font)),
                    pw.Text('₹${invoice.totalCGST.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SGST:', style: pw.TextStyle(font: font)),
                    pw.Text('₹${invoice.totalSGST.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total:',
                      style: pw.TextStyle(
                        font: fontBold,
                      ),
                    ),
                    pw.Text(
                      '₹${invoice.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: fontBold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(
            font: font,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'This is a computer-generated invoice and does not require a signature.',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
