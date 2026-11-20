import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/home_screen.dart';
import 'admin_screens.dart';
import 'common_screens.dart';
import 'db.dart';
import 'family_screens.dart';
import 'principal_screens.dart';
import 'school_models.dart';
import 'teacher_screens.dart';
import 'ui.dart';

/// الهيكل الرئيسي بعد الدخول: 4 تبويبات، الأولى تختلف حسب الدور
class RoleShell extends StatefulWidget {
  const RoleShell({super.key});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _tab = 0;

  Widget _homeFor(String role) {
    switch (role) {
      case Roles.owner:
      case Roles.admin:
        return const AdminHome();
      case Roles.principal:
        return const PrincipalHome();
      case Roles.teacher:
        return const TeacherHome();
      case Roles.parent:
        return const ParentHome();
      default:
        return const StudentHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.user;
    final pages = [
      _homeFor(me.role),
      const LibraryTab(),
      const AnnouncementsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: 'المكتبة'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'الإعلانات'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

/// تبويب المكتبة: الكتب والشروحات
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late Future<Catalog> _future;

  @override
  void initState() {
    super.initState();
    _future = CatalogStore.get();
  }

  Future<void> _reload() async {
    final f = CatalogStore.reload();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Catalog>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: LoadingView());
        if (snap.hasError || !snap.hasData) {
          return Scaffold(body: ErrorView(error: snap.error ?? 'تعذر تحميل المكتبة', onRetry: _reload));
        }
        return HomeScreen(catalog: snap.data!, onRefresh: _reload);
      },
    );
  }
}
