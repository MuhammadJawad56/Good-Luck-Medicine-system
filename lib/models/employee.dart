class Employee {
  final String id;
  String name;
  String position;
  double totalSalary;
  List<Withdrawal> withdrawals;

  Employee({
    required this.id,
    required this.name,
    required this.position,
    required this.totalSalary,
    List<Withdrawal>? withdrawals,
  }) : withdrawals = withdrawals ?? [];

  // Get withdrawals for a specific date range
  List<Withdrawal> getWithdrawalsInRange(DateTime startDate, DateTime endDate) {
    return withdrawals.where((w) {
      return w.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          w.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Get total withdrawals in a date range
  double getTotalWithdrawalsInRange(DateTime startDate, DateTime endDate) {
    return getWithdrawalsInRange(startDate, endDate)
        .fold(0.0, (sum, w) => sum + w.amount);
  }

  // Get remaining balance for a date range
  double getRemainingBalance(DateTime startDate, DateTime endDate) {
    return totalSalary - getTotalWithdrawalsInRange(startDate, endDate);
  }
}

class Withdrawal {
  final String id;
  final double amount;
  final DateTime date;

  Withdrawal({
    required this.id,
    required this.amount,
    required this.date,
  });
}
