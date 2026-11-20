import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import 'downloads_screen.dart';
import 'grade_screen.dart';

/// الشاشة الرئيسية: "صفّي" في الأعلى، ثم كل المراحل والصفوف
class HomeScreen extends StatefulWidget {
  final Catalog catalog;
  final Future<void> Function() onRefresh;

  const HomeScreen({super.key, required this.catalog, required this.onRefresh});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _myGradeId;

  @override
  void initState() {
    super.initState();
    UserPrefs.getGrade().then((g) => setState(() => _myGradeId = g));
  }

  Future<void> _openGrade(Grade g) async {
    await UserPrefs.setGrade(g.id);
    setState(() => _myGradeId = g.id);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => GradeScreen(grade: g)));
  }

  @override
  Widget build(BuildContext context) {
    final myGrade = _myGradeId == null ? null : widget.catalog.findGrade(_myGradeId!);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة'),
        actions: [
          IconButton(
            tooltip: 'كتبي المحمّلة',
            icon: const Icon(Icons.download_done),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DownloadsScreen(catalog: widget.catalog)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (myGrade != null) ...[
              Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const Icon(Icons.school, size: 36),
                  title: const Text('صفّي'),
                  subtitle: Text(myGrade.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_back_ios_new, size: 16, textDirection: TextDirection.ltr),
                  onTap: () => _openGrade(myGrade),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final stage in widget.catalog.stages) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4),
                child: Text(stage.name,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: scheme.primary)),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  for (final g in stage.grades)
                    _GradeTile(
                      grade: g,
                      selected: g.id == _myGradeId,
                      onTap: () => _openGrade(g),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  final Grade grade;
  final bool selected;
  final VoidCallback onTap;

  const _GradeTile({required this.grade, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${grade.order}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : scheme.primary)),
              const SizedBox(height: 4),
              Text(
                grade.name.replaceFirst('الصف ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
