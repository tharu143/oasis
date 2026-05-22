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

// Sales Order Screen Imports
import 'features/sales_order/models/sales_order_model.dart';
import 'features/sales_order/presentation/screens/sales_order_dashboard_screen.dart';
import 'features/sales_order/presentation/screens/sales_order_detail_screen.dart';
import 'features/sales_order/presentation/screens/sales_order_form_screen.dart';
import 'features/sales_order/presentation/screens/sales_order_list_screen.dart';

// Delivery Note Screen Imports
import 'features/delivery_note/models/delivery_note_model.dart';
import 'features/delivery_note/presentation/screens/delivery_note_dashboard_screen.dart';
import 'features/delivery_note/presentation/screens/delivery_note_detail_screen.dart';
import 'features/delivery_note/presentation/screens/delivery_note_form_screen.dart';
import 'features/delivery_note/presentation/screens/delivery_note_list_screen.dart';

// Purchase Order Screen Imports
import 'features/purchase_order/presentation/screens/purchase_order_dashboard_screen.dart';
import 'features/purchase_order/presentation/screens/purchase_order_detail_screen.dart';
import 'features/purchase_order/presentation/screens/purchase_order_form_screen.dart';
import 'features/purchase_order/presentation/screens/purchase_order_list_screen.dart';

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
        
        // Sales Order Routes
        '/sales-order-dashboard': (context) => const SalesOrderDashboardScreen(),
        '/sales-order-list': (context) => const SalesOrderListScreen(),
        '/sales-order-form': (context) => const SalesOrderFormScreen(),

        // Delivery Note Routes
        '/delivery-note-dashboard': (context) => const DeliveryNoteDashboardScreen(),
        '/delivery-note-list': (context) => const DeliveryNoteListScreen(),
        '/delivery-note-form': (context) => const DeliveryNoteFormScreen(),

        // Purchase Order Routes
        '/purchase-order-dashboard': (context) => const PurchaseOrderDashboardScreen(),
        '/purchase-order-list': (context) => const PurchaseOrderListScreen(),
        '/purchase-order-form': (context) => const PurchaseOrderFormScreen(),
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
        
        if (settings.name == '/sales-order-detail') {
          // FcmService passes just the docname string as arguments
          final docname = settings.arguments as String? ?? '';
          // Create a minimal SalesOrderModel stub — the screen auto-fetches full details
          final stub = SalesOrderModel(
            name: docname,
            customer: '',
            customerName: '',
            transactionDate: '',
            deliveryDate: '',
            orderType: 'Sales',
            currency: 'QAR',
            conversionRate: 1.0,
            sellingPriceList: 'Standard Selling',
            priceListCurrency: 'QAR',
            plcConversionRate: 1.0,
            items: [],
          );
          return MaterialPageRoute(
            builder: (_) => SalesOrderDetailScreen(salesOrder: stub),
            settings: settings,
          );
        }

        if (settings.name == '/delivery-note-detail') {
          final docname = settings.arguments as String? ?? '';
          final stub = DeliveryNoteModel(
            name: docname,
            customer: '',
            customerName: '',
            postingDate: '',
            postingTime: '',
            currency: 'QAR',
            conversionRate: 1.0,
            sellingPriceList: 'Standard Selling',
            priceListCurrency: 'QAR',
            plcConversionRate: 1.0,
            items: [],
          );
          return MaterialPageRoute(
            builder: (_) => DeliveryNoteDetailScreen(deliveryNote: stub),
            settings: settings,
          );
        }

        if (settings.name == '/purchase-order-detail') {
          final docname = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: docname),
            settings: settings,
          );
        }
        return null; // let Flutter handle unknown routes
      },
    );
  }
}
