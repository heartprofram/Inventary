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
        fontFamily: 'Roboto', // Opcional, asegurar que se vea moderno
      ),
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
    InventoryScreen(),
    PosScreen(),
    ReportsScreen(),
    SalesHistoryScreen(),
    PendingPaymentsScreen(),
    MovementsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Inventario',
    'Ventas (POS)',
    'Cierre de Caja',
    'Historial Ventas',
    'Cuentas por Cobrar',
    'Movimientos',
    'Configuración'
  ];

  final List<IconData> _icons = const [
    Icons.inventory,
    Icons.shopping_cart,
    Icons.analytics,
    Icons.receipt_long,
    Icons.pending_actions,
    Icons.list_alt,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_selectedIndex]),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            elevation: 0,
            leading: isWide ? const Icon(Icons.point_of_sale, color: Colors.teal) : null,
          ),
          drawer: isWide ? null : _buildDrawer(),
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedLabelTextStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
                  selectedIconTheme: const IconThemeData(color: Colors.teal),
                  destinations: List.generate(_titles.length, (index) {
                    return NavigationRailDestination(
                      icon: Icon(_icons[index]),
                      selectedIcon: Icon(_icons[index], color: Colors.teal),
                      label: Text(_titles[index]),
                    );
                  }),
                ),
              if (isWide) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: _pages[_selectedIndex],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.teal,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.point_of_sale, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Sistema POS\nInventario',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _titles.length,
              itemBuilder: (context, index) {
                if (index == 6) return Column(
                  children: [
                    const Divider(),
                    _buildDrawerItem(index),
                  ],
                );
                return _buildDrawerItem(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index) {
    return ListTile(
      leading: Icon(_icons[index], color: _selectedIndex == index ? Colors.teal : Colors.grey),
      title: Text(
        _titles[index],
        style: TextStyle(
          color: _selectedIndex == index ? Colors.teal : Colors.black87,
          fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}