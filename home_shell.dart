import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'customers_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  static const _icons = [
    Icons.point_of_sale,
    Icons.inventory_2_outlined,
    Icons.people_outline,
    Icons.receipt_long_outlined,
    Icons.settings_outlined,
  ];
  static const _keys = ['pos', 'products', 'customers', 'sales', 'settings'];

  @override
  Widget build(BuildContext context) {
    final low = context.watch<AppState>().lowStock;
    final pages = <Widget>[
      const PosScreen(),
      const ProductsScreen(),
      const CustomersScreen(),
      const SalesScreen(),
      const SettingsScreen(),
    ];
    Widget icon(int i) {
      final w = Icon(_icons[i]);
      if (i == 1 && low > 0) {
        return Badge(label: Text('$low'), child: w);
      }
      return w;
    }

    final wide = MediaQuery.of(context).size.width >= 800;
    final body = IndexedStack(index: _i, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _i,
            onDestinationSelected: (v) => setState(() => _i = v),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (var i = 0; i < 5; i++)
                NavigationRailDestination(
                    icon: icon(i), label: Text(context.t(_keys[i]))),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (var i = 0; i < 5; i++)
            NavigationDestination(
                icon: icon(i), label: context.t(_keys[i])),
        ],
      ),
    );
  }
}
