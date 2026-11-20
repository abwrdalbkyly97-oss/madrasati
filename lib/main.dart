import 'package:flutter/material.dart';

import 'models.dart';
import 'services.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MadrasatiApp());
}

class MadrasatiApp extends StatelessWidget {
  const MadrasatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F766E); // أخضر مدرسي هادئ
    return MaterialApp(
      title: 'مدرستي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      // كل التطبيق من اليمين لليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const RootShell(),
    );
  }
}

/// الهيكل الرئيسي: يحمّل الفهرس مرة واحدة ثم يعرض التبويبات
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late Future<Catalog> _catalog;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _catalog = CatalogRepository().load();
  }

  Future<void> _reload() async {
    setState(() => _catalog = CatalogRepository().load());
    await _catalog;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Catalog>(
      future: _catalog,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل المكتبة'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }
        final catalog = snap.data!;
        final pages = [
          HomeScreen(catalog: catalog, onRefresh: _reload),
          DownloadsScreen(catalog: catalog),
        ];
        return Scaffold(
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.local_library_outlined),
                  selectedIcon: Icon(Icons.local_library),
                  label: 'المكتبة'),
              NavigationDestination(
                  icon: Icon(Icons.download_done_outlined),
                  selectedIcon: Icon(Icons.download_done),
                  label: 'كتبي المحمّلة'),
            ],
          ),
        );
      },
    );
  }
}
