import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import '../utils/pdf_header.dart';

class WarrantyPage extends StatelessWidget {
  const WarrantyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Warranty Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select Warranty Type',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6A1B9A),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose the warranty category you want to manage.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF616161),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _WarrantyModuleCard(
                      title: 'Drug Inspector Warranty',
                      description: 'Manage inspector-side warranty records and compliance entries.',
                      icon: Icons.verified,
                      color: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DrugInspectorWarrantyPage(),
                          ),
                        );
                      },
                    ),
                    _WarrantyModuleCard(
                      title: 'Customer Warranty',
                      description: 'Manage customer warranty details, claims, and follow-up records.',
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF00897B),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CustomerWarrantyPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarrantyModuleCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WarrantyModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WarrantyModuleCard> createState() => _WarrantyModuleCardState();
}

class _WarrantyModuleCardState extends State<_WarrantyModuleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 280,
        constraints: const BoxConstraints(minHeight: 240),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: widget.color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isPressed ? 0.08 : 0.12),
              blurRadius: _isPressed ? 8 : 16,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.color.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 36,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF757575),
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrugInspectorWarrantyPage extends StatelessWidget {
  const DrugInspectorWarrantyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WarrantyEntryPage(
      title: 'Drug Inspector Warranty',
      icon: Icons.verified,
      color: Color(0xFF6A1B9A),
      description: 'Add one or more medicines with their batch numbers for the drug inspector warranty record.',
      warrantyText:
          'I hereby submit the following medicines for warranty claim. I confirm that the medicines listed below were received through proper channel and have remained under my custody.\n\nI take full responsibility and liability for the handling, storage, and condition of these medicines while they remained in my possession. The items are being returned for claim due to reasons mentioned below.',
    );
  }
}

class CustomerWarrantyPage extends StatelessWidget {
  const CustomerWarrantyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WarrantyEntryPage(
      title: 'Customer Warranty',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF00897B),
      description: 'Customers must add each medicine name together with its batch number before printing the warranty.',
      warrantyText: 'the warranty of the medicines given below',
    );
  }
}

class _WarrantyEntryPage extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String warrantyText;

  const _WarrantyEntryPage({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.warrantyText,
  });

  @override
  State<_WarrantyEntryPage> createState() => _WarrantyEntryPageState();
}

class _WarrantyEntryPageState extends State<_WarrantyEntryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_WarrantyMedicineEntry> _entries = [_WarrantyMedicineEntry()];

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _entries.add(_WarrantyMedicineEntry());
    });
  }

  void _removeEntry(int index) {
    if (_entries.length == 1) {
      return;
    }

    setState(() {
      final entry = _entries.removeAt(index);
      entry.dispose();
    });
  }

  Future<void> _printWarranty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pdf = pw.Document();
    final medicines = _entries
        .map(
          (entry) => _PrintedWarrantyMedicine(
            name: entry.medicineNameController.text.trim(),
            batchNumber: entry.batchNumberController.text.trim(),
          ),
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfHeaderHelper.buildSimpleHeader(
            subtitle: widget.title,
            rightSideInfo:
                'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\nTime: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            widget.warrantyText,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Medicines',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey700),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfCell('No.', isHeader: true),
                  _pdfCell('Medicine Name', isHeader: true),
                  _pdfCell('Batch No.', isHeader: true),
                ],
              ),
              ...List.generate(medicines.length, (index) {
                final medicine = medicines[index];
                return pw.TableRow(
                  children: [
                    _pdfCell('${index + 1}'),
                    _pdfCell(medicine.name),
                    _pdfCell(medicine.batchNumber),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Items: ${medicines.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Signature: _______________',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final now = DateTime.now();
      final fileName =
          '${widget.title.replaceAll(' ', '_')}_${now.day}_${now.month}_${now.year}.pdf';

      if (Platform.isWindows) {
        final desktopPath =
            Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
        final filePath = desktopPath.isNotEmpty ? '$desktopPath\\Desktop\\$fileName' : fileName;

        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        try {
          await OpenFilex.open(file.path);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF opened successfully! You can now print it.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Desktop. Please open it from: ${file.path}'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: fileName,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing warranty: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(widget.icon, size: 32, color: widget.color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: widget.color,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.description,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFF616161),
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.color.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            widget.warrantyText,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF424242),
                                  height: 1.5,
                                ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Medicines',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Medicine name and batch number are required for every entry.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF616161),
                              ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(_entries.length, (index) {
                          final entry = _entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Medicine ${index + 1}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const Spacer(),
                                      if (_entries.length > 1)
                                        TextButton.icon(
                                          onPressed: () => _removeEntry(index),
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Remove'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: entry.medicineNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Medicine Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Medicine name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: entry.batchNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Batch No.',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Batch number is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addEntry,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Medicine'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.color,
                            side: BorderSide(color: widget.color),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _printWarranty,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Print Warranty'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarrantyMedicineEntry {
  final TextEditingController medicineNameController = TextEditingController();
  final TextEditingController batchNumberController = TextEditingController();

  void dispose() {
    medicineNameController.dispose();
    batchNumberController.dispose();
  }
}

pw.Widget _pdfCell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

class _PrintedWarrantyMedicine {
  final String name;
  final String batchNumber;

  const _PrintedWarrantyMedicine({
    required this.name,
    required this.batchNumber,
  });
}
