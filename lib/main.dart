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

// Material Request Screen Imports
import 'features/material_request/models/material_request_model.dart';
import 'features/material_request/presentation/screens/material_request_dashboard_screen.dart';
import 'features/material_request/presentation/screens/material_request_detail_screen.dart';
import 'features/material_request/presentation/screens/material_request_form_screen.dart';
import 'features/material_request/presentation/screens/material_request_list_screen.dart';

// Journal Entry Screen Imports
import 'features/journal_entry/models/journal_entry_model.dart';
import 'features/journal_entry/presentation/screens/journal_entry_dashboard_screen.dart';
import 'features/journal_entry/presentation/screens/journal_entry_detail_screen.dart';
import 'features/journal_entry/presentation/screens/journal_entry_form_screen.dart';
import 'features/journal_entry/presentation/screens/journal_entry_list_screen.dart';

// Payment Entry Screen Imports
import 'features/payment_entry/models/payment_entry_model.dart';
import 'features/payment_entry/presentation/screens/payment_entry_dashboard_screen.dart';
import 'features/payment_entry/presentation/screens/payment_entry_detail_screen.dart';
import 'package:oasis/features/payment_entry/presentation/screens/payment_entry_form_screen.dart';
import 'package:oasis/features/payment_entry/presentation/screens/payment_entry_list_screen.dart';

// Sales Invoice Screen Imports
import 'package:oasis/features/sales_invoice/models/sales_invoice_model.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_dashboard_screen.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_detail_screen.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_form_screen.dart';
import 'package:oasis/features/sales_invoice/presentation/screens/sales_invoice_list_screen.dart';


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

        // Material Request Routes
        '/material-request-dashboard': (context) => const MaterialRequestDashboardScreen(),
        '/material-request-list': (context) => const MaterialRequestListScreen(),
        '/material-request-form': (context) => const MaterialRequestFormScreen(),

        // Journal Entry Routes
        '/journal-entry-dashboard': (context) => const JournalEntryDashboardScreen(),
        '/journal-entry-list': (context) => const JournalEntryListScreen(),
        '/journal-entry-form': (context) => const JournalEntryFormScreen(),

        // Payment Entry Routes
        '/payment-entry-dashboard': (context) => const PaymentEntryDashboardScreen(),
        '/payment-entry-list': (context) => const PaymentEntryListScreen(),
        '/payment-entry-form': (context) => const PaymentEntryFormScreen(),

        // Sales Invoice Routes
        '/sales-invoice-dashboard': (context) => const SalesInvoiceDashboardScreen(),
        '/sales-invoice-list': (context) => const SalesInvoiceListScreen(),
        '/sales-invoice-form': (context) => const SalesInvoiceFormScreen(),
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

        if (settings.name == '/material-request-detail') {
          final docname = settings.arguments as String? ?? '';
          final stub = MaterialRequestModel(
            name: docname,
            company: '',
            materialRequestType: 'Purchase',
            transactionDate: '',
            items: [],
          );
          return MaterialPageRoute(
            builder: (_) => MaterialRequestDetailScreen(materialRequest: stub),
            settings: settings,
          );
        }

        if (settings.name == '/journal-entry-detail') {
          final docname = settings.arguments as String? ?? '';
          final stub = JournalEntryModel(
            name: docname,
            company: '',
            voucherType: 'Journal Entry',
            postingDate: '',
            accounts: [],
          );
          return MaterialPageRoute(
            builder: (_) => JournalEntryDetailScreen(journalEntry: stub),
            settings: settings,
          );
        }

        if (settings.name == '/payment-entry-detail') {
          final docname = settings.arguments as String? ?? '';
          final stub = PaymentEntryModel(
            name: docname,
            company: '',
            paymentType: 'Receive',
            postingDate: '',
            modeOfPayment: '',
            paidFrom: '',
            paidTo: '',
            paidAmount: 0.0,
            receivedAmount: 0.0,
            targetExchangeRate: 1.0,
            references: [],
          );
          return MaterialPageRoute(
            builder: (_) => PaymentEntryDetailScreen(paymentEntry: stub),
            settings: settings,
          );
        }

        if (settings.name == '/sales-invoice-detail') {
          final docname = settings.arguments as String? ?? '';
          final stub = SalesInvoiceModel(
            name: docname,
            customer: '',
            customerName: '',
            postingDate: '',
            dueDate: '',
            currency: 'QAR',
            conversionRate: 1.0,
            sellingPriceList: 'Standard Selling',
            priceListCurrency: 'QAR',
            plcConversionRate: 1.0,
            outstandingAmount: 0.0,
            items: [],
          );
          return MaterialPageRoute(
            builder: (_) => SalesInvoiceDetailScreen(salesInvoice: stub),
            settings: settings,
          );
        }

        return null; // let Flutter handle unknown routes
      },
    );
  }
}
