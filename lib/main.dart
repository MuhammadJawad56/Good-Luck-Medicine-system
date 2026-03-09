import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'widgets/cheque_notification_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Optimize for low-end systems
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GoodluckMedicineApp());
}

class GoodluckMedicineApp extends StatelessWidget {
  const GoodluckMedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goodluck Medicine',
      debugShowCheckedModeBanner: false,
      // Performance optimizations for low-end systems
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Reduce text scaling for better performance
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF1565C0), // Professional blue
          onPrimary: Colors.white,
          secondary: const Color(0xFF2E7D32), // Medical green
          onSecondary: Colors.white,
          tertiary: const Color(0xFFE65100), // Warm orange
          onTertiary: Colors.white,
          error: const Color(0xFFC62828), // Red
          onError: Colors.white,
          surface: const Color(0xFFFAFAFA), // Off-white background
          onSurface: const Color(0xFF212121), // Dark text
          surfaceContainerHighest: const Color(0xFFF5F5F5),
          outline: const Color(0xFFBDBDBD),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const ChequeNotificationOverlay(
        child: HomePage(),
      ),
      routes: {
        '/cheques': (context) => const ChequeNotificationOverlay(
          child: HomePage(),
        ),
      },
    );
  }
}
