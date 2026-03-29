import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/providers/core_providers.dart';
import 'package:inventary/core/providers/sync_provider.dart';
import 'package:inventary/core/services/google_api_service.dart';
import 'package:inventary/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventary/features/sales/presentation/screens/pos_screen.dart';
import 'package:inventary/features/settings/presentation/screens/settings_screen.dart';
import 'package:inventary/features/reports/presentation/screens/reports_screen.dart';
import 'package:inventary/features/reports/presentation/screens/movements_screen.dart';
import 'package:inventary/features/sales/presentation/screens/sales_history_screen.dart';
import 'package:inventary/features/sales/presentation/screens/pending_payments_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  
  try {
    await Hive.initFlutter();
    // Pre-apertura de cajas para evitar bloqueos de I/O en runtime
    await Future.wait([
      Hive.openBox('inventory_box'),
      Hive.openBox('sales_cache'),
      Hive.openBox('movements_cache'),
      Hive.openBox('sales_queue'),
      Hive.openBox('movements_queue'),
      Hive.openBox('inventory_queue'),
    ]);
    debugPrint('[Hive] Inicialización completa.');
  } catch (e) {
    debugPrint('[Hive] Error crítico: $e');
  }
  
  final googleApi = GoogleApiService();
  final container = ProviderContainer(
    overrides: [
      googleApiServiceProvider.overrideWithValue(googleApi),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AppBootstrapper(googleApi: googleApi),
    ),
  );
}

class AppBootstrapper extends ConsumerStatefulWidget {
  final GoogleApiService googleApi;
  const AppBootstrapper({super.key, required this.googleApi});

  @override
  ConsumerState<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends ConsumerState<AppBootstrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // SOLUCIÓN FALSO OFFLINE: Aumentado a 15 segundos para conexiones lentas
      await widget.googleApi.init().timeout(const Duration(seconds: 15));
      debugPrint('[Bootstrapper] Google API listo.');
    } catch (e) {
      debugPrint('[Bootstrapper] Entrando en modo Offline por timeout/error: $e');
    } finally {
      // Iniciar sincronización en segundo plano
      ref.read(syncServiceProvider).start();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.teal,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.point_of_sale, size: 80, color: Colors.white),
                SizedBox(height: 24),
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Sincronizando Sistema...', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }
    return const PosApp();
  }
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario & POS',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  final List<Widget> _pages = const [
    InventoryScreen(), PosScreen(), ReportsScreen(),
    SalesHistoryScreen(), PendingPaymentsScreen(), MovementsScreen(), SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema POS'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final syncCount = ref.watch(pendingSyncCountProvider);
            return syncCount.when(
              data: (count) => count > 0
                ? IconButton(
                    icon: Badge(label: Text('$count'), child: const Icon(Icons.cloud_off, color: Colors.orange)),
                    onPressed: () => ref.read(syncServiceProvider).forceSync(),
                  )
                : const Icon(Icons.cloud_done, color: Colors.green),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Icon(Icons.error_outline),
            );
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: _pages[_selectedIndex],
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Center(
                child: Text(
                  'Menú Principal',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Stock'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('POS'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reportes'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Ventas'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending),
              title: const Text('Pagos'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Movs'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              selected: _selectedIndex == 6,
              onTap: () {
                setState(() => _selectedIndex = 6);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (cert, host, port) => true;
  }
}
