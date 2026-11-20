import 'package:flutter/material.dart';

import 'common_screens.dart';
import 'db.dart';
import 'family_screens.dart';
import 'school_models.dart';
import 'ui.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

// ───────────────────────── بيانات اليوم ─────────────────────────

class TodaySummary {
  final List<SchoolClass> classes;
  final Map<String, AppUser> students; // uid -> student
  final List<AttendanceDay> today;
  final int teachers;
  final int parents;

  TodaySummary(this.classes, this.students, this.today, this.teachers, this.parents);

  int get studentsCount => students.length;

  int status(String s) => today.fold<int>(0, (sum, d) => sum + d.count(s));

  double? get todayRate {
    final total = today.fold<int>(0, (sum, d) => sum + d.records.length);
    if (total == 0) return null;
    return (status(Att.present) + status(Att.late)) / total * 100;
  }

  List<SchoolClass> get notTaken {
    final taken = today.map((d) => d.classId).toSet();
    return classes.where((c) => !taken.contains(c.id)).toList();
  }

  List<MapEntry<AppUser, String>> get absentees {
    final result = <MapEntry<AppUser, String>>[];
    final names = {for (final c in classes) c.id: c.name};
    for (final d in today) {
      d.records.forEach((uid, st) {
        if (st == Att.absent && students[uid] != null) {
          result.add(MapEntry(students[uid]!, names[d.classId] ?? ''));
        }
      });
    }
    return result;
  }
}

Future<TodaySummary> loadTodaySummary() async {
  final r = await Future.wait<Object?>([
    Db.classes(),
    Db.usersByRole(Roles.student),
    Db.attendanceOnDate(todayKey),
    Db.countRole(Roles.teacher),
    Db.countRole(Roles.parent),
  ]);
  final students = r[1] as List<AppUser>;
  return TodaySummary(
    r[0] as List<SchoolClass>,
    {for (final s in students) s.uid: s},
    r[2] as List<AttendanceDay>,
    r[3] as int,
    r[4] as int,
  );
}

// ───────────────────────── واجهة المدير ─────────────────────────

class PrincipalHome extends StatelessWidget {
  const PrincipalHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Session.settings.name), actions: const [NotificationBell()]),
      body: AsyncBody<TodaySummary>(
        load: loadTodaySummary,
        builder: (context, s, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeaderCard(
                title: 'أهلاً ${Session.user.name.split(' ').first} 👋',
                subtitle: 'ملخص ${prettyDay(todayKey)}',
                icon: Icons.insights,
              ),
              const SizedBox(height: 12),
              TodayStats(summary: s),
              const SizedBox(height: 12),
              ActionGrid(
                children: [
                  ActionTile(
                    label: 'تقارير الفصول',
                    icon: Icons.analytics,
                    onTap: () => _push(context, const ClassReportsScreen()),
                  ),
                  ActionTile(
                    label: 'بحث عن طالب',
                    icon: Icons.person_search,
                    color: kInfo,
                    onTap: () => _push(context, StudentSearchScreen(students: s.students.values.toList())),
                  ),
                  ActionTile(
                    label: 'المعلمون',
                    icon: Icons.co_present,
                    color: Colors.purple,
                    onTap: () => _push(context, const TeachersDirectoryScreen()),
                  ),
                  ActionTile(
                    label: 'إعلان عام',
                    icon: Icons.campaign,
                    color: kAccent,
                    onTap: () => _push(context, const ComposeAnnouncementScreen()),
                  ),
                  ActionTile(
                    label: 'غياب اليوم',
                    icon: Icons.person_off,
                    color: kDanger,
                    onTap: () => _push(context, TodayAbsenceScreen(summary: s)),
                  ),
                  ActionTile(
                    label: 'لم يُحضَّر',
                    icon: Icons.pending_actions,
                    color: Colors.blueGrey,
                    onTap: () => _push(context, TodayAbsenceScreen(summary: s, showNotTaken: true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقات أرقام اليوم (تُستخدم للمدير والإدارة)
class TodayStats extends StatelessWidget {
  final TodaySummary summary;

  const TodayStats({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(label: 'الطلاب', value: '${s.studentsCount}', icon: Icons.groups)),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    label: 'المعلمون', value: '${s.teachers}', icon: Icons.co_present, color: Colors.purple)),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(label: 'الفصول', value: '${s.classes.length}', icon: Icons.class_, color: kInfo)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'حضور اليوم',
                value: pct(s.todayRate),
                icon: Icons.event_available,
                color: pctColor(s.todayRate),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'غائبون اليوم',
                value: '${s.status(Att.absent)}',
                icon: Icons.person_off,
                color: kDanger,
                onTap: () => _push(context, TodayAbsenceScreen(summary: s)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'فصول لم تُحضَّر',
                value: '${s.notTaken.length}',
                icon: Icons.pending_actions,
                color: Colors.blueGrey,
                onTap: () => _push(context, TodayAbsenceScreen(summary: s, showNotTaken: true)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TodayAbsenceScreen extends StatelessWidget {
  final TodaySummary summary;
  final bool showNotTaken;

  const TodayAbsenceScreen({super.key, required this.summary, this.showNotTaken = false});

  @override
  Widget build(BuildContext context) {
    final absentees = summary.absentees;
    final notTaken = summary.notTaken;
    return Scaffold(
      appBar: AppBar(title: Text(showNotTaken ? 'فصول لم تُحضَّر اليوم' : 'غياب اليوم')),
      body: showNotTaken
          ? (notTaken.isEmpty
              ? const EmptyView(icon: Icons.verified, text: 'كل الفصول تم تحضيرها اليوم 👏')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final c in notTaken)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(leading: const Icon(Icons.class_), title: Text(c.label)),
                      ),
                  ],
                ))
          : (absentees.isEmpty
              ? const EmptyView(icon: Icons.verified, text: 'لا يوجد غياب مسجّل اليوم')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final e in absentees)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Avatar(e.key.name, size: 36, color: kDanger),
                          title: Text(e.key.name),
                          subtitle: Text(e.value),
                          onTap: () => _push(context, StudentReportScreen(student: e.key)),
                        ),
                      ),
                  ],
                )),
    );
  }
}

// ───────────────────────── تقارير الفصول ─────────────────────────

class ClassReportsScreen extends StatelessWidget {
  const ClassReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقارير الفصول')),
      body: AsyncBody<List<SchoolClass>>(
        load: Db.classes,
        builder: (context, classes, reload) {
          if (classes.isEmpty) return const EmptyView(icon: Icons.class_outlined, text: 'لا توجد فصول بعد');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimary.withValues(alpha: 0.12),
                  child: Text('${classes[i].grade}', style: const TextStyle(color: kPrimary)),
                ),
                title: Text(classes[i].label),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _push(context, ClassReportScreen(cls: classes[i])),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClassReport {
  final List<AppUser> students;
  final List<AttendanceDay> attendance;
  final List<Assessment> assessments;

  _ClassReport(this.students, this.attendance, this.assessments);

  double? attendanceRateOf(String uid) {
    var total = 0;
    var ok = 0;
    for (final d in attendance) {
      final s = d.records[uid];
      if (s == null) continue;
      total++;
      if (s == Att.present || s == Att.late) ok++;
    }
    return total == 0 ? null : ok / total * 100;
  }

  double? averageOf(String uid, int term) {
    final v = assessments.where((a) => a.term == term).map((a) => a.percentOf(uid)).whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  Map<String, double> subjectAverages(int term) {
    final map = <String, List<double>>{};
    for (final a in assessments.where((a) => a.term == term)) {
      final avg = a.classAverage;
      if (avg != null) map.putIfAbsent(a.subjectName, () => []).add(avg);
    }
    return map.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }
}

class ClassReportScreen extends StatelessWidget {
  final SchoolClass cls;

  const ClassReportScreen({super.key, required this.cls});

  Future<_ClassReport> _load() async {
    final r = await Future.wait<Object?>([
      Db.studentsOfClass(cls.id),
      Db.attendanceOfClass(cls.id),
      Db.assessmentsOfClass(cls.id),
    ]);
    return _ClassReport(r[0] as List<AppUser>, r[1] as List<AttendanceDay>, r[2] as List<Assessment>);
  }

  @override
  Widget build(BuildContext context) {
    final term = Session.settings.term;
    return Scaffold(
      appBar: AppBar(title: Text('تقرير ${cls.name}')),
      body: AsyncBody<_ClassReport>(
        load: _load,
        builder: (context, r, reload) {
          final subj = r.subjectAverages(term);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: StatTile(label: 'الطلاب', value: '${r.students.length}', icon: Icons.groups)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                          label: 'أيام التحضير',
                          value: '${r.attendance.length}',
                          icon: Icons.fact_check,
                          color: kInfo),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                          label: 'التقييمات',
                          value: '${r.assessments.length}',
                          icon: Icons.grade,
                          color: kAccent),
                    ),
                  ],
                ),
                SectionTitle('متوسط المواد (${term == 2 ? 'الترم الثاني' : 'الترم الأول'})'),
                if (subj.isEmpty)
                  const Card(child: ListTile(title: Text('لا توجد درجات بعد')))
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (final e in subj.entries) ...[
                            Row(
                              children: [
                                SizedBox(width: 110, child: Text(e.key)),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (e.value / 100).clamp(0.0, 1.0),
                                      minHeight: 12,
                                      color: pctColor(e.value),
                                      backgroundColor: Colors.black12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(width: 52, child: Text(pct(e.value), textAlign: TextAlign.end)),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SectionTitle('الطلاب'),
                if (r.students.isEmpty)
                  const Card(child: ListTile(title: Text('لا يوجد طلاب')))
                else
                  Card(
                    child: Column(
                      children: [
                        for (final s in r.students)
                          ListTile(
                            leading: Avatar(s.name, size: 34),
                            title: Text(s.name),
                            subtitle: Text('الحضور ${pct(r.attendanceRateOf(s.uid))}'),
                            trailing: StatusChip(pct(r.averageOf(s.uid, term)),
                                color: pctColor(r.averageOf(s.uid, term))),
                            onTap: () => _push(context, StudentReportScreen(student: s)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StudentReportScreen extends StatelessWidget {
  final AppUser student;

  const StudentReportScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          if (student.parentUid.isNotEmpty)
            IconButton(
              tooltip: 'مراسلة ولي الأمر',
              icon: const Icon(Icons.chat),
              onPressed: () async {
                final p = await Db.user(student.parentUid);
                if (!context.mounted) return;
                await openWhatsApp(context, p?.phone ?? '', 'السلام عليكم ولي أمر الطالب ${student.name}، ');
              },
            ),
        ],
      ),
      body: StudentDashboard(student: student, greeting: student.name),
    );
  }
}

class StudentSearchScreen extends StatefulWidget {
  final List<AppUser> students;

  const StudentSearchScreen({super.key, required this.students});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.students.where((s) => _q.isEmpty || s.name.contains(_q) || s.username.contains(_q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('بحث عن طالب')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اكتب اسم الطالب'),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: Avatar(list[i].name, size: 34),
                title: Text(list[i].name),
                subtitle: Text(list[i].username),
                onTap: () => _push(context, StudentReportScreen(student: list[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeachersDirectoryScreen extends StatelessWidget {
  const TeachersDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المعلمون')),
      body: AsyncBody<List<AppUser>>(
        load: () => Db.usersByRole(Roles.teacher),
        builder: (context, list, reload) {
          if (list.isEmpty) return const EmptyView(icon: Icons.co_present, text: 'لا يوجد معلمون بعد');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = list[i];
              return Card(
                child: ListTile(
                  leading: Avatar(t.name, color: Colors.purple),
                  title: Text(t.name),
                  subtitle: Text(t.assignments.isEmpty
                      ? 'بدون فصول'
                      : t.assignments.map((a) => '${a.subjectName} (${a.className})').join('، ')),
                  trailing: t.phone.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.chat, color: kSuccess),
                          onPressed: () => openWhatsApp(context, t.phone, 'السلام عليكم أ. ${t.name}، '),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
