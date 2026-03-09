import 'package:flutter/material.dart';
import '../models/cheque.dart';
import '../services/cheque_notification_service.dart';

class ChequesPage extends StatefulWidget {
  const ChequesPage({super.key});

  @override
  State<ChequesPage> createState() => _ChequesPageState();
}

class _ChequesPageState extends State<ChequesPage> {
  final List<Cheque> _cheques = [];
  final TextEditingController _searchController = TextEditingController();
  final ChequeNotificationService _notificationService = ChequeNotificationService();

  @override
  void initState() {
    super.initState();
    _updateNotificationService();
  }

  void _updateNotificationService() {
    _notificationService.setCheques(_cheques);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Cheque> get _filteredCheques {
    if (_searchController.text.isEmpty) {
      return _cheques;
    }
    final query = _searchController.text.toLowerCase();
    return _cheques.where((cheque) {
      return cheque.chequeNumber.toLowerCase().contains(query) ||
          cheque.vendorName.toLowerCase().contains(query) ||
          cheque.bank.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddChequeDialog({Cheque? chequeToEdit}) {
    final chequeNumberController = TextEditingController(text: chequeToEdit?.chequeNumber ?? '');
    final vendorNameController = TextEditingController(text: chequeToEdit?.vendorName ?? '');
    final bankController = TextEditingController(text: chequeToEdit?.bank ?? '');
    final amountController = TextEditingController(text: chequeToEdit?.amount.toStringAsFixed(2) ?? '');
    bool isGiven = chequeToEdit?.isGiven ?? true;
    DateTime selectedDate = chequeToEdit?.chequeDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(chequeToEdit == null ? 'Add New Cheque' : 'Edit Cheque'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: chequeNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Cheque Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankController,
                  decoration: const InputDecoration(
                    labelText: 'Bank',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (PKR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                // Given/Received Toggle
                Row(
                  children: [
                    const Text('Type: '),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Given'),
                            icon: Icon(Icons.arrow_upward),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Received'),
                            icon: Icon(Icons.arrow_downward),
                          ),
                        ],
                        selected: {isGiven},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setDialogState(() {
                            isGiven = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cheque Date',
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
              onPressed: () {
                if (chequeNumberController.text.isNotEmpty &&
                    vendorNameController.text.isNotEmpty &&
                    bankController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  setState(() {
                    if (chequeToEdit == null) {
                      _cheques.add(Cheque(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        chequeNumber: chequeNumberController.text,
                        chequeDate: selectedDate,
                        isGiven: isGiven,
                        vendorName: vendorNameController.text,
                        bank: bankController.text,
                        amount: double.tryParse(amountController.text) ?? 0.0,
                      ));
                    } else {
                      final index = _cheques.indexWhere((c) => c.id == chequeToEdit.id);
                      if (index != -1) {
                        _cheques[index].chequeNumber = chequeNumberController.text;
                        _cheques[index].chequeDate = selectedDate;
                        _cheques[index].isGiven = isGiven;
                        _cheques[index].vendorName = vendorNameController.text;
                        _cheques[index].bank = bankController.text;
                        _cheques[index].amount = double.tryParse(amountController.text) ?? 0.0;
                      }
                    }
                    _updateNotificationService();
                  });
                  Navigator.pop(context);
                  _showNotification(chequeToEdit == null ? 'Cheque added successfully!' : 'Cheque updated successfully!');
                }
              },
              child: Text(chequeToEdit == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteCheque(Cheque cheque) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cheque'),
        content: Text('Are you sure you want to delete cheque #${cheque.chequeNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cheques.remove(cheque);
                _updateNotificationService();
              });
              Navigator.pop(context);
              _showNotification('Cheque deleted successfully!');
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
    final totalCheques = _cheques.length;
    final pendingCheques = _cheques.where((c) => c.daysUntilDate >= 0).length;
    final totalAmount = _cheques.fold<double>(0.0, (sum, c) => sum + c.amount);
    final approachingCheques = _cheques.where((c) => c.isApproaching).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Cheque Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        actions: [
          if (approachingCheques > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '$approachingCheques',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
                        hintText: 'Search by cheque number, vendor, or bank...',
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
                    onPressed: _showAddChequeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Cheque'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
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
                      title: 'Total Cheques',
                      value: '$totalCheques',
                      icon: Icons.receipt_long,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Pending',
                      value: '$pendingCheques',
                      icon: Icons.pending,
                      color: Colors.orange,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Approaching',
                      value: '$approachingCheques',
                      icon: Icons.warning,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TableHeader('Cheque No.')),
                    Expanded(child: _TableHeader('Cheque Date')),
                    Expanded(child: _TableHeader('Type')),
                    Expanded(child: _TableHeader('Vendor Name')),
                    Expanded(child: _TableHeader('Bank')),
                    Expanded(child: _TableHeader('Amount')),
                    Expanded(child: _TableHeader('Days Left')),
                    Expanded(child: _TableHeader('Actions')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Cheques List
              Expanded(
                child: _filteredCheques.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _cheques.isEmpty
                                  ? 'No cheques found'
                                  : 'No cheques match your search',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _cheques.isEmpty
                                  ? 'Click "Add Cheque" to get started'
                                  : 'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCheques.length,
                        itemBuilder: (context, index) {
                          final cheque = _filteredCheques[index];
                          final daysLeft = cheque.daysUntilDate;
                          final isApproaching = cheque.isApproaching;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isApproaching
                                      ? (daysLeft <= 3 ? Colors.red : Colors.orange)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cheque.chequeNumber,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${cheque.chequeDate.day}/${cheque.chequeDate.month}/${cheque.chequeDate.year}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          cheque.isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                                          size: 16,
                                          color: cheque.isGiven ? Colors.blue : Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          cheque.isGiven ? 'Given' : 'Received',
                                          style: TextStyle(
                                            color: cheque.isGiven ? Colors.blue : Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      cheque.vendorName,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      cheque.bank,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'PKR ${cheque.amount.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          daysLeft >= 0 ? '$daysLeft' : 'Overdue',
                                          style: TextStyle(
                                            color: isApproaching
                                                ? (daysLeft <= 3 ? Colors.red : Colors.orange)
                                                : (daysLeft < 0 ? Colors.red : Colors.grey),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isApproaching)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.warning,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          color: const Color(0xFFE65100),
                                          onPressed: () => _showAddChequeDialog(chequeToEdit: cheque),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 20),
                                          color: Colors.red,
                                          onPressed: () => _deleteCheque(cheque),
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}
