class Cheque {
  final String id;
  String chequeNumber;
  DateTime chequeDate;
  bool isGiven; // true = Given, false = Received
  String vendorName;
  String bank;
  double amount;

  Cheque({
    required this.id,
    required this.chequeNumber,
    required this.chequeDate,
    required this.isGiven,
    required this.vendorName,
    required this.bank,
    required this.amount,
  });

  // Get days until cheque date
  int get daysUntilDate {
    final now = DateTime.now();
    final difference = chequeDate.difference(now);
    return difference.inDays;
  }

  // Check if cheque date is approaching (7 days or less)
  bool get isApproaching {
    return daysUntilDate <= 7 && daysUntilDate >= 0;
  }
}
