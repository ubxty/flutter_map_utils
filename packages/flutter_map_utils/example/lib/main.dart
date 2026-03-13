import 'package:flutter/material.dart';

import 'pages/drawing_page.dart';
import 'pages/editing_page.dart';
import 'pages/measurement_page.dart';
import 'pages/geojson_page.dart';
import 'pages/snapping_page.dart';
import 'pages/all_in_one_page.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_map_utils',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF42A5F5),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = <_PageEntry>[
    _PageEntry(icon: Icons.draw, label: 'Draw', page: DrawingPage()),
    _PageEntry(icon: Icons.edit, label: 'Edit', page: EditingPage()),
    _PageEntry(icon: Icons.straighten, label: 'Measure', page: MeasurementPage()),
    _PageEntry(icon: Icons.data_object, label: 'GeoJSON', page: GeoJsonPage()),
    _PageEntry(icon: Icons.grid_on, label: 'Snap', page: SnappingPage()),
    _PageEntry(icon: Icons.all_inclusive, label: 'All-in-One', page: AllInOnePage()),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Icon(Icons.map, size: 32, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      'Utils',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final p in _pages)
                  NavigationRailDestination(
                    icon: Icon(p.icon),
                    label: Text(p.label),
                  ),
              ],
            ),
          Expanded(child: _pages[_index].page),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final p in _pages)
                  NavigationDestination(icon: Icon(p.icon), label: p.label),
              ],
            ),
    );
  }
}

class _PageEntry {
  final IconData icon;
  final String label;
  final Widget page;
  const _PageEntry({required this.icon, required this.label, required this.page});
}
