import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import '../models/employee.dart';
import '../widgets/cheque_notification_overlay.dart';
import '../utils/pdf_header.dart';
import '../services/data_persistence_service.dart';

class SalariesPage extends StatefulWidget {
  const SalariesPage({super.key});

  @override
  State<SalariesPage> createState() => _SalariesPageState();
}

class _SalariesPageState extends State<SalariesPage> {
  final List<Employee> _employees = [];
  final TextEditingController _searchController = TextEditingController();
  final DataPersistenceService _dataService = DataPersistenceService();
  bool _isLoading = true;
  
  // Pay cycle settings (default: 1st to 1st)
  DateTime _cycleStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _cycleEndDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);

  @override
  void initState() {
    super.initState();
    _updateCycleDates();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final employees = await _dataService.loadEmployees();
    final withdrawals = await _dataService.loadWithdrawals();
    
    // Attach withdrawals to employees
    for (var employee in employees) {
      final employeeWithdrawals = withdrawals[employee.id] ?? [];
      employee.withdrawals.clear();
      employee.withdrawals.addAll(employeeWithdrawals);
    }
    
    setState(() {
      _employees.clear();
      _employees.addAll(employees);
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await _dataService.saveEmployees(_employees);
    final withdrawalsMap = <String, List<Withdrawal>>{};
    for (var employee in _employees) {
      withdrawalsMap[employee.id] = employee.withdrawals;
    }
    await _dataService.saveWithdrawals(withdrawalsMap);
  }

  void _updateCycleDates() {
    final now = DateTime.now();
    _cycleStartDate = DateTime(now.year, now.month, 1);
    _cycleEndDate = DateTime(now.year, now.month + 1, 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Employee> get _filteredEmployees {
    if (_searchController.text.isEmpty) {
      return _employees;
    }
    final query = _searchController.text.toLowerCase();
    return _employees.where((employee) {
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddEmployeeDialog({Employee? employeeToEdit}) {
    final nameController = TextEditingController(text: employeeToEdit?.name ?? '');
    final positionController = TextEditingController(text: employeeToEdit?.position ?? '');
    final salaryController = TextEditingController(text: employeeToEdit?.totalSalary.toStringAsFixed(2) ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employeeToEdit == null ? 'Add New Employee' : 'Edit Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(
                  labelText: 'Total Salary (PKR)',
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
                  positionController.text.isNotEmpty &&
                  salaryController.text.isNotEmpty) {
                setState(() {
                  if (employeeToEdit == null) {
                    _employees.add(Employee(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      position: positionController.text,
                      totalSalary: double.tryParse(salaryController.text) ?? 0.0,
                    ));
                  } else {
                    final index = _employees.indexWhere((e) => e.id == employeeToEdit.id);
                    if (index != -1) {
                      _employees[index].name = nameController.text;
                      _employees[index].position = positionController.text;
                      _employees[index].totalSalary = double.tryParse(salaryController.text) ?? 0.0;
                    }
                  }
                });
                await _saveData();
                Navigator.pop(context);
                _showNotification(employeeToEdit == null ? 'Employee added successfully!' : 'Employee updated successfully!');
              }
            },
            child: Text(employeeToEdit == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showAddWithdrawalDialog(Employee employee) {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Withdrawal - ${employee.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Withdrawal Amount (PKR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Withdrawal Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                  ),
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
                if (amountController.text.isNotEmpty) {
                  setState(() {
                    employee.withdrawals.add(Withdrawal(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: double.tryParse(amountController.text) ?? 0.0,
                      date: selectedDate,
                    ));
                  });
                  await _saveData();
                  Navigator.pop(context);
                  _showNotification('Withdrawal added successfully!');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCycleSettingsDialog() {
    DateTime startDate = _cycleStartDate;
    DateTime endDate = _cycleEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pay Cycle Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cycle Start Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${startDate.day}/${startDate.month}/${startDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cycle End Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${endDate.day}/${endDate.month}/${endDate.year}',
                    ),
                  ),
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
              onPressed: () {
                setState(() {
                  _cycleStartDate = startDate;
                  _cycleEndDate = endDate;
                });
                Navigator.pop(context);
                _showNotification('Pay cycle updated!');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateEmployeePDF(Employee employee) async {
    try {
      final pdf = pw.Document();
      final withdrawals = employee.getWithdrawalsInRange(_cycleStartDate, _cycleEndDate);
      final totalWithdrawals = employee.getTotalWithdrawalsInRange(_cycleStartDate, _cycleEndDate);
      final remaining = employee.getRemainingBalance(_cycleStartDate, _cycleEndDate);

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
                  subtitle: 'Employee Monthly Withdrawal Statement',
                  rightSideInfo: 'Pay Cycle: ${_cycleStartDate.day}/${_cycleStartDate.month}/${_cycleStartDate.year} - ${_cycleEndDate.day}/${_cycleEndDate.month}/${_cycleEndDate.year}\nGenerated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                ),
                pw.SizedBox(height: 20),
                
                // Employee Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey800),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Employee Name: ${employee.name}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Position: ${employee.position}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Total Salary: PKR ${employee.totalSalary.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Withdrawals Table
                pw.Text(
                  'Withdrawals',
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
                            'Date',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Amount (PKR)',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (withdrawals.isEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'No withdrawals in this cycle',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.SizedBox(),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.SizedBox(),
                          ),
                        ],
                      )
                    else
                      ...List.generate(withdrawals.length, (index) {
                        final withdrawal = withdrawals[index];
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
                                '${withdrawal.date.day}/${withdrawal.date.month}/${withdrawal.date.year}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                withdrawal.amount.toStringAsFixed(2),
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
                
                // Summary
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey800),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Withdrawals:',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'PKR ${totalWithdrawals.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Remaining Balance:',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'PKR ${remaining.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: remaining >= 0 ? PdfColors.green : PdfColors.red,
                            ),
                          ),
                        ],
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
                      'Total Withdrawals: ${withdrawals.length}',
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

      // Save and open PDF
      final pdfBytes = await pdf.save();
      final desktopPath = Platform.environment['USERPROFILE'] ?? '';
      final fileName = '${employee.name.replaceAll(' ', '_')}_Withdrawal_${_cycleStartDate.day}_${_cycleStartDate.month}_${_cycleStartDate.year}.pdf';
      final filePath = desktopPath.isNotEmpty 
          ? '$desktopPath\\Desktop\\$fileName'
          : fileName;
      
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      try {
        await OpenFilex.open(file.path);
        if (mounted) {
          _showNotification('PDF opened successfully! You can now print it.');
        }
      } catch (e) {
        if (mounted) {
          _showNotification('PDF saved to Desktop: $fileName');
        }
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error generating PDF: $e', isError: true);
      }
    }
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

  void _deleteEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _employees.remove(employee);
              });
              await _saveData();
              Navigator.pop(context);
              _showNotification('Employee deleted successfully!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalEmployees = _employees.length;
    final monthlyPayroll = _employees.fold<double>(0.0, (sum, e) => sum + e.totalSalary);
    final totalWithdrawals = _employees.fold<double>(
      0.0,
      (sum, e) => sum + e.getTotalWithdrawalsInRange(_cycleStartDate, _cycleEndDate),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Salary Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF2E7D32),
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
                        hintText: 'Search employees...',
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
                    onPressed: _showAddEmployeeDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Employee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pay Cycle Info
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Pay Cycle',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_cycleStartDate.day}/${_cycleStartDate.month}/${_cycleStartDate.year} - ${_cycleEndDate.day}/${_cycleEndDate.month}/${_cycleEndDate.year}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: _showCycleSettingsDialog,
                        tooltip: 'Change Pay Cycle',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Employees',
                      value: '$totalEmployees',
                      icon: Icons.people,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Monthly Payroll',
                      value: 'PKR ${monthlyPayroll.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Withdrawals',
                      value: 'PKR ${totalWithdrawals.toStringAsFixed(2)}',
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Employees List Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _TableHeader('Employee Name')),
                    Expanded(child: _TableHeader('Position')),
                    Expanded(child: _TableHeader('Salary')),
                    Expanded(child: _TableHeader('Actions')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Employees List
              Expanded(
                child: _filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _employees.isEmpty
                                  ? 'No employees found'
                                  : 'No employees match your search',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _employees.isEmpty
                                  ? 'Click "Add Employee" to get started'
                                  : 'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = _filteredEmployees[index];
                          final withdrawals = employee.getWithdrawalsInRange(_cycleStartDate, _cycleEndDate);
                          final totalWithdrawals = employee.getTotalWithdrawalsInRange(_cycleStartDate, _cycleEndDate);
                          final remaining = employee.getRemainingBalance(_cycleStartDate, _cycleEndDate);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ExpansionTile(
                              title: Text(
                                employee.name,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              subtitle: Text(
                                '${employee.position} • PKR ${employee.totalSalary.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.print, size: 20),
                                    color: Colors.blue,
                                    onPressed: () => _generateEmployeePDF(employee),
                                    tooltip: 'Print PDF',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: const Color(0xFF2E7D32),
                                    onPressed: () => _showAddEmployeeDialog(employeeToEdit: employee),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deleteEmployee(employee),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Withdrawals (${withdrawals.length})',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _showAddWithdrawalDialog(employee),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Add Withdrawal'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (withdrawals.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text('No withdrawals in this cycle'),
                                        )
                                      else
                                        ...withdrawals.map((w) => Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            leading: const Icon(Icons.account_balance_wallet),
                                            title: Text('PKR ${w.amount.toStringAsFixed(2)}'),
                                            subtitle: Text(
                                              '${w.date.day}/${w.date.month}/${w.date.year}',
                                            ),
                                            trailing: Text(
                                              'Remaining: PKR ${(employee.totalSalary - employee.getTotalWithdrawalsInRange(_cycleStartDate, w.date.add(const Duration(days: 1)))).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: remaining >= 0 ? Colors.green : Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )),
                                      const Divider(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Withdrawals:',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              'PKR ${totalWithdrawals.toStringAsFixed(2)}',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Remaining Balance:',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'PKR ${remaining.toStringAsFixed(2)}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: remaining >= 0 ? Colors.green : Colors.red,
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}
