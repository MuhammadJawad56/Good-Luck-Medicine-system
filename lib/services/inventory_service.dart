import '../models/medicine.dart';

class InventoryService {
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  List<Medicine> _medicines = [];
  final List<VoidCallback> _listeners = [];

  List<Medicine> get medicines => _medicines;

  void setMedicines(List<Medicine> medicines) {
    _medicines = medicines;
    _notifyListeners();
  }

  void addMedicine(Medicine medicine) {
    _medicines.add(medicine);
    _notifyListeners();
  }

  void updateMedicine(String id, Medicine updatedMedicine) {
    final index = _medicines.indexWhere((m) => m.id == id);
    if (index != -1) {
      _medicines[index] = updatedMedicine;
      _notifyListeners();
    }
  }

  Medicine? getMedicineById(String id) {
    try {
      return _medicines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Medicine? getMedicineByName(String name) {
    try {
      return _medicines.firstWhere(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  void reduceStock(String medicineId, int quantity) {
    final medicine = getMedicineById(medicineId);
    if (medicine != null) {
      final updatedQuantity = (medicine.quantity - quantity).clamp(0, double.infinity).toInt();
      final updatedMedicine = Medicine(
        id: medicine.id,
        name: medicine.name,
        batchNumber: medicine.batchNumber,
        quantity: updatedQuantity,
        purchasingCost: medicine.purchasingCost,
        averageSellingCost: medicine.averageSellingCost,
      );
      updateMedicine(medicineId, updatedMedicine);
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }
}

typedef VoidCallback = void Function();
