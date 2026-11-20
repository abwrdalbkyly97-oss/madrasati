import 'package:flutter/material.dart';

import 'common_screens.dart';
import 'db.dart';
import 'school_models.dart';
import 'ui.dart';

// ───────────────────────── بيانات الطالب ─────────────────────────

class StudentData {
  final AppUser student;
  final SchoolClass? cls;
  final Map<int, List<String>> timetable;
  final List<Homework> homework;
  final List<Assessment> assessments;
  final List<AttendanceDay> attendance;

  StudentData({
    required this.student,
    required this.cls,
    required this.timetable,
    required this.homework,
    required this.assessments,
    required this.attendance,
  });

  /// الأيام التي سُجّل فيها حضور هذا الطالب
  List<MapEntry<String, String>> get myDays => attendance
      .where((d) => d.records.containsKey(student.uid))
      .map((d) => MapEntry(d.date, d.records[student.uid]!))
      .toList();

  int countStatus(String s) => myDays.where((e) => e.value == s).length;

  double? get attendanceRate {
    final days = myDays;
    if (days.isEmpty) return null;
    final ok = days.where((e) => e.value == Att.present || e.value == Att.late).length;
    return ok / days.length * 100;
  }

  List<Assessment> get myAssessments => assessments.where((a) => a.scores.containsKey(student.uid)).toList();

  double? averageOf(Iterable<Assessment> list) {
    final values = list.map((a) => a.percentOf(student.uid)).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get overallAverage => averageOf(myAssessments.where((a) => a.term == Session.settings.term));

  List<Homework> get upcomingHomework {
    final today = todayKey;
    final list = homework.where((h) => h.dueDate.compareTo(today) >= 0).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }
}

Future<StudentData> loadStudentData(AppUser s) async {
  if (s.classId.isEmpty) {
    return StudentData(student: s, cls: null, timetable: {}, homework: [], assessments: [], attendance: []);
  }
  final results = await Future.wait<Object?>([
    Db.classById(s.classId),
    Db.timetable(s.classId),
    Db.homeworkOfClass(s.classId),
    Db.assessmentsOfClass(s.classId),
    Db.attendanceOfClass(s.classId),
  ]);
  return StudentData(
    student: s,
    cls: results[0] as SchoolClass?,
    timetable: results[1] as Map<int, List<String>>,
    homework: results[2] as List<Homework>,
    assessments: results[3] as List<Assessment>,
    attendance: results[4] as List<AttendanceDay>,
  );
}

// ───────────────────────── واجهة الطالب ─────────────────────────

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.user;
    return Scaffold(
      appBar: AppBar(title: Text(Session.settings.name), actions: const [NotificationBell()]),
      body: StudentDashboard(student: me, greeting: 'أهلاً ${me.name.split(' ').first} 👋'),
    );
  }
}

// ───────────────────────── واجهة ولي الأمر ─────────────────────────

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Session.settings.name), actions: const [NotificationBell()]),
      body: AsyncBody<List<AppUser>>(
        load: () => Db.childrenOf(Session.user.uid),
        builder: (context, kids, reload) {
          if (kids.isEmpty) {
            return const EmptyView(
              icon: Icons.family_restroom,
              text: 'لم يتم ربط أي طالب بحسابك بعد.\nتواصل مع إدارة المدرسة.',
            );
          }
          final index = _selected.clamp(0, kids.length - 1);
          final child = kids[index];
          return Column(
            children: [
              if (kids.length > 1)
                SizedBox(
                  height: 62,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    children: [
                      for (var i = 0; i < kids.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.child_care, size: 18),
                            label: Text(kids[i].name.split(' ').first),
                            selected: i == index,
                            onSelected: (_) => setState(() => _selected = i),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: StudentDashboard(
                  key: ValueKey(child.uid),
                  student: child,
                  greeting: 'متابعة ${child.name}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── لوحة الطالب (مشتركة) ─────────────────────────

class StudentDashboard extends StatelessWidget {
  final AppUser student;
  final String greeting;

  const StudentDashboard({super.key, required this.student, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return AsyncBody<StudentData>(
      load: () => loadStudentData(student),
      builder: (context, data, reload) {
        final today = DateTime.now().weekday;
        final todayPeriods = data.timetable[today] ?? const <String>[];
        final upcoming = data.upcomingHomework;
        final grades = data.myAssessments.take(4).toList();
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeaderCard(
                title: greeting,
                subtitle: data.cls == null ? 'لم يُحدد الفصل بعد' : data.cls!.label,
                icon: Icons.backpack,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'نسبة الحضور',
                      value: pct(data.attendanceRate),
                      icon: Icons.event_available,
                      color: pctColor(data.attendanceRate),
                      onTap: () => _open(context, AttendanceHistoryScreen(data: data)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'المعدل',
                      value: pct(data.overallAverage),
                      icon: Icons.trending_up,
                      color: pctColor(data.overallAverage),
                      onTap: () => _open(context, GradesScreen(data: data)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'واجبات قادمة',
                      value: '${upcoming.length}',
                      icon: Icons.assignment,
                      color: kAccent,
                      onTap: () => _open(context, HomeworkListScreen(data: data)),
                    ),
                  ),
                ],
              ),
              SectionTitle('حصص اليوم (${weekdayName(today)})',
                  trailing: TextButton(
                    onPressed: () => _open(context, TimetableScreen(data: data)),
                    child: const Text('الجدول كاملاً'),
                  )),
              if (todayPeriods.where((p) => p.isNotEmpty).isEmpty)
                const Card(child: ListTile(leading: Icon(Icons.weekend), title: Text('لا توجد حصص اليوم')))
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < todayPeriods.length; i++)
                        if (todayPeriods[i].isNotEmpty)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: kPrimary.withValues(alpha: 0.12),
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: kPrimary)),
                            ),
                            title: Text(todayPeriods[i]),
                          ),
                    ],
                  ),
                ),
              SectionTitle('الواجبات القادمة',
                  trailing: TextButton(
                    onPressed: () => _open(context, HomeworkListScreen(data: data)),
                    child: const Text('عرض الكل'),
                  )),
              if (upcoming.isEmpty)
                const Card(
                    child: ListTile(leading: Icon(Icons.celebration), title: Text('لا توجد واجبات قادمة')))
              else
                for (final h in upcoming.take(3)) ...[HomeworkCard(h: h), const SizedBox(height: 8)],
              SectionTitle('آخر الدرجات',
                  trailing: TextButton(
                    onPressed: () => _open(context, GradesScreen(data: data)),
                    child: const Text('كشف الدرجات'),
                  )),
              if (grades.isEmpty)
                const Card(child: ListTile(leading: Icon(Icons.grade_outlined), title: Text('لا توجد درجات بعد')))
              else
                Card(
                  child: Column(
                    children: [
                      for (final a in grades)
                        ListTile(
                          title: Text('${a.subjectName} – ${a.title}'),
                          subtitle: Text(prettyDay(a.date)),
                          trailing: StatusChip(
                            '${_fmt(a.scores[student.uid] ?? 0)} / ${_fmt(a.maxScore)}',
                            color: pctColor(a.percentOf(student.uid)),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              ActionGrid(
                columns: 4,
                children: [
                  ActionTile(
                    label: 'الحضور',
                    icon: Icons.fact_check,
                    onTap: () => _open(context, AttendanceHistoryScreen(data: data)),
                  ),
                  ActionTile(
                    label: 'الدرجات',
                    icon: Icons.grade,
                    color: kInfo,
                    onTap: () => _open(context, GradesScreen(data: data)),
                  ),
                  ActionTile(
                    label: 'الواجبات',
                    icon: Icons.assignment,
                    color: kAccent,
                    onTap: () => _open(context, HomeworkListScreen(data: data)),
                  ),
                  ActionTile(
                    label: 'الجدول',
                    icon: Icons.calendar_view_week,
                    color: Colors.purple,
                    onTap: () => _open(context, TimetableScreen(data: data)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ───────────────────────── بطاقة الواجب ─────────────────────────

class HomeworkCard extends StatelessWidget {
  final Homework h;
  final VoidCallback? onDelete;

  const HomeworkCard({super.key, required this.h, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final overdue = h.dueDate.compareTo(todayKey) < 0;
    final isToday = h.dueDate == todayKey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(h.subjectName, color: kPrimary),
                      if (h.className.isNotEmpty) StatusChip(h.className, color: Colors.blueGrey),
                      StatusChip(
                        isToday ? 'التسليم اليوم' : 'التسليم ${prettyDay(h.dueDate)}',
                        color: overdue ? Colors.grey : (isToday ? kDanger : kAccent),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(h.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
            if (h.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(h.details, style: const TextStyle(color: Colors.black87, height: 1.5)),
            ],
            const SizedBox(height: 6),
            Text('أ. ${h.teacherName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── الشاشات التفصيلية ─────────────────────────

class AttendanceHistoryScreen extends StatelessWidget {
  final StudentData data;

  const AttendanceHistoryScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.myDays;
    return Scaffold(
      appBar: AppBar(title: Text('حضور ${data.student.name.split(' ').first}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              for (final s in [Att.present, Att.absent, Att.late, Att.excused]) ...[
                Expanded(
                  child: StatTile(
                    label: Att.label(s),
                    value: '${data.countStatus(s)}',
                    icon: attIcon(s),
                    color: attColor(s),
                  ),
                ),
                if (s != Att.excused) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.percent),
              title: const Text('نسبة الحضور'),
              trailing: Text(pct(data.attendanceRate),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: pctColor(data.attendanceRate))),
            ),
          ),
          const SectionTitle('سجل الأيام'),
          if (days.isEmpty)
            const EmptyView(icon: Icons.event_busy, text: 'لم يُسجَّل حضور بعد')
          else
            Card(
              child: Column(
                children: [
                  for (final d in days)
                    ListTile(
                      dense: true,
                      leading: Icon(attIcon(d.value), color: attColor(d.value)),
                      title: Text(prettyDay(d.key)),
                      trailing: StatusChip(Att.label(d.value), color: attColor(d.value)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class GradesScreen extends StatefulWidget {
  final StudentData data;

  const GradesScreen({super.key, required this.data});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  late int _term = Session.settings.term;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final list = data.myAssessments.where((a) => a.term == _term).toList();
    final bySubject = <String, List<Assessment>>{};
    for (final a in list) {
      bySubject.putIfAbsent(a.subjectName, () => []).add(a);
    }
    final subjects = bySubject.keys.toList()..sort();
    final overall = data.averageOf(list);
    return Scaffold(
      appBar: AppBar(title: const Text('كشف الدرجات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('الترم الأول')),
              ButtonSegment(value: 2, label: Text('الترم الثاني')),
            ],
            selected: {_term},
            onSelectionChanged: (s) => setState(() => _term = s.first),
          ),
          const SizedBox(height: 12),
          HeaderCard(
            title: data.student.name,
            subtitle: 'المعدل العام: ${pct(overall)}',
            icon: Icons.workspace_premium,
          ),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            const EmptyView(icon: Icons.grade_outlined, text: 'لا توجد درجات في هذا الترم')
          else
            for (final s in subjects) ...[
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${bySubject[s]!.length} تقييم'),
                  trailing: StatusChip(pct(data.averageOf(bySubject[s]!)),
                      color: pctColor(data.averageOf(bySubject[s]!))),
                  children: [
                    for (final a in bySubject[s]!)
                      ListTile(
                        dense: true,
                        title: Text(a.title),
                        subtitle: Text('${prettyDay(a.date)} · متوسط الفصل ${pct(a.classAverage)}'),
                        trailing: Text(
                          '${_fmt(a.scores[data.student.uid] ?? 0)} / ${_fmt(a.maxScore)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: pctColor(a.percentOf(data.student.uid))),
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class HomeworkListScreen extends StatelessWidget {
  final StudentData data;

  const HomeworkListScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final upcoming = data.upcomingHomework;
    final past = data.homework.where((h) => h.dueDate.compareTo(todayKey) < 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('الواجبات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('القادمة'),
          if (upcoming.isEmpty)
            const Card(child: ListTile(leading: Icon(Icons.celebration), title: Text('لا توجد واجبات قادمة')))
          else
            for (final h in upcoming) ...[HomeworkCard(h: h), const SizedBox(height: 8)],
          if (past.isNotEmpty) ...[
            const SectionTitle('السابقة'),
            for (final h in past.take(30)) ...[HomeworkCard(h: h), const SizedBox(height: 8)],
          ],
        ],
      ),
    );
  }
}

class TimetableScreen extends StatelessWidget {
  final StudentData data;

  const TimetableScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جدول ${data.cls?.name ?? ''}')),
      body: TimetableView(timetable: data.timetable),
    );
  }
}

/// عرض الجدول الأسبوعي (يُستخدم للطالب وولي الأمر والمعلم)
class TimetableView extends StatelessWidget {
  final Map<int, List<String>> timetable;

  const TimetableView({super.key, required this.timetable});

  @override
  Widget build(BuildContext context) {
    final days = Session.settings.days;
    final today = DateTime.now().weekday;
    if (timetable.values.every((v) => v.every((p) => p.isEmpty))) {
      return const EmptyView(icon: Icons.calendar_view_week, text: 'لم تُدخل الإدارة الجدول بعد');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final d in days) ...[
          Card(
            color: d == today ? const Color(0xFFE6F6F4) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weekdayName(d) + (d == today ? ' (اليوم)' : ''),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < (timetable[d] ?? const <String>[]).length; i++)
                        if (timetable[d]![i].isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: CircleAvatar(
                              backgroundColor: kPrimary,
                              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                            label: Text(timetable[d]![i]),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
