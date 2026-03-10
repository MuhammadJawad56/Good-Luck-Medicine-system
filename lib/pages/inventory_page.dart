import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import '../models/medicine.dart';
import '../widgets/cheque_notification_overlay.dart';
import '../utils/pdf_header.dart';
import '../services/inventory_service.dart';
import '../services/data_persistence_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final List<Medicine> _medicines = [];
  final TextEditingController _searchController = TextEditingController();
  final InventoryService _inventoryService = InventoryService();
  final DataPersistenceService _dataService = DataPersistenceService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inventoryService.addListener(_onInventoryServiceChanged);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final medicines = await _dataService.loadMedicines();
      print('Loaded ${medicines.length} medicines from storage');
      _inventoryService.setMedicines(medicines);
      setState(() {
        _medicines.clear();
        _medicines.addAll(medicines);
        _isLoading = false;
      });
      print('UI updated with ${_medicines.length} medicines');
    } catch (e) {
      print('Error loading medicines: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    try {
      // Save from inventory service to ensure we have the latest data
      print('Saving ${_inventoryService.medicines.length} medicines to storage');
      await _dataService.saveMedicines(_inventoryService.medicines);
      print('Medicines saved successfully');
    } catch (e) {
      print('Error saving medicines: $e');
      rethrow;
    }
  }

  void _onInventoryServiceChanged() {
    // Sync local state with inventory service
    // This is called automatically when inventory service changes
    if (mounted) {
      setState(() {
        _medicines.clear();
        _medicines.addAll(_inventoryService.medicines);
        print('_onInventoryServiceChanged: Updated UI with ${_medicines.length} medicines');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inventoryService.removeListener(_onInventoryServiceChanged);
    super.dispose();
  }

  // Filter medicines by search query only - medicines with zero quantity remain in list
  List<Medicine> get _filteredMedicines {
    if (_searchController.text.isEmpty) {
      return _medicines; // Return all medicines, including those with zero quantity
    }
    final query = _searchController.text.toLowerCase();
    return _medicines.where((medicine) {
      return medicine.name.toLowerCase().contains(query) ||
          medicine.batchNumber.toLowerCase().contains(query);
      // Note: Medicines with zero quantity are NOT filtered out - they remain visible
    }).toList();
  }

  void _showAddMedicineDialog({Medicine? existingMedicine}) {
    final nameController = TextEditingController(text: existingMedicine?.name ?? '');
    final batchController = TextEditingController(text: existingMedicine?.batchNumber ?? '');
    final quantityController = TextEditingController(text: existingMedicine?.quantity.toString() ?? '');
    final purchasingCostController = TextEditingController(text: existingMedicine?.purchasingCost.toString() ?? '');
    final sellingCostController = TextEditingController(text: existingMedicine?.averageSellingCost.toString() ?? '');

    final isUpdate = existingMedicine != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdate ? 'Update Medicine' : 'Add New Medicine'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Batch Number (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Leave empty to auto-assign',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purchasingCostController,
                decoration: const InputDecoration(
                  labelText: 'Purchasing Cost (PKR)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sellingCostController,
                decoration: const InputDecoration(
                  labelText: 'Average Selling Cost (PKR)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  quantityController.text.isNotEmpty &&
                  purchasingCostController.text.isNotEmpty &&
                  sellingCostController.text.isNotEmpty) {
                // Determine batch number
                String finalBatchNumber = batchController.text.trim();
                
                if (isUpdate) {
                  // Update existing medicine
                  final index = _medicines.indexWhere((m) => m.id == existingMedicine.id);
                  if (index != -1) {
                    // If batch is empty, keep the existing batch number
                    if (finalBatchNumber.isEmpty) {
                      finalBatchNumber = existingMedicine.batchNumber;
                    }
                    final updatedMedicine = Medicine(
                      id: existingMedicine.id,
                      name: nameController.text,
                      batchNumber: finalBatchNumber,
                      quantity: int.tryParse(quantityController.text) ?? 0,
                      purchasingCost: double.tryParse(purchasingCostController.text) ?? 0.0,
                      averageSellingCost: double.tryParse(sellingCostController.text) ?? 0.0,
                    );
                    _inventoryService.updateMedicine(existingMedicine.id, updatedMedicine);
                    await _saveData();
                    if (!mounted) return;
                    Navigator.pop(context);
                    _showUpdateNotification('Medicine updated successfully!');
                  }
                } else {
                  // Check for duplicate medicine by name only
                  Medicine? duplicateMedicine;
                  
                  for (var medicine in _medicines) {
                    if (medicine.name.toLowerCase() == nameController.text.toLowerCase()) {
                      duplicateMedicine = medicine;
                      break;
                    }
                  }

                  if (duplicateMedicine != null) {
                    // If batch number is empty, use the existing batch number
                    if (finalBatchNumber.isEmpty) {
                      finalBatchNumber = duplicateMedicine.batchNumber;
                    }
                    
                    // Automatically update existing medicine - ADD quantity instead of replacing
                    final index = _medicines.indexWhere((m) => m.id == duplicateMedicine!.id);
                    if (index != -1) {
                      final newQuantity = int.tryParse(quantityController.text) ?? 0;
                      final oldQuantity = duplicateMedicine.quantity;
                      final totalQuantity = oldQuantity + newQuantity;
                      
                      // Update with new costs and add quantity
                      final updatedMedicine = Medicine(
                        id: duplicateMedicine.id,
                        name: nameController.text,
                        batchNumber: finalBatchNumber,
                        quantity: totalQuantity, // Add new quantity to old quantity
                        purchasingCost: double.tryParse(purchasingCostController.text) ?? 0.0,
                        averageSellingCost: double.tryParse(sellingCostController.text) ?? 0.0,
                      );
                      _inventoryService.updateMedicine(duplicateMedicine!.id, updatedMedicine);
                      await _saveData();
                      if (!mounted) return;
                      Navigator.pop(context);
                      _showUpdateNotification(
                        'Medicine updated! Added $newQuantity to existing stock. Total quantity: $totalQuantity',
                      );
                    }
                  } else {
                    // No duplicate found - auto-generate batch number if empty
                    if (finalBatchNumber.isEmpty) {
                      finalBatchNumber = _generateBatchNumber();
                    }
                    
                    // Add new medicine
                    final newMedicine = Medicine(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      batchNumber: finalBatchNumber,
                      quantity: int.tryParse(quantityController.text) ?? 0,
                      purchasingCost: double.tryParse(purchasingCostController.text) ?? 0.0,
                      averageSellingCost: double.tryParse(sellingCostController.text) ?? 0.0,
                    );
                    _inventoryService.addMedicine(newMedicine);
                    print('Added to inventory service: ${_inventoryService.medicines.length} medicines');
                    await _saveData();
                    if (!mounted) return;
                    Navigator.pop(context);
                    _showUpdateNotification('Medicine added successfully! Batch: $finalBatchNumber');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: Text(isUpdate ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  String _generateBatchNumber() {
    // Generate a unique batch number: 1 letter + 6 digits (max 7 characters)
    // Start with a random alphabet (A-Z)
    final random = Random();
    final alphabet = String.fromCharCode(65 + random.nextInt(26)); // A-Z
    // Generate 6 random digits
    final digits = random.nextInt(999999).toString().padLeft(6, '0');
    return '$alphabet$digits'; // Format: A123456 (7 characters total)
  }

  void _showUpdateConfirmationDialog(
    Medicine existingMedicine,
    String newName,
    String newBatch,
    int newQuantity,
    double newPurchasingCost,
    double newSellingCost,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Medicine Already Exists'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A medicine with the same name or batch number already exists:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${existingMedicine.name}'),
                  Text('Batch: ${existingMedicine.batchNumber}'),
                  Text('Current Quantity: ${existingMedicine.quantity}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Do you want to update the existing entry?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = _medicines.indexWhere((m) => m.id == existingMedicine.id);
                if (index != -1) {
                  _medicines[index] = Medicine(
                    id: existingMedicine.id,
                    name: newName,
                    batchNumber: newBatch,
                    quantity: newQuantity,
                    purchasingCost: newPurchasingCost,
                    averageSellingCost: newSellingCost,
                  );
                }
              });
              Navigator.pop(context);
              _showUpdateNotification('Medicine updated successfully!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteMedicine(Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete ${medicine.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _inventoryService.removeMedicine(medicine.id);
              await _saveData();
              if (!mounted) return;
              Navigator.pop(context);
              _showUpdateNotification('Medicine deleted successfully!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUpdateNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _printOrderForm() async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo, address, and contact info
              PdfHeaderHelper.buildSimpleHeader(
                subtitle: 'Order Form',
                rightSideInfo: 'Date: ${now.day}/${now.month}/${now.year}\nTime: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              ),
              pw.SizedBox(height: 20),
              
              // Table Header
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey800),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'S.No',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Medicine Name',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Batch Number',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Quantity',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Amount (PKR)',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  // Medicine rows
                  ...List.generate(_medicines.length, (index) {
                    final medicine = _medicines[index];
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${index + 1}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            medicine.name,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            medicine.batchNumber,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '', // Empty quantity column
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '', // Empty amount column
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Items: ${_medicines.length}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Signature: _______________',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      
      // For Windows desktop, save PDF to Desktop and open with default application
      if (Platform.isWindows) {
        // Get Desktop path from environment variable
        final desktopPath = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
        final filePath = desktopPath.isNotEmpty 
            ? '$desktopPath\\Desktop\\Order_Form_${now.day}_${now.month}_${now.year}.pdf'
            : 'Order_Form_${now.day}_${now.month}_${now.year}.pdf';
        
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        
        // Open the PDF with default application (which can print)
        try {
          await OpenFilex.open(file.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF opened successfully! You can now print it.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved to Desktop. Please open it from: ${file.path}'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      } else {
        // For other platforms, use sharePdf
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Order_Form_${now.day}_${now.month}_${now.year}.pdf',
        );
      }
    } catch (e) {
      // Show error message if printing fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _medicines.where((m) => m.quantity > 0 && m.quantity < 10).length;
    final outOfStockCount = _medicines.where((m) => m.quantity == 0).length;
    final totalProfit = _medicines.fold<double>(
      0.0,
      (sum, medicine) => sum + medicine.totalProfit,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Inventory Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and Add Button Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by name or batch number...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddMedicineDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medicine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _printOrderForm,
                    icon: const Icon(Icons.print),
                    label: const Text('Order Form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Medicines',
                      value: '${_medicines.length}',
                      icon: Icons.inventory_2,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Low Stock',
                      value: '$lowStockCount',
                      icon: Icons.warning,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Out of Stock',
                      value: '$outOfStockCount',
                      icon: Icons.error,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Profit',
                      value: 'PKR ${totalProfit.toStringAsFixed(2)}',
                      icon: Icons.trending_up,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _TableHeader('Medicine Name')),
                    Expanded(child: _TableHeader('Batch No.')),
                    Expanded(child: _TableHeader('Quantity')),
                    Expanded(child: _TableHeader('Purchase Cost')),
                    Expanded(child: _TableHeader('Selling Cost')),
                    Expanded(child: _TableHeader('Profit')),
                    Expanded(child: _TableHeader('Actions')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Medicines List
              Expanded(
                child: _filteredMedicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _medicines.isEmpty
                                  ? 'No medicines found'
                                  : 'No medicines match your search',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _medicines.isEmpty
                                  ? 'Click "Add Medicine" to get started'
                                  : 'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final medicine = _filteredMedicines[index];
                          final isLowStock = medicine.quantity > 0 && medicine.quantity < 10;
                          final isOutOfStock = medicine.quantity == 0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isOutOfStock
                                      ? Colors.red.withOpacity(0.3)
                                      : isLowStock
                                          ? Colors.orange.withOpacity(0.3)
                                          : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      medicine.name,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      medicine.batchNumber,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          '${medicine.quantity}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isOutOfStock
                                                    ? Colors.red
                                                    : isLowStock
                                                        ? Colors.orange
                                                        : Theme.of(context).colorScheme.onSurface,
                                              ),
                                        ),
                                        if (isLowStock || isOutOfStock)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Icon(
                                              isOutOfStock ? Icons.error : Icons.warning,
                                              size: 16,
                                              color: isOutOfStock ? Colors.red : Colors.orange,
                                            ),
                                          ),
                                        if (isOutOfStock)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text(
                                              '(Out of Stock)',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Colors.red,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'PKR ${medicine.purchasingCost.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'PKR ${medicine.averageSellingCost.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'PKR ${medicine.profit.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: medicine.profit >= 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          color: const Color(0xFF1565C0),
                                          onPressed: () {
                                            _showAddMedicineDialog(existingMedicine: medicine);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 20),
                                          color: Colors.red,
                                          onPressed: () => _deleteMedicine(medicine),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1565C0),
          ),
    );
  }
}
