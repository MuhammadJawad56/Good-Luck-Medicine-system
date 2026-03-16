import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../models/medicine.dart';
import '../services/inventory_service.dart';
import '../widgets/cheque_notification_overlay.dart';
import '../utils/pdf_header.dart';
import '../services/data_persistence_service.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final List<Bill> _bills = [];
  final TextEditingController _searchController = TextEditingController();
  final InventoryService _inventoryService = InventoryService();
  final DataPersistenceService _dataService = DataPersistenceService();
  int _billCounter = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inventoryService.addListener(_onInventoryChanged);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bills = await _dataService.loadBills();
    final counter = await _dataService.loadBillCounter();
    setState(() {
      _bills.clear();
      _bills.addAll(bills);
      _billCounter = counter;
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await _dataService.saveBills(_bills);
    await _dataService.saveBillCounter(_billCounter);
  }

  void _onInventoryChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inventoryService.removeListener(_onInventoryChanged);
    super.dispose();
  }

  List<Bill> get _filteredBills {
    if (_searchController.text.isEmpty) {
      return _bills;
    }
    final query = _searchController.text.toLowerCase();
    return _bills.where((bill) {
      return bill.billNumber.toLowerCase().contains(query) ||
          (bill.customerName?.toLowerCase().contains(query) ?? false) ||
          (bill.customerContact?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _showCreateBillDialog() {
    final customerNameController = TextEditingController();
    final customerContactController = TextEditingController();
    final List<BillItem> billItems = [];
    bool isTestBill = false;
    final availableMedicines = _inventoryService.medicines; // Use all medicines, not just in stock
    
    // Get unique customer names from previous bills
    final Set<String> previousCustomerNames = {};
    final Map<String, String> customerNameToContact = {}; // Map customer name to their contact
    
    for (var bill in _bills) {
      if (bill.customerName != null && bill.customerName!.trim().isNotEmpty) {
        previousCustomerNames.add(bill.customerName!.trim());
        // Store the most recent contact for each customer
        if (bill.customerContact != null && bill.customerContact!.trim().isNotEmpty) {
          customerNameToContact[bill.customerName!.trim()] = bill.customerContact!.trim();
        }
      }
    }
    final previousCustomers = previousCustomerNames.toList()..sort();
    
    // Controllers for adding new item
    Medicine? selectedMedicine;
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    TextEditingController? medicineSearchController;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Bill'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.75,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Bill Type Selector
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<String>(
                    value: isTestBill ? 'Test Bill' : 'Customer Bill',
                    items: const [
                      DropdownMenuItem(
                        value: 'Customer Bill',
                        child: Text('Customer Bill'),
                      ),
                      DropdownMenuItem(
                        value: 'Test Bill',
                        child: Text('Test Bill'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        isTestBill = (value == 'Test Bill');
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Customer Info (Optional)
                Row(
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return previousCustomers;
                          }
                          return previousCustomers.where((name) {
                            return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (String option) => option,
                        onSelected: (String selection) {
                          setDialogState(() {
                            customerNameController.text = selection;
                            // Auto-fill contact if available
                            if (customerNameToContact.containsKey(selection)) {
                              customerContactController.text = customerNameToContact[selection]!;
                            }
                          });
                        },
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController controller,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          // Sync the autocomplete controller with customerNameController
                          controller.addListener(() {
                            customerNameController.text = controller.text;
                            setDialogState(() {}); // Update UI to show/hide history button
                          });
                          
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Customer Name (Optional)',
                              hintText: previousCustomers.isEmpty 
                                  ? 'Enter customer name...'
                                  : 'Select or type customer name...',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person),
                              suffixIcon: previousCustomers.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.arrow_drop_down),
                                      tooltip: 'Show previous customers',
                                      onPressed: () {
                                        focusNode.requestFocus();
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (String value) {
                              onFieldSubmitted();
                            },
                            onChanged: (value) {
                              setDialogState(() {}); // Update UI to show/hide history button
                            },
                          );
                        },
                      ),
                    ),
                    // History button - show when customer name is entered
                    StatefulBuilder(
                      builder: (context, setHistoryState) {
                        // Check if customer name exists in previous bills
                        final hasHistory = previousCustomers.contains(customerNameController.text.trim());
                        return hasHistory
                            ? IconButton(
                                icon: const Icon(Icons.history, color: Colors.blue),
                                tooltip: 'View Customer Bill History',
                                onPressed: () {
                                  _showCustomerBillHistory(
                                    context,
                                    customerNameController.text.trim(),
                                    customerContactController.text.trim(),
                                  );
                                },
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: customerContactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const SizedBox(height: 12),
                
                // Add Medicine Section - Inline
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_circle, color: Color(0xFFAD1457)),
                          const SizedBox(width: 8),
                          Text(
                            'Add Medicine',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Medicine Selection
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Autocomplete<Medicine>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return availableMedicines;
                                }
                                return availableMedicines.where((medicine) {
                                  return medicine.name
                                      .toLowerCase()
                                      .contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (Medicine medicine) => 
                                  '${medicine.name} (Stock: ${medicine.quantity}, Batch: ${medicine.batchNumber})',
                              onSelected: (Medicine medicine) {
                                setDialogState(() {
                                  selectedMedicine = medicine;
                                  // Auto-fill price from inventory average selling cost
                                  priceController.text = medicine.averageSellingCost.toStringAsFixed(2);
                                  // Do NOT auto-fill quantity from inventory; user must enter it manually
                                  quantityController.clear();
                                });
                              },
                              fieldViewBuilder: (
                                BuildContext context,
                                TextEditingController controller,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Initialize the controller reference
                                if (medicineSearchController == null) {
                                  medicineSearchController = controller;
                                } else {
                                  medicineSearchController = controller;
                                }
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Search & Select Medicine',
                                    hintText: 'Type medicine name...',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: selectedMedicine != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedMedicine = null;
                                                controller.clear();
                                                quantityController.clear();
                                                priceController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.numbers),
                                suffixText: selectedMedicine != null
                                    ? 'Max: ${selectedMedicine!.quantity}'
                                    : null,
                                helperText: selectedMedicine == null
                                    ? 'Enter quantity manually'
                                    : null,
                              ),
                              keyboardType: TextInputType.number,
                              enabled: true, // Always enabled
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              decoration: InputDecoration(
                                labelText: 'Price per Piece (PKR)',
                                hintText: selectedMedicine != null 
                                    ? 'From inventory: PKR ${selectedMedicine!.averageSellingCost.toStringAsFixed(2)}'
                                    : 'Enter price per piece',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.attach_money),
                                helperText: selectedMedicine != null 
                                    ? 'Auto-filled from inventory selling price (editable)'
                                    : 'Enter price per piece manually',
                                helperMaxLines: 1,
                                suffixIcon: selectedMedicine != null
                                    ? IconButton(
                                        icon: const Icon(Icons.refresh, size: 18),
                                        tooltip: 'Reset to inventory price',
                                        onPressed: () {
                                          setDialogState(() {
                                            priceController.text = selectedMedicine!.averageSellingCost.toStringAsFixed(2);
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              enabled: true, // Always enabled
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.add_circle, size: 36),
                            color: const Color(0xFFAD1457),
                            onPressed: () async {
                                    // Get medicine name for lookup/billing
                                    // If a medicine was selected from inventory, always use its actual name.
                                    // Otherwise, fall back to the raw text (and strip any extra info like "(Stock: ..)")
                                    final rawSearchText = medicineSearchController?.text.trim() ?? '';
                                    final medicineName = selectedMedicine?.name ??
                                        (rawSearchText.contains('(')
                                            ? rawSearchText.split('(').first.trim()
                                            : rawSearchText);
                                    final quantity = int.tryParse(quantityController.text) ?? 0;
                                    final price = double.tryParse(priceController.text) ?? 0.0;

                                    // Validation
                                    if (medicineName.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please enter medicine name'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (quantity <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Quantity must be greater than 0'),
                                        ),
                                      );
                                      return;
                                    }

                                    if (price <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Price per piece must be greater than 0'),
                                        ),
                                      );
                                      return;
                                    }

                                    // Check if medicine exists in inventory
                                    Medicine? medicineInInventory;

                                    // If medicine was selected from autocomplete, trust that it came from inventory
                                    if (selectedMedicine != null) {
                                      medicineInInventory = selectedMedicine;
                                    } else {
                                      medicineInInventory = _inventoryService.getMedicineByName(medicineName);
                                    }
                                    
                                    if (medicineInInventory == null) {
                                      // Medicine not in inventory - show popup to add it
                                      final shouldAdd = await _showMedicineNotInInventoryDialog(
                                        context,
                                        medicineName,
                                        setDialogState,
                                        priceController.text,
                                      );
                                      if (shouldAdd == true) {
                                        // Refresh available medicines after adding
                                        setDialogState(() {
                                          // The dialog will refresh the list
                                        });
                                        return;
                                      } else {
                                        return; // User cancelled
                                      }
                                    }

                                    // Check if medicine is out of stock
                                    if (medicineInInventory.quantity == 0) {
                                      // Medicine out of stock - show popup to update stock
                                      final shouldUpdate = await _showMedicineOutOfStockDialog(
                                        context,
                                        medicineInInventory,
                                        setDialogState,
                                      );
                                      if (shouldUpdate == true) {
                                        // Refresh available medicines after updating
                                        setDialogState(() {
                                          // The dialog will refresh the list
                                        });
                                        return;
                                      } else {
                                        return; // User cancelled
                                      }
                                    }

                                    // Check if requested quantity exceeds available stock
                                    if (quantity > medicineInInventory.quantity) {
                                      // Insufficient stock - show popup to update stock
                                      final shouldUpdate = await _showInsufficientStockDialog(
                                        context,
                                        medicineInInventory,
                                        quantity,
                                        setDialogState,
                                      );
                                      if (shouldUpdate == true) {
                                        // Refresh available medicines after updating
                                        setDialogState(() {
                                          // The dialog will refresh the list
                                        });
                                        return;
                                      } else {
                                        return; // User cancelled
                                      }
                                    }

                                    // Get final updated medicine from inventory (in case it was just added/updated)
                                    final updatedMedicine = _inventoryService.getMedicineByName(medicineName);
                                    if (updatedMedicine == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Medicine not found in inventory. Please add it first.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Verify stock is sufficient
                                    if (updatedMedicine.quantity < quantity) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Insufficient stock. Available: ${updatedMedicine.quantity}, Requested: $quantity'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Check if medicine already in bill
                                    final existingIndex = billItems.indexWhere(
                                      (item) => item.medicineId == updatedMedicine.id,
                                    );

                                    if (existingIndex != -1) {
                                      // Update existing item
                                      final existing = billItems[existingIndex];
                                      final newQuantity = existing.quantity + quantity;
                                      if (newQuantity > updatedMedicine.quantity) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Total quantity exceeds available stock: ${updatedMedicine.quantity}'),
                                          ),
                                        );
                                        return;
                                      }
                                      billItems[existingIndex] = BillItem(
                                        medicineId: existing.medicineId,
                                        medicineName: existing.medicineName,
                                        // Do not auto-use inventory batch number for bill items
                                        batchNumber: '',
                                        quantity: newQuantity,
                                        unitPrice: price,
                                        total: newQuantity * price,
                                      );
                                    } else {
                                      // Add new item
                                      billItems.add(BillItem(
                                        medicineId: updatedMedicine.id,
                                        medicineName: updatedMedicine.name,
                                        // Do not auto-use inventory batch number for bill items
                                        batchNumber: '',
                                        quantity: quantity,
                                        unitPrice: price,
                                        total: quantity * price,
                                      ));
                                    }

                                    setDialogState(() {
                                      selectedMedicine = null;
                                      medicineSearchController?.clear();
                                      quantityController.clear();
                                      priceController.clear();
                                    });
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Items List Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAD1457).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _DialogTableHeader('Medicine Name')),
                      Expanded(child: _DialogTableHeader('Batch')),
                      Expanded(child: _DialogTableHeader('Qty')),
                      Expanded(child: _DialogTableHeader('Price')),
                      Expanded(child: _DialogTableHeader('Total')),
                      Expanded(child: _DialogTableHeader('Action')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Items List
                billItems.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items added yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Search and add medicines above',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: billItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFAD1457).withOpacity(0.2),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFAD1457),
                                  ),
                                ),
                              ),
                              title: Text(
                                item.medicineName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('Batch: ${item.batchNumber}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'PKR ${item.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 22),
                                    color: Colors.red,
                                    onPressed: () {
                                      setDialogState(() {
                                        billItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                
                // Total
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Total Amount:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Text(
                        'PKR ${Bill.calculateTotal(billItems).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: billItems.isEmpty
                  ? null
                  : () {
                      // Create a temporary bill for preview/print
                      final tempBillNumber = 'BILL-PREVIEW-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${_billCounter.toString().padLeft(4, '0')}';
                      final tempBill = Bill(
                        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
                        billNumber: tempBillNumber,
                        date: DateTime.now(),
                        customerName: customerNameController.text.isEmpty ? null : customerNameController.text,
                        customerContact: customerContactController.text.isEmpty ? null : customerContactController.text,
                        items: List.from(billItems),
                        totalAmount: Bill.calculateTotal(billItems),
                        isTestBill: isTestBill,
                      );
                      _generateBillPDF(tempBill);
                    },
              icon: const Icon(Icons.print),
              label: const Text('Print Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            ElevatedButton(
              onPressed: billItems.isEmpty
                  ? null
                  : () async {
                      final billNumber = 'BILL-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${_billCounter.toString().padLeft(4, '0')}';
                      final newBill = Bill(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        billNumber: billNumber,
                        date: DateTime.now(),
                        customerName: customerNameController.text.isEmpty ? null : customerNameController.text,
                        customerContact: customerContactController.text.isEmpty ? null : customerContactController.text,
                        items: List.from(billItems),
                        totalAmount: Bill.calculateTotal(billItems),
                        isTestBill: isTestBill,
                      );

                      // Update inventory - reduce stock
                      for (var item in billItems) {
                        _inventoryService.reduceStock(item.medicineId, item.quantity);
                      }

                      setState(() {
                        _bills.add(newBill);
                        _billCounter++;
                      });

                      await _saveData();
                      Navigator.pop(context);
                      _showNotification('Bill created successfully!');
                      _generateBillPDF(newBill);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAD1457),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Create Bill'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showMedicineNotInInventoryDialog(
    BuildContext context,
    String medicineName,
    StateSetter setDialogState,
    String? currentPrice,
  ) async {
    final nameController = TextEditingController(text: medicineName);
    final batchController = TextEditingController();
    final quantityController = TextEditingController(text: '1'); // Default to 1
    final purchasingCostController = TextEditingController();
    final sellingCostController = TextEditingController(text: currentPrice ?? '0.00');

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Medicine Not in Inventory',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$medicineName is not in inventory. Please add it to continue.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                enabled: false, // Name is fixed
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Batch Number (Optional)',
                  hintText: 'Leave empty to auto-generate',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purchasingCostController,
                decoration: const InputDecoration(
                  labelText: 'Purchasing Cost (PKR)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_cart),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sellingCostController,
                decoration: const InputDecoration(
                  labelText: 'Selling Cost (PKR)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate all required fields with better error messages
              if (quantityController.text.isEmpty || quantityController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (purchasingCostController.text.isEmpty || purchasingCostController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter purchasing cost'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (sellingCostController.text.isEmpty || sellingCostController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter selling cost'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final quantity = int.tryParse(quantityController.text.trim());
              final purchasingCost = double.tryParse(purchasingCostController.text.trim());
              final sellingCost = double.tryParse(sellingCostController.text.trim());

              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quantity must be a number greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (purchasingCost == null || purchasingCost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchasing cost must be a number greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (sellingCost == null || sellingCost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selling cost must be a number greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                String finalBatchNumber = batchController.text.trim();
                if (finalBatchNumber.isEmpty) {
                  // Generate batch number
                  final random = DateTime.now().millisecondsSinceEpoch % 26;
                  final alphabet = String.fromCharCode(65 + random);
                  final digits = (DateTime.now().millisecondsSinceEpoch % 999999).toString().padLeft(6, '0');
                  finalBatchNumber = '$alphabet$digits';
                }

                final newMedicine = Medicine(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  batchNumber: finalBatchNumber,
                  quantity: quantity,
                  purchasingCost: purchasingCost,
                  averageSellingCost: sellingCost,
                );

                _inventoryService.addMedicine(newMedicine);
                await _dataService.saveMedicines(_inventoryService.medicines);
                
                if (context.mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$medicineName added to inventory successfully! You can now add it to the bill.'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding medicine: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showMedicineOutOfStockDialog(
    BuildContext context,
    Medicine medicine,
    StateSetter setDialogState,
  ) async {
    final quantityController = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Medicine Out of Stock',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${medicine.name} is out of stock (Current: ${medicine.quantity}). Please update stock to continue.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Medicine: ${medicine.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Batch: ${medicine.batchNumber}'),
              const SizedBox(height: 8),
              Text('Current Stock: ${medicine.quantity}'),
              const SizedBox(height: 20),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Add Quantity',
                  hintText: 'Enter quantity to add',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_box),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (quantityController.text.isNotEmpty) {
                final addQuantity = int.tryParse(quantityController.text) ?? 0;
                if (addQuantity > 0) {
                  final updatedMedicine = Medicine(
                    id: medicine.id,
                    name: medicine.name,
                    batchNumber: medicine.batchNumber,
                    quantity: medicine.quantity + addQuantity,
                    purchasingCost: medicine.purchasingCost,
                    averageSellingCost: medicine.averageSellingCost,
                  );

                  _inventoryService.updateMedicine(medicine.id, updatedMedicine);
                  await _dataService.saveMedicines(_inventoryService.medicines);
                  
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock updated! New quantity: ${updatedMedicine.quantity}. You can now add it to the bill.'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quantity must be greater than 0'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showInsufficientStockDialog(
    BuildContext context,
    Medicine medicine,
    int requestedQuantity,
    StateSetter setDialogState,
  ) async {
    final quantityController = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Insufficient Stock',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${medicine.name} has insufficient stock.\nRequested: $requestedQuantity\nAvailable: ${medicine.quantity}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Medicine: ${medicine.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Batch: ${medicine.batchNumber}'),
              const SizedBox(height: 8),
              Text('Current Stock: ${medicine.quantity}'),
              const SizedBox(height: 20),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Add Quantity',
                  hintText: 'Add at least ${requestedQuantity - medicine.quantity} more',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.add_box),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (quantityController.text.isNotEmpty) {
                final addQuantity = int.tryParse(quantityController.text) ?? 0;
                if (addQuantity > 0) {
                  final updatedMedicine = Medicine(
                    id: medicine.id,
                    name: medicine.name,
                    batchNumber: medicine.batchNumber,
                    quantity: medicine.quantity + addQuantity,
                    purchasingCost: medicine.purchasingCost,
                    averageSellingCost: medicine.averageSellingCost,
                  );

                  _inventoryService.updateMedicine(medicine.id, updatedMedicine);
                  await _dataService.saveMedicines(_inventoryService.medicines);
                  
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock updated! New quantity: ${updatedMedicine.quantity}. You can now add it to the bill.'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quantity must be greater than 0'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateBillPDF(Bill bill) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          // Use half of A4 height (approx. A5) for compact bills
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo, address, and contact info
                if (!bill.isTestBill) ...[
                  PdfHeaderHelper.buildSimpleHeader(
                    subtitle: 'Sales Bill',
                    rightSideInfo: 'Bill No: ${bill.billNumber}\nDate: ${bill.date.day}/${bill.date.month}/${bill.date.year}\nTime: ${bill.date.hour.toString().padLeft(2, '0')}:${bill.date.minute.toString().padLeft(2, '0')}',
                  ),
                  pw.SizedBox(height: 20),
                ] else ...[
                  pw.Text(
                    'TEST BILL',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],

                // Customer Info (if available)
                if (bill.customerName != null || bill.customerContact != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey800),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Customer Details',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (bill.customerName != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Name: ${bill.customerName}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                        if (bill.customerContact != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Contact: ${bill.customerContact}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (bill.customerName != null || bill.customerContact != null)
                  pw.SizedBox(height: 16),

                // Items Table
                pw.Text(
                  'Items',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
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
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Medicine Name',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Batch',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Qty',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...List.generate(bill.items.length, (index) {
                      final item = bill.items[index];
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${index + 1}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.medicineName,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.batchNumber,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.quantity}',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.unitPrice.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.total.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey800),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Amount:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'PKR ${bill.totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Items: ${bill.items.length}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Signature: _______________',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _BillPdfPreviewPage(
            title: 'Bill Preview',
            fileName: '${bill.billNumber}_${bill.date.day}_${bill.date.month}_${bill.date.year}.pdf',
            pdfBytes: pdfBytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showNotification('Error generating PDF: $e', isError: true);
      }
    }
  }

  void _showCustomerBillHistory(BuildContext context, String customerName, String customerContact) {
    // Get all bills for this customer (by name or contact)
    final customerBills = _bills.where((bill) {
      final nameMatch = bill.customerName != null && 
          bill.customerName!.toLowerCase().trim() == customerName.toLowerCase().trim();
      final contactMatch = customerContact.isNotEmpty &&
          bill.customerContact != null &&
          bill.customerContact!.toLowerCase().trim() == customerContact.toLowerCase().trim();
      return nameMatch || contactMatch;
    }).toList();

    if (customerBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No bills found for $customerName'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Group bills by date
    final Map<String, List<Bill>> billsByDate = {};
    for (var bill in customerBills) {
      final dateKey = '${bill.date.year}-${bill.date.month.toString().padLeft(2, '0')}-${bill.date.day.toString().padLeft(2, '0')}';
      billsByDate.putIfAbsent(dateKey, () => []).add(bill);
    }

    // Sort dates descending (newest first)
    final sortedDates = billsByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    customerName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.7,
          child: sortedDates.isEmpty
              ? const Center(child: Text('No bills found'))
              : ListView.builder(
                  itemCount: sortedDates.length,
                  itemBuilder: (context, dateIndex) {
                    final dateKey = sortedDates[dateIndex];
                    final billsForDate = billsByDate[dateKey]!;
                    final date = DateTime.parse('$dateKey 00:00:00');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.blue),
                        title: Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text('${billsForDate.length} bill${billsForDate.length > 1 ? 's' : ''}'),
                        children: billsForDate.map((bill) {
                          return ListTile(
                            leading: const Icon(Icons.receipt, color: Color(0xFFAD1457)),
                            title: Text(
                              bill.billNumber,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${bill.items.length} items'),
                                Text(
                                  'Total: PKR ${bill.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Time: ${bill.date.hour.toString().padLeft(2, '0')}:${bill.date.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  tooltip: 'View Bill',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showBillDetailsDialog(bill);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print, color: Colors.green),
                                  tooltip: 'Print Bill',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _generateBillPDF(bill);
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBillDetailsDialog(Bill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt, color: Color(0xFFAD1457)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.billNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${bill.date.day}/${bill.date.month}/${bill.date.year} ${bill.date.hour.toString().padLeft(2, '0')}:${bill.date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bill.customerName != null || bill.customerContact != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (bill.customerName != null)
                          Text('Name: ${bill.customerName}'),
                        if (bill.customerContact != null)
                          Text('Contact: ${bill.customerContact}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Items:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...bill.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFAD1457).withOpacity(0.2),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFAD1457),
                          ),
                        ),
                      ),
                      title: Text(
                        item.medicineName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Batch: ${item.batchNumber}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'PKR ${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'PKR ${bill.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _generateBillPDF(bill);
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Bill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrintBillDialog() {
    if (_bills.isEmpty) {
      _showNotification('No bills available to print', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Bill to Print'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _bills.length,
            itemBuilder: (context, index) {
              final bill = _bills[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.receipt, color: Color(0xFFAD1457)),
                  title: Text(
                    bill.billNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bill.customerName != null)
                        Text('Customer: ${bill.customerName}'),
                      Text(
                        '${bill.items.length} items • PKR ${bill.totalAmount.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Date: ${bill.date.day}/${bill.date.month}/${bill.date.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(context);
                      _generateBillPDF(bill);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _deleteBill(Bill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Bill'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete bill ${bill.billNumber}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _bills.remove(bill);
              });
              await _saveData();
              Navigator.pop(context);
              _showNotification('Bill deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBills = _bills.length;
    final totalAmount = _bills.fold<double>(0.0, (sum, bill) => sum + bill.totalAmount);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bill Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFFAD1457),
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
                        hintText: 'Search bills by number, customer name, or contact...',
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
                    onPressed: _showCreateBillDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAD1457),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _bills.isEmpty
                        ? null
                        : () => _showPrintBillDialog(),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
                      title: 'Total Bills',
                      value: '$totalBills',
                      icon: Icons.receipt,
                      color: const Color(0xFFAD1457),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Amount',
                      value: 'PKR ${totalAmount.toStringAsFixed(2)}',
                      icon: Icons.account_balance,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bills List Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFAD1457).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TableHeader('Bill No.')),
                    Expanded(flex: 2, child: _TableHeader('Customer')),
                    Expanded(child: _TableHeader('Items')),
                    Expanded(child: _TableHeader('Amount')),
                    Expanded(child: _TableHeader('Date')),
                    Expanded(child: _TableHeader('Actions')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bills List
              Expanded(
                child: _filteredBills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _bills.isEmpty
                                  ? 'No bills found'
                                  : 'No bills match your search',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _bills.isEmpty
                                  ? 'Click "Create Bill" to get started'
                                  : 'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredBills.length,
                        itemBuilder: (context, index) {
                          final bill = _filteredBills[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: const Icon(Icons.receipt, color: Color(0xFFAD1457)),
                              title: Text(
                                bill.billNumber,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bill.customerName != null)
                                    Text('Customer: ${bill.customerName}'),
                                  if (bill.customerContact != null)
                                    Text('Contact: ${bill.customerContact}'),
                                  Text(
                                    '${bill.items.length} items',
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'PKR ${bill.totalAmount.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${bill.date.day}/${bill.date.month}/${bill.date.year}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.print, size: 20),
                                    color: Colors.blue,
                                    onPressed: () => _generateBillPDF(bill),
                                    tooltip: 'Print Bill',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deleteBill(bill),
                                    tooltip: 'Delete Bill',
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

class _BillPdfPreviewPage extends StatelessWidget {
  final String title;
  final String fileName;
  final Uint8List pdfBytes;

  const _BillPdfPreviewPage({
    required this.title,
    required this.fileName,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowSharing: true,
        allowPrinting: true,
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

class _DialogTableHeader extends StatelessWidget {
  final String text;

  const _DialogTableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
