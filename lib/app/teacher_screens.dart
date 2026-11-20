import 'package:flutter/material.dart';

import 'common_screens.dart';
import 'db.dart';
import 'family_screens.dart';
import 'school_models.dart';
import 'ui.dart';

// ───────────────────────── الصفحة الرئيسية للمعلم ─────────────────────────

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.user;
    final byClass = <String, List<Assignment>>{};
    for (final a in me.assignments) {
      byClass.putIfAbsent(a.classId, () => []).add(a);
    }
    return Scaffold(
      appBar: AppBar(title: Text(Session.settings.name), actions: const [NotificationBell()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeaderCard(
            title: 'أهلاً أ. ${me.name.split(' ').first} 👋',
            subtitle: '${byClass.length} فصول · ${me.assignments.length} مواد',
            icon: Icons.co_present,
          ),
          const SizedBox(height: 12),
          ActionGrid(
            children: [
              ActionTile(
                label: 'واجباتي',
                icon: Icons.assignment,
                color: kAccent,
                onTap: () => _push(context, const MyHomeworkScreen()),
              ),
              ActionTile(
                label: 'شروحاتي',
                icon: Icons.ondemand_video,
                color: Colors.red,
                onTap: () => _push(context, const MyLessonsScreen()),
              ),
              ActionTile(
                label: 'إعلان لفصل',
                icon: Icons.campaign,
                color: kInfo,
                onTap: () => _push(context, const ComposeAnnouncementScreen()),
              ),
            ],
          ),
          const SectionTitle('فصولي'),
          if (byClass.isEmpty)
            const EmptyView(icon: Icons.class_outlined, text: 'لم تُسند لك فصول بعد.\nتواصل مع إدارة المدرسة.')
          else
            for (final entry in byClass.entries) ...[
              _ClassCard(assignments: entry.value),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

class _ClassCard extends StatelessWidget {
  final List<Assignment> assignments;

  const _ClassCard({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final first = assignments.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.class_, color: kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(first.className,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                FilledButton.icon(
                  onPressed: () => _push(
                    context,
                    AttendanceScreen(classId: first.classId, className: first.className),
                  ),
                  icon: const Icon(Icons.fact_check, size: 18),
                  label: const Text('تحضير'),
                ),
              ],
            ),
            const Divider(height: 22),
            for (final a in assignments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(a.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    _SmallAction(
                      icon: Icons.grade,
                      label: 'درجات',
                      color: kInfo,
                      onTap: () => _push(context, AssessmentsScreen(assignment: a)),
                    ),
                    _SmallAction(
                      icon: Icons.assignment_add,
                      label: 'واجب',
                      color: kAccent,
                      onTap: () => _push(context, ClassHomeworkScreen(assignment: a)),
                    ),
                    _SmallAction(
                      icon: Icons.video_call,
                      label: 'شرح',
                      color: Colors.red,
                      onTap: () => _push(context, SubjectLessonsScreen(assignment: a)),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _push(context, ClassTimetableScreen(classId: first.classId, title: first.className)),
                icon: const Icon(Icons.calendar_view_week, size: 18),
                label: const Text('جدول الفصل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class ClassTimetableScreen extends StatelessWidget {
  final String classId;
  final String title;

  const ClassTimetableScreen({super.key, required this.classId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جدول $title')),
      body: AsyncBody<Map<int, List<String>>>(
        load: () => Db.timetable(classId),
        builder: (context, t, reload) => TimetableView(timetable: t),
      ),
    );
  }
}

// ───────────────────────── التحضير ─────────────────────────

class AttendanceScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AttendanceScreen({super.key, required this.classId, required this.className});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _date = DateTime.now();
  List<AppUser>? _students;
  Map<String, String> _records = {};
  Map<String, String> _saved = {};
  bool _exists = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = _students ?? await Db.studentsOfClass(widget.classId);
      final day = await Db.attendance(widget.classId, dayKey(_date));
      final records = <String, String>{};
      for (final s in students) {
        records[s.uid] = day?.records[s.uid] ?? Att.present;
      }
      setState(() {
        _students = students;
        _records = records;
        _saved = Map.of(day?.records ?? {});
        _exists = day != null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      _date = d;
      _load();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final me = Session.user;
      final date = dayKey(_date);
      await Db.saveAttendance(AttendanceDay(
        classId: widget.classId,
        date: date,
        records: _records,
        takenBy: me.name,
      ));
      // إشعار أولياء الأمور بالغياب والتأخير الجديد فقط
      final students = _students ?? [];
      final changed = students.where((s) {
        final now = _records[s.uid];
        return (now == Att.absent || now == Att.late) && _saved[s.uid] != now;
      }).toList();
      for (final s in changed) {
        if (s.parentUid.isEmpty) continue;
        final status = _records[s.uid] == Att.absent ? 'غائب' : 'متأخر';
        await Db.notify(
          s.parentUid,
          'تنبيه حضور: ${s.name}',
          'ابنكم ${s.name} $status يوم ${prettyDay(date)} (${widget.className}).',
        );
      }
      _saved = Map.of(_records);
      _exists = true;
      if (!mounted) return;
      showSnack(context, 'تم حفظ التحضير');
      final absentees = students.where((s) => _records[s.uid] == Att.absent).toList();
      if (absentees.isNotEmpty) _showAbsentees(absentees, date);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAbsentees(List<AppUser> absentees, String date) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('الغائبون (${absentees.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('وصل إشعار لأولياء الأمور في التطبيق. يمكنك أيضاً مراسلتهم بالواتساب:',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            for (final s in absentees)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(s.name, size: 34, color: kDanger),
                title: Text(s.name),
                trailing: IconButton(
                  icon: const Icon(Icons.chat, color: kSuccess),
                  onPressed: () async {
                    if (s.parentUid.isEmpty) {
                      showSnack(context, 'لا يوجد ولي أمر مربوط بهذا الطالب', error: true);
                      return;
                    }
                    final parent = await Db.user(s.parentUid);
                    if (!context.mounted) return;
                    await openWhatsApp(
                      context,
                      parent?.phone ?? '',
                      'السلام عليكم، نحيطكم علماً بأن ابنكم ${s.name} غائب اليوم ${prettyDay(date)}. '
                      '${Session.settings.name}',
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = _students ?? [];
    final counts = <String, int>{};
    for (final v in _records.values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: Text('تحضير ${widget.className}')),
      bottomNavigationBar: students.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.save),
                  label: Text(_exists ? 'تحديث التحضير' : 'حفظ التحضير'),
                ),
              ),
            ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : students.isEmpty
                  ? const EmptyView(icon: Icons.groups, text: 'لا يوجد طلاب في هذا الفصل بعد')
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.event, color: kPrimary),
                            title: Text(prettyDay(dayKey(_date))),
                            subtitle: Text(_exists ? 'تم التحضير مسبقاً، يمكنك التعديل' : 'لم يُحضَّر بعد'),
                            trailing: TextButton(onPressed: _pickDate, child: const Text('تغيير اليوم')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in [Att.present, Att.absent, Att.late, Att.excused])
                              StatusChip('${Att.label(s)}: ${counts[s] ?? 0}', color: attColor(s)),
                            ActionChip(
                              avatar: const Icon(Icons.done_all, size: 18),
                              label: const Text('الكل حاضر'),
                              onPressed: () => setState(() {
                                for (final k in _records.keys.toList()) {
                                  _records[k] = Att.present;
                                }
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < students.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 26,
                                    child: Text('${i + 1}', style: const TextStyle(color: Colors.black45)),
                                  ),
                                  Expanded(
                                    child: Text(students[i].name,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  for (final s in [Att.present, Att.absent, Att.late, Att.excused])
                                    _StatusDot(
                                      status: s,
                                      selected: _records[students[i].uid] == s,
                                      onTap: () => setState(() => _records[students[i].uid] = s),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 70),
                      ],
                    ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusDot({required this.status, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = attColor(status);
    return Tooltip(
      message: Att.label(status),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? c : c.withValues(alpha: 0.08),
          ),
          child: Icon(attIcon(status), size: 20, color: selected ? Colors.white : c),
        ),
      ),
    );
  }
}

// ───────────────────────── الدرجات ─────────────────────────

class AssessmentsScreen extends StatefulWidget {
  final Assignment assignment;

  const AssessmentsScreen({super.key, required this.assignment});

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  Key _key = UniqueKey();

  Future<List<Assessment>> _load() async {
    final all = await Db.assessmentsOfClass(widget.assignment.classId);
    return all.where((a) => a.subjectId == widget.assignment.subjectId).toList();
  }

  Future<void> _openEditor([Assessment? a]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssessmentEditor(assignment: widget.assignment, existing: a)),
    );
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(title: Text('درجات ${a.subjectName} – ${a.className}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('تقييم جديد'),
      ),
      body: AsyncBody<List<Assessment>>(
        key: _key,
        load: _load,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return const EmptyView(
                icon: Icons.grade_outlined, text: 'لا توجد تقييمات بعد.\nاضغط «تقييم جديد» لإضافة اختبار أو مشاركة.');
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final x = list[i];
                return Card(
                  child: ListTile(
                    title: Text(x.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${x.term == 2 ? 'الترم الثاني' : 'الترم الأول'} · ${prettyDay(x.date)} · من ${_fmt(x.maxScore)}'),
                    trailing: StatusChip('متوسط ${pct(x.classAverage)}', color: pctColor(x.classAverage)),
                    onTap: () => _openEditor(x),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class AssessmentEditor extends StatefulWidget {
  final Assignment assignment;
  final Assessment? existing;

  const AssessmentEditor({super.key, required this.assignment, this.existing});

  @override
  State<AssessmentEditor> createState() => _AssessmentEditorState();
}

class _AssessmentEditorState extends State<AssessmentEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _max =
      TextEditingController(text: widget.existing == null ? '20' : _fmt(widget.existing!.maxScore));
  late int _term = widget.existing?.term ?? Session.settings.term;
  late DateTime _date = parseDay(widget.existing?.date ?? '') ?? DateTime.now();
  final Map<String, TextEditingController> _scores = {};
  List<AppUser>? _students;
  bool _notify = true;

  @override
  void initState() {
    super.initState();
    Db.studentsOfClass(widget.assignment.classId).then((list) {
      if (!mounted) return;
      setState(() {
        _students = list;
        for (final s in list) {
          final v = widget.existing?.scores[s.uid];
          _scores[s.uid] = TextEditingController(text: v == null ? '' : _fmt(v));
        }
      });
    }).catchError((Object e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    });
  }

  @override
  void dispose() {
    for (final c in _scores.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) throw Exception('اكتب اسم التقييم مثل: اختبار شهري 1');
    final max = double.tryParse(_max.text.trim());
    if (max == null || max <= 0) throw Exception('الدرجة العظمى غير صحيحة');
    final scores = <String, double>{};
    for (final e in _scores.entries) {
      final t = e.value.text.trim();
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v == null || v < 0 || v > max) throw Exception('درجة غير صحيحة: "$t" (يجب أن تكون من 0 إلى ${_fmt(max)})');
      scores[e.key] = v;
    }
    final me = Session.user;
    final a = widget.assignment;
    await Db.saveAssessment(Assessment(
      id: widget.existing?.id ?? '',
      classId: a.classId,
      subjectId: a.subjectId,
      subjectName: a.subjectName,
      term: _term,
      title: _title.text.trim(),
      maxScore: max,
      date: dayKey(_date),
      teacherUid: widget.existing?.teacherUid ?? me.uid,
      teacherName: widget.existing?.teacherName ?? me.name,
      scores: scores,
    ));
    if (_notify && widget.existing == null) {
      for (final s in _students ?? <AppUser>[]) {
        final v = scores[s.uid];
        if (v == null || s.parentUid.isEmpty) continue;
        await Db.notify(s.parentUid, 'درجة جديدة: ${s.name}',
            '${a.subjectName} – ${_title.text.trim()}: ${_fmt(v)} من ${_fmt(max)}');
      }
    }
    if (mounted) {
      showSnack(context, 'تم حفظ الدرجات');
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'حذف التقييم', 'سيتم حذف التقييم وكل درجاته. هل أنت متأكد؟',
        ok: 'حذف', danger: true);
    if (!ok) return;
    await Db.deleteAssessment(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'تقييم جديد' : 'تعديل التقييم'),
        actions: [
          if (widget.existing != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BusyButton(label: 'حفظ الدرجات', icon: Icons.save, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'اسم التقييم (مثال: اختبار شهري 1)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الدرجة العظمى'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _term,
                  decoration: const InputDecoration(labelText: 'الترم'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('الأول')),
                    DropdownMenuItem(value: 2, child: Text('الثاني')),
                  ],
                  onChanged: (v) => setState(() => _term = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('التاريخ: ${prettyDay(dayKey(_date))}'),
            trailing: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) setState(() => _date = d);
              },
              child: const Text('تغيير'),
            ),
          ),
          if (widget.existing == null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: const Text('إرسال الدرجة لأولياء الأمور'),
            ),
          const SectionTitle('درجات الطلاب'),
          if (students == null)
            const Padding(padding: EdgeInsets.all(24), child: LoadingView())
          else if (students.isEmpty)
            const EmptyView(icon: Icons.groups, text: 'لا يوجد طلاب في هذا الفصل')
          else
            for (var i = 0; i < students.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(color: Colors.black45))),
                    Expanded(child: Text(students[i].name)),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _scores[students[i].uid],
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '—', isDense: true),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ───────────────────────── الواجبات ─────────────────────────

class ClassHomeworkScreen extends StatefulWidget {
  final Assignment assignment;

  const ClassHomeworkScreen({super.key, required this.assignment});

  @override
  State<ClassHomeworkScreen> createState() => _ClassHomeworkScreenState();
}

class _ClassHomeworkScreenState extends State<ClassHomeworkScreen> {
  Key _key = UniqueKey();

  Future<List<Homework>> _load() async {
    final all = await Db.homeworkOfClass(widget.assignment.classId);
    return all.where((h) => h.subjectName == widget.assignment.subjectName).toList();
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewHomeworkScreen(assignment: widget.assignment)),
    );
    if (added == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(title: Text('واجبات ${a.subjectName} – ${a.className}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('واجب جديد'),
      ),
      body: AsyncBody<List<Homework>>(
        key: _key,
        load: _load,
        builder: (context, list, reload) {
          if (list.isEmpty) return const EmptyView(icon: Icons.assignment_outlined, text: 'لا توجد واجبات بعد');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => HomeworkCard(
                h: list[i],
                onDelete: () async {
                  final ok = await confirmDialog(context, 'حذف الواجب', 'هل تريد حذف هذا الواجب؟',
                      ok: 'حذف', danger: true);
                  if (!ok) return;
                  await Db.deleteHomework(list[i].id);
                  setState(() => _key = UniqueKey());
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewHomeworkScreen extends StatefulWidget {
  final Assignment assignment;

  const NewHomeworkScreen({super.key, required this.assignment});

  @override
  State<NewHomeworkScreen> createState() => _NewHomeworkScreenState();
}

class _NewHomeworkScreenState extends State<NewHomeworkScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 1));

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) throw Exception('اكتب عنوان الواجب');
    final me = Session.user;
    final a = widget.assignment;
    await Db.addHomework(Homework(
      id: '',
      classId: a.classId,
      className: a.className,
      subjectName: a.subjectName,
      title: _title.text.trim(),
      details: _details.text.trim(),
      dueDate: dayKey(_due),
      teacherUid: me.uid,
      teacherName: me.name,
    ));
    if (mounted) {
      showSnack(context, 'تم نشر الواجب');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('واجب جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.class_, color: kPrimary),
              title: Text(widget.assignment.subjectName),
              subtitle: Text(widget.assignment.className),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'عنوان الواجب (مثال: حل تمارين صفحة 25)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'التفاصيل (اختياري)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('موعد التسليم: ${prettyDay(dayKey(_due))}'),
            trailing: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 120)),
                );
                if (d != null) setState(() => _due = d);
              },
              child: const Text('تغيير'),
            ),
          ),
          const SizedBox(height: 20),
          BusyButton(label: 'نشر الواجب', icon: Icons.send, onPressed: _save),
        ],
      ),
    );
  }
}

class MyHomeworkScreen extends StatefulWidget {
  const MyHomeworkScreen({super.key});

  @override
  State<MyHomeworkScreen> createState() => _MyHomeworkScreenState();
}

class _MyHomeworkScreenState extends State<MyHomeworkScreen> {
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('واجباتي')),
      body: AsyncBody<List<Homework>>(
        key: _key,
        load: () => Db.homeworkByTeacher(Session.user.uid),
        builder: (context, list, reload) {
          if (list.isEmpty) return const EmptyView(icon: Icons.assignment_outlined, text: 'لم تنشر واجبات بعد');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => HomeworkCard(
              h: list[i],
              onDelete: () async {
                final ok =
                    await confirmDialog(context, 'حذف الواجب', 'هل تريد حذف هذا الواجب؟', ok: 'حذف', danger: true);
                if (!ok) return;
                await Db.deleteHomework(list[i].id);
                setState(() => _key = UniqueKey());
              },
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── الشروحات ─────────────────────────

class SubjectLessonsScreen extends StatefulWidget {
  final Assignment assignment;

  const SubjectLessonsScreen({super.key, required this.assignment});

  @override
  State<SubjectLessonsScreen> createState() => _SubjectLessonsScreenState();
}

class _SubjectLessonsScreenState extends State<SubjectLessonsScreen> {
  Key _key = UniqueKey();

  Future<void> _add() async {
    final title = TextEditingController();
    final url = TextEditingController();
    var term = Session.settings.term;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('إضافة شرح'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الدرس')),
                const SizedBox(height: 10),
                TextField(
                  controller: url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رابط يوتيوب أو أي رابط'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: term,
                  decoration: const InputDecoration(labelText: 'الترم'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('الأول')),
                    DropdownMenuItem(value: 2, child: Text('الثاني')),
                  ],
                  onChanged: (v) => setD(() => term = v ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            BusyButton(
              label: 'إضافة',
              onPressed: () async {
                if (title.text.trim().isEmpty || !url.text.trim().startsWith('http')) {
                  throw Exception('اكتب العنوان ورابطاً صحيحاً يبدأ بـ http');
                }
                final me = Session.user;
                await Db.addLesson(OnlineLesson(
                  id: '',
                  subjectId: widget.assignment.subjectId,
                  term: term,
                  title: title.text.trim(),
                  url: url.text.trim(),
                  teacherUid: me.uid,
                  teacherName: me.name,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(title: Text('شروحات ${a.subjectName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('إضافة شرح'),
      ),
      body: AsyncBody<List<OnlineLesson>>(
        key: _key,
        load: () => Db.lessonsOfSubject(a.subjectId),
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.ondemand_video,
              text: 'أضف روابط شروحات يوتيوب لهذه المادة.\nستظهر لكل طلاب الصف في المكتبة.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final l = list[i];
              final mine = l.teacherUid == Session.user.uid || Roles.isManager(Session.user.role);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 34),
                  title: Text(l.title),
                  subtitle: Text('${l.term == 2 ? 'الترم الثاني' : 'الترم الأول'} · أ. ${l.teacherName}'),
                  onTap: () => openLink(context, l.url),
                  trailing: mine
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await Db.deleteLesson(l.id);
                            setState(() => _key = UniqueKey());
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MyLessonsScreen extends StatelessWidget {
  const MyLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شروحاتي')),
      body: AsyncBody<List<OnlineLesson>>(
        load: () => Db.lessonsByTeacher(Session.user.uid),
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.ondemand_video,
              text: 'لم تضف شروحات بعد.\nمن «فصولي» اضغط «شرح» بجانب المادة.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 34),
                title: Text(list[i].title),
                onTap: () => openLink(context, list[i].url),
              ),
            ),
          );
        },
      ),
    );
  }
}
