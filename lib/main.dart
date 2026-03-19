import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/providers/core_providers.dart';
import 'package:inventary/core/services/google_api_service.dart';
import 'package:inventary/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventary/features/sales/presentation/screens/pos_screen.dart';
import 'package:inventary/features/settings/presentation/screens/settings_screen.dart';
import 'package:inventary/features/reports/presentation/screens/reports_screen.dart';
import 'package:inventary/features/reports/presentation/screens/movements_screen.dart';
import 'package:inventary/features/sales/presentation/screens/sales_history_screen.dart';
import 'package:inventary/features/sales/presentation/screens/pending_payments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos GoogleApiService (se ajustará automáticamente según la plataforma)
  final googleApi = GoogleApiService();
  await googleApi.init();
  
  runApp(
    ProviderScope(
      overrides: [
        googleApiServiceProvider.overrideWithValue(googleApi),
      ],
      child: const PosApp(),
    ),
  );
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario & POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MainContent();
  }
}

class _MainContent extends StatefulWidget {
  const _MainContent();

  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  int _selectedIndex = 1;

  static const List<Widget> _pages = <Widget>[
    InventoryScreen(),
    PosScreen(),
    ReportsScreen(),
    SalesHistoryScreen(),
    PendingPaymentsScreen(),
    MovementsScreen(),
    SettingsScreen(),
  ];

  static const List<String> _titles = [
    'Inventario',
    'Ventas (POS)',
    'Cierre de Caja',
    'Historial Ventas',
    'Cuentas por Cobrar',
    'Movimientos',
    'Configuración'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.teal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.point_of_sale, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Sistema POS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventario'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Ventas (POS)'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Cierre de Caja'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Historial Ventas'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Movimientos'),
              selected: _selectedIndex == 5,
              onTap: () => _onItemTapped(5),
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions),
              title: const Text('Cuentas por Cobrar'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              selected: _selectedIndex == 6,
              onTap: () => _onItemTapped(6),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}