import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/fcm_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/quotation/models/quotation_model.dart';
import 'features/quotation/presentation/screens/quotation_dashboard_screen.dart';
import 'features/quotation/presentation/screens/quotation_detail_screen.dart';
import 'features/quotation/presentation/screens/quotation_form_screen.dart';
import 'features/quotation/presentation/screens/quotation_list_screen.dart';

/// Global navigator key — used by FcmService for deep-link routing on notification tap.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM — permissions, channels, foreground listener, deep-link handlers
  await FcmService.instance.initialize(navKey: navigatorKey);

  runApp(const OasisApp());
}

class OasisApp extends StatelessWidget {
  const OasisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oasis ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/quotation-dashboard': (context) => const QuotationDashboardScreen(),
        '/quotation-list': (context) => const QuotationListScreen(),
        '/quotation-form': (context) => const QuotationFormScreen(),
      },
      // onGenerateRoute handles dynamic routes — e.g. deep-linking with a docname
      onGenerateRoute: (settings) {
        if (settings.name == '/quotation-detail') {
          // FcmService passes just the docname string as arguments
          final docname = settings.arguments as String? ?? '';
          // Create a minimal Quotation stub — the screen auto-fetches full details
          final stub = Quotation(
            name: docname,
            workflowState: '',
            customerName: '',
            transactionDate: '',
          );
          return MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotation: stub),
            settings: settings,
          );
        }
        return null; // let Flutter handle unknown routes
      },
    );
  }
}
