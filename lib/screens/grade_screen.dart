import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import 'subject_screen.dart';

/// مواد الصف، مع اختيار القسم (علمي/أدبي) للثاني والثالث الثانوي
class GradeScreen extends StatefulWidget {
  final Grade grade;

  const GradeScreen({super.key, required this.grade});

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  String _track = 'sci';

  @override
  void initState() {
    super.initState();
    UserPrefs.getTrack().then((t) {
      if (t.isNotEmpty) setState(() => _track = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grade;
    final subjects = g.subjectsFor(g.hasTracks ? _track : '');

    return Scaffold(
      appBar: AppBar(title: Text(g.name)),
      body: Column(
        children: [
          if (g.hasTracks)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sci', label: Text('علمي'), icon: Icon(Icons.science)),
                  ButtonSegment(value: 'lit', label: Text('أدبي'), icon: Icon(Icons.menu_book)),
                ],
                selected: {_track},
                onSelectionChanged: (s) {
                  setState(() => _track = s.first);
                  UserPrefs.setTrack(s.first);
                },
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, i) {
                final s = subjects[i];
                final available = s.books.where((b) => b.isAvailable).length;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SubjectScreen(subject: s, gradeName: g.name)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.icon, style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 8),
                          Text(s.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            '$available/${s.books.length} كتب · ${s.lessons.length} شرح',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
