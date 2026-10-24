import 'package:flutter/material.dart';

import 'screens/leaderboard_screen.dart';
import 'screens/live_screen.dart';
import 'screens/test_screen.dart';
import 'services/battery_monitor.dart';
import 'services/results_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChargeMeterApp());
}

class ChargeMeterApp extends StatelessWidget {
  const ChargeMeterApp({super.key});

  static const _seed = Color(0xFF4ADE80);

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        margin: EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charge Meter',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final _monitor = BatteryMonitor();
  final _store = ResultsStore();
  int _tab = 0;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monitor.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save battery while in the background.
    if (state == AppLifecycleState.resumed) {
      _monitor.start();
    } else if (state == AppLifecycleState.paused) {
      _monitor.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.bolt_rounded),
          SizedBox(width: 6),
          Text('Charge Meter', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (!BatteryMonitor.isAndroid)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(label: Text('Estimate mode')),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            LiveScreen(monitor: _monitor),
            TestScreen(
              monitor: _monitor,
              store: _store,
              onSaved: () => setState(() => _revision++),
            ),
            LeaderboardScreen(store: _store, revision: _revision),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed_rounded),
              label: 'Live'),
          NavigationDestination(
              icon: Icon(Icons.cable_outlined),
              selectedIcon: Icon(Icons.cable_rounded),
              label: 'Test cable'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Leaderboard'),
        ],
      ),
    );
  }
}
