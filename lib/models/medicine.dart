class Medicine {
  final String id;
  final String name;
  final String batchNumber;
  final int quantity;
  final double purchasingCost;
  final double averageSellingCost;
  
  Medicine({
    required this.id,
    required this.name,
    required this.batchNumber,
    required this.quantity,
    required this.purchasingCost,
    required this.averageSellingCost,
  });
  
  // Auto-calculate profit
  double get profit => averageSellingCost - purchasingCost;
  
  // Calculate total profit (profit per unit * quantity)
  double get totalProfit => profit * quantity;
  
  // Calculate profit percentage
  double get profitPercentage {
    if (purchasingCost == 0) return 0;
    return ((profit / purchasingCost) * 100);
  }
}
