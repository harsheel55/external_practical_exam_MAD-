import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LogoUtil {
  // This method creates a simple TATA logo as a PDF widget
  static pw.Widget getTataLogo() {
    // Create a simple TATA logo using PDF widgets
    return pw.Container(
      height: 80,
      width: 80,
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.0, 0.447, 0.698), // TATA Blue
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Center(
        child: pw.Text(
          'TATA',
          style: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
