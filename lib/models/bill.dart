class Bill {
  final String id;
  final String billNumber;
  final DateTime date;
  String? customerName;
  String? customerContact;
  final List<BillItem> items;
  final double totalAmount;
  final bool isTestBill;

  Bill({
    required this.id,
    required this.billNumber,
    required this.date,
    this.customerName,
    this.customerContact,
    required this.items,
    required this.totalAmount,
    this.isTestBill = false,
  });

  // Calculate total from items
  static double calculateTotal(List<BillItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.total);
  }
}

class BillItem {
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  final int quantity;
  final double unitPrice;
  final double total;

  BillItem({
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}
