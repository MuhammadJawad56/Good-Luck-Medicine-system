import 'package:flutter/material.dart';
import '../models/cheque.dart';

class ChequeNotificationService {
  static final ChequeNotificationService _instance = ChequeNotificationService._internal();
  factory ChequeNotificationService() => _instance;
  ChequeNotificationService._internal();

  List<Cheque> _cheques = [];
  final List<VoidCallback> _listeners = [];

  void setCheques(List<Cheque> cheques) {
    _cheques = cheques;
    _notifyListeners();
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

  List<Cheque> getApproachingCheques() {
    return _cheques.where((cheque) => cheque.isApproaching).toList();
  }
}
