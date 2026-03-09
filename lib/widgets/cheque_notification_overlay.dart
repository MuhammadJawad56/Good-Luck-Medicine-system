import 'package:flutter/material.dart';
import '../services/cheque_notification_service.dart';
import '../models/cheque.dart';
import '../pages/cheques_page.dart';

class ChequeNotificationOverlay extends StatefulWidget {
  final Widget child;

  const ChequeNotificationOverlay({super.key, required this.child});

  @override
  State<ChequeNotificationOverlay> createState() => _ChequeNotificationOverlayState();
}

class _ChequeNotificationOverlayState extends State<ChequeNotificationOverlay> {
  final ChequeNotificationService _service = ChequeNotificationService();
  List<Cheque> _approachingCheques = [];
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_checkApproachingCheques);
    // Defer the initial check to after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApproachingCheques();
    });
    // Check every minute for approaching cheques
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _checkApproachingCheques();
        _startPeriodicCheck();
      }
    });
  }

  void _checkApproachingCheques() {
    if (!mounted) return;
    
    final approaching = _service.getApproachingCheques();
    // Use Future.microtask to defer setState to after current build
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _approachingCheques = approaching;
          _isVisible = approaching.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_checkApproachingCheques);
    super.dispose();
  }

  void _dismissNotification() {
    setState(() {
      _isVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible && _approachingCheques.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  elevation: 8,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Cheque Date Approaching!',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _dismissNotification,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _approachingCheques.length,
                            itemBuilder: (context, index) {
                              final cheque = _approachingCheques[index];
                              final daysLeft = cheque.daysUntilDate;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: daysLeft <= 3 ? Colors.red.shade50 : Colors.orange.shade50,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: daysLeft <= 3 ? Colors.red : Colors.orange,
                                    child: Text(
                                      '$daysLeft',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Cheque #${cheque.chequeNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Vendor: ${cheque.vendorName}'),
                                      Text('Bank: ${cheque.bank}'),
                                      Text(
                                        'Date: ${cheque.chequeDate.day}/${cheque.chequeDate.month}/${cheque.chequeDate.year}',
                                      ),
                                      Text(
                                        'Type: ${cheque.isGiven ? "Given" : "Received"}',
                                        style: TextStyle(
                                          color: cheque.isGiven ? Colors.blue : Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    'PKR ${cheque.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _dismissNotification,
                              child: const Text('Dismiss'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                _dismissNotification();
                                // Navigate to cheques page
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ChequeNotificationOverlay(
                                      child: ChequesPage(),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('View Cheques'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
