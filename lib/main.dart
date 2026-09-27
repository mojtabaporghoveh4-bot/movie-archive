import 'package:flutter/material.dart';

import 'archive.dart';
import 'screens/browse.dart';
import 'screens/drives.dart';
import 'screens/library.dart';
import 'screens/settings.dart';
import 'screens/stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  archive = await Archive.open();
  runApp(const App());
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archive,
        builder: (_, _) => MaterialApp(
          title: 'Movie Archive',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: archive.themeMode,
          home: const Shell(),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _pages = [
    (Icons.video_library_outlined, Icons.video_library, 'Library'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Browse'),
    (Icons.storage_outlined, Icons.storage, 'Drives'),
    (Icons.insights_outlined, Icons.insights, 'Stats'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  Widget get _body => switch (_tab) {
        0 => LibraryPage(key: const ValueKey('library')),
        1 => const BrowsePage(),
        2 => const DrivesPage(),
        3 => const StatsPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    if (!wide) {
      return Scaffold(
        body: _body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            for (final (icon, sel, label) in _pages)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: label),
          ],
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Icon(Icons.movie_filter_rounded, size: 32, color: scheme.primary),
          ),
          destinations: [
            for (final (icon, sel, label) in _pages)
              NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: Text(label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _body),
      ]),
    );
  }
}
