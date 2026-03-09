import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

class PdfHeaderHelper {
  // Company information
  static const String companyName = 'GOODLUCK MEDICINE COMPANY';
  static const String address = 'Shop No.8 Amin Medicine Market Chowk Urdu Bazar';
  static const String contact1 = '03014549183';
  static const String contact2 = '042-37361351';

  // Build standard PDF header with logo, address, and contact info
  static Future<pw.Widget> buildHeader({
    String? subtitle,
    String? rightSideInfo,
  }) async {
    // Try to load logo image (if available as PNG/JPG)
    // For now, we'll use text-based header since SVG needs conversion
    pw.ImageProvider? logoImage;
    
    try {
      // Try to load logo as image if available
      final logoBytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // Logo image not available, will use text-based header
      logoImage = null;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey800, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left side - Logo and Company Info
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo placeholder or company name
                if (logoImage != null)
                  pw.Image(logoImage!, width: 80, height: 80)
                else
                  pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey800),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'GL',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  address,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text(
                      'Contact: ',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$contact1, $contact2',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right side - Additional info (date, etc.)
          if (rightSideInfo != null)
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    rightSideInfo,
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build simplified header without logo (text-based)
  static pw.Widget buildSimpleHeader({
    String? subtitle,
    String? rightSideInfo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey800, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left side - Company Info
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  address,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text(
                      'Contact: ',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$contact1, $contact2',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right side - Additional info
          if (rightSideInfo != null)
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    rightSideInfo,
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
