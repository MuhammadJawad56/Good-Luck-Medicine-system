import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../models/employee.dart';
import '../models/cheque.dart';
import '../models/bill.dart';

class DataPersistenceService {
  static final DataPersistenceService _instance = DataPersistenceService._internal();
  factory DataPersistenceService() => _instance;
  DataPersistenceService._internal();

  static const String _medicinesKey = 'medicines';
  static const String _employeesKey = 'employees';
  static const String _withdrawalsKey = 'withdrawals';
  static const String _chequesKey = 'cheques';
  static const String _billsKey = 'bills';
  static const String _billCounterKey = 'bill_counter';

  // Save Medicines
  Future<void> saveMedicines(List<Medicine> medicines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicinesJson = medicines.map((m) => {
        'id': m.id,
        'name': m.name,
        'batchNumber': m.batchNumber,
        'quantity': m.quantity,
        'purchasingCost': m.purchasingCost,
        'averageSellingCost': m.averageSellingCost,
      }).toList();
      final jsonString = jsonEncode(medicinesJson);
      final success = await prefs.setString(_medicinesKey, jsonString);
      print('SharedPreferences save result: $success');
      print('Saved ${medicines.length} medicines, JSON length: ${jsonString.length}');
    } catch (e) {
      print('Error in saveMedicines: $e');
      rethrow;
    }
  }

  // Load Medicines
  Future<List<Medicine>> loadMedicines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicinesJson = prefs.getString(_medicinesKey);
      print('Loaded medicines JSON: ${medicinesJson != null ? medicinesJson.length : 0} characters');
      if (medicinesJson == null || medicinesJson.isEmpty) {
        print('No medicines found in storage');
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(medicinesJson);
      final medicines = decoded.map((m) => Medicine(
        id: m['id'],
        name: m['name'],
        batchNumber: m['batchNumber'],
        quantity: m['quantity'],
        purchasingCost: (m['purchasingCost'] as num).toDouble(),
        averageSellingCost: (m['averageSellingCost'] as num).toDouble(),
      )).toList();
      print('Decoded ${medicines.length} medicines from JSON');
      return medicines;
    } catch (e) {
      print('Error in loadMedicines: $e');
      return [];
    }
  }

  // Save Employees
  Future<void> saveEmployees(List<Employee> employees) async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = employees.map((e) => {
      'id': e.id,
      'name': e.name,
      'position': e.position,
      'totalSalary': e.totalSalary,
    }).toList();
    await prefs.setString(_employeesKey, jsonEncode(employeesJson));
  }

  // Load Employees
  Future<List<Employee>> loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = prefs.getString(_employeesKey);
    if (employeesJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(employeesJson);
    return decoded.map((e) => Employee(
      id: e['id'],
      name: e['name'],
      position: e['position'],
      totalSalary: (e['totalSalary'] as num).toDouble(),
    )).toList();
  }

  // Save Withdrawals
  Future<void> saveWithdrawals(Map<String, List<Withdrawal>> withdrawals) async {
    final prefs = await SharedPreferences.getInstance();
    final withdrawalsJson = <String, dynamic>{};
    withdrawals.forEach((employeeId, withdrawalList) {
      withdrawalsJson[employeeId] = withdrawalList.map((w) => {
        'id': w.id,
        'amount': w.amount,
        'date': w.date.toIso8601String(),
      }).toList();
    });
    await prefs.setString(_withdrawalsKey, jsonEncode(withdrawalsJson));
  }

  // Load Withdrawals
  Future<Map<String, List<Withdrawal>>> loadWithdrawals() async {
    final prefs = await SharedPreferences.getInstance();
    final withdrawalsJson = prefs.getString(_withdrawalsKey);
    if (withdrawalsJson == null) return {};
    
    final Map<String, dynamic> decoded = jsonDecode(withdrawalsJson);
    final Map<String, List<Withdrawal>> result = {};
    decoded.forEach((employeeId, withdrawalList) {
      result[employeeId] = (withdrawalList as List).map((w) => Withdrawal(
        id: w['id'],
        amount: (w['amount'] as num).toDouble(),
        date: DateTime.parse(w['date']),
      )).toList();
    });
    return result;
  }

  // Save Cheques
  Future<void> saveCheques(List<Cheque> cheques) async {
    final prefs = await SharedPreferences.getInstance();
    final chequesJson = cheques.map((c) => {
      'id': c.id,
      'chequeNumber': c.chequeNumber,
      'chequeDate': c.chequeDate.toIso8601String(),
      'isGiven': c.isGiven,
      'vendorName': c.vendorName,
      'bank': c.bank,
      'amount': c.amount,
    }).toList();
    await prefs.setString(_chequesKey, jsonEncode(chequesJson));
  }

  // Load Cheques
  Future<List<Cheque>> loadCheques() async {
    final prefs = await SharedPreferences.getInstance();
    final chequesJson = prefs.getString(_chequesKey);
    if (chequesJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(chequesJson);
    return decoded.map((c) => Cheque(
      id: c['id'],
      chequeNumber: c['chequeNumber'],
      chequeDate: DateTime.parse(c['chequeDate']),
      isGiven: c['isGiven'],
      vendorName: c['vendorName'],
      bank: c['bank'],
      amount: (c['amount'] as num).toDouble(),
    )).toList();
  }

  // Save Bills
  Future<void> saveBills(List<Bill> bills) async {
    final prefs = await SharedPreferences.getInstance();
    final billsJson = bills.map((b) => {
      'id': b.id,
      'billNumber': b.billNumber,
      'date': b.date.toIso8601String(),
      'customerName': b.customerName,
      'customerContact': b.customerContact,
      'items': b.items.map((item) => {
        'medicineId': item.medicineId,
        'medicineName': item.medicineName,
        'batchNumber': item.batchNumber,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'total': item.total,
        // Extra aliases for backward/forward compatibility (in case older versions used different keys).
        'price': item.unitPrice,
        'totalPrice': item.total,
        'qty': item.quantity,
      }).toList(),
      'totalAmount': b.totalAmount,
    }).toList();
    await prefs.setString(_billsKey, jsonEncode(billsJson));
  }

  // Load Bills
  Future<List<Bill>> loadBills() async {
    final prefs = await SharedPreferences.getInstance();
    final billsJson = prefs.getString(_billsKey);
    if (billsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(billsJson);

    double toDoubleValue(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int toIntValue(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
      return 0;
    }

    return decoded.map((b) {
      // Support multiple possible key names for old saved bills.
      final rawItems =
          b['items'] ?? b['billItems'] ?? b['bill_items'] ?? <dynamic>[];

      List<dynamic> itemsList;
      if (rawItems is List) {
        itemsList = rawItems;
      } else if (rawItems is String) {
        // Some older schemas might have stored items as a JSON string.
        final decodedItems = (() {
          try {
            final v = jsonDecode(rawItems);
            return v is List ? v : <dynamic>[];
          } catch (_) {
            return <dynamic>[];
          }
        })();
        itemsList = decodedItems;
      } else {
        itemsList = <dynamic>[];
      }
      final items = itemsList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map((item) {
        final medicineId = (item['medicineId'] ?? item['id'] ?? '').toString();
        final medicineName = (item['medicineName'] ?? item['name'] ?? '').toString();
        final batchNumber = (item['batchNumber'] ?? item['batch'] ?? item['batch_no'] ?? '').toString();

        final quantity = toIntValue(item['quantity'] ?? item['qty']);
        final unitPrice = toDoubleValue(item['unitPrice'] ?? item['price']);

        // Some older schemas may store 'total' as 'totalPrice', or only store unitPrice + quantity.
        final total = (() {
          final directTotal = item['total'] ?? item['totalPrice'];
          final parsedTotal = toDoubleValue(directTotal);
          if (parsedTotal != 0.0 || quantity == 0) return parsedTotal;
          return unitPrice * quantity;
        })();

        return BillItem(
          medicineId: medicineId,
          medicineName: medicineName,
          batchNumber: batchNumber,
          quantity: quantity,
          unitPrice: unitPrice,
          total: total,
        );
      }).toList();

      final totalAmount = toDoubleValue(
        b['totalAmount'] ??
            b['grandTotal'] ??
            b['total'] ??
            0,
      );

      return Bill(
        id: (b['id'] ?? '').toString(),
        billNumber: (b['billNumber'] ?? '').toString(),
        date: DateTime.parse(b['date'] ?? DateTime.now().toIso8601String()),
        customerName: b['customerName']?.toString(),
        customerContact: b['customerContact']?.toString(),
        items: items,
        // If totalAmount is missing/broken but items exist, compute it.
        totalAmount: totalAmount == 0.0 && items.isNotEmpty
            ? Bill.calculateTotal(items)
            : totalAmount,
      );
    }).toList();
  }

  // Save Bill Counter
  Future<void> saveBillCounter(int counter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_billCounterKey, counter);
  }

  // Load Bill Counter
  Future<int> loadBillCounter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_billCounterKey) ?? 1;
  }

  // Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_medicinesKey);
    await prefs.remove(_employeesKey);
    await prefs.remove(_withdrawalsKey);
    await prefs.remove(_chequesKey);
    await prefs.remove(_billsKey);
    await prefs.remove(_billCounterKey);
  }
}
