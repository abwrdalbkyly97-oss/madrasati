import 'package:flutter/material.dart';

import '../models.dart';
import 'common_screens.dart';
import 'db.dart';
import 'principal_screens.dart';
import 'school_models.dart';
import 'ui.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

/// مواد صف معيّن من فهرس المكتبة
Future<List<Subject>> subjectsForClass(SchoolClass c) async {
  final catalog = await CatalogStore.get();
  for (final stage in catalog.stages) {
    for (final g in stage.grades) {
      if (g.order == c.grade) return g.subjectsFor(c.track);
    }
  }
  return [];
}

String gradeName(int g) {
  const names = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'الأول الثانوي',
    'الثاني الثانوي',
    'الثالث الثانوي',
  ];
  return (g >= 1 && g <= 12) ? names[g - 1] : '$g';
}

String credentialsMessage(AppUser u, String password) {
  return 'السلام عليكم ${u.name}\n'
      'بيانات دخولك إلى تطبيق ${Session.settings.name}:\n'
      'اسم المستخدم: ${u.username}\n'
      'كلمة المرور: $password';
}

// ───────────────────────── لوحة الإدارة ─────────────────────────

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isOwner = Session.user.role == Roles.owner;
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
                title: 'لوحة الإدارة',
                subtitle: '${Roles.label(Session.user.role)} · ${prettyDay(todayKey)}',
                icon: Icons.admin_panel_settings,
              ),
              const SizedBox(height: 12),
              TodayStats(summary: s),
              if (s.classes.isEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFFF7E6),
                  child: ListTile(
                    leading: const Icon(Icons.tips_and_updates, color: kAccent),
                    title: const Text('ابدأ من هنا'),
                    subtitle: const Text('1) أضف الفصول  2) أضف المعلمين  3) أضف الطلاب وأولياء الأمور  4) أدخل الجدول'),
                    onTap: () => _push(context, const ClassesScreen()),
                  ),
                ),
              ],
              const SectionTitle('إدارة المدرسة'),
              ActionGrid(
                children: [
                  ActionTile(
                      label: 'الفصول',
                      icon: Icons.class_,
                      onTap: () => _push(context, const ClassesScreen())),
                  ActionTile(
                      label: 'الطلاب',
                      icon: Icons.groups,
                      color: kInfo,
                      onTap: () => _push(context, const UsersScreen(role: Roles.student))),
                  ActionTile(
                      label: 'أولياء الأمور',
                      icon: Icons.family_restroom,
                      color: Colors.teal,
                      onTap: () => _push(context, const UsersScreen(role: Roles.parent))),
                  ActionTile(
                      label: 'المعلمون',
                      icon: Icons.co_present,
                      color: Colors.purple,
                      onTap: () => _push(context, const UsersScreen(role: Roles.teacher))),
                  ActionTile(
                      label: 'الجدول الدراسي',
                      icon: Icons.calendar_view_week,
                      color: kAccent,
                      onTap: () => _push(context, const TimetableClassesScreen())),
                  ActionTile(
                      label: 'بيانات الدخول',
                      icon: Icons.key,
                      color: Colors.brown,
                      onTap: () => _push(context, const CredentialsScreen())),
                  ActionTile(
                      label: 'تقارير الفصول',
                      icon: Icons.analytics,
                      color: Colors.indigo,
                      onTap: () => _push(context, const ClassReportsScreen())),
                  ActionTile(
                      label: 'بحث عن طالب',
                      icon: Icons.person_search,
                      color: Colors.cyan.shade700,
                      onTap: () => _push(context, StudentSearchScreen(students: s.students.values.toList()))),
                  ActionTile(
                      label: 'إعلان',
                      icon: Icons.campaign,
                      color: Colors.orange,
                      onTap: () => _push(context, const ComposeAnnouncementScreen())),
                ],
              ),
              const SectionTitle('النظام'),
              ActionGrid(
                children: [
                  ActionTile(
                      label: 'إعدادات المدرسة',
                      icon: Icons.settings,
                      color: Colors.blueGrey,
                      onTap: () => _push(context, const SettingsScreen())),
                  if (isOwner)
                    ActionTile(
                        label: 'المدير',
                        icon: Icons.workspace_premium,
                        color: Colors.deepOrange,
                        onTap: () => _push(context, const UsersScreen(role: Roles.principal))),
                  if (isOwner)
                    ActionTile(
                        label: 'موظفو الإدارة',
                        icon: Icons.badge,
                        color: Colors.pink,
                        onTap: () => _push(context, const UsersScreen(role: Roles.admin))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── الفصول ─────────────────────────

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  Key _key = UniqueKey();

  Future<void> _edit([SchoolClass? c]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _ClassDialog(existing: c));
    if (saved == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفصول')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('فصل جديد'),
      ),
      body: AsyncBody<List<SchoolClass>>(
        key: _key,
        load: Db.classes,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.class_outlined,
              text: 'لا توجد فصول.\nأضف فصلاً لكل شعبة، مثل: الخامس أ (بنين)، الخامس أ (بنات).',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (c.section == Sections.girls ? Colors.pink : kInfo).withValues(alpha: 0.12),
                    child: Text('${c.grade}',
                        style: TextStyle(color: c.section == Sections.girls ? Colors.pink : kInfo)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    Sections.label(c.section),
                    if (c.track == 'sci') 'علمي',
                    if (c.track == 'lit') 'أدبي',
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') _edit(c);
                      if (v == 'students') _push(context, UsersScreen(role: Roles.student, classFilter: c.id));
                      if (v == 'timetable') _push(context, TimetableEditorScreen(cls: c));
                      if (v == 'delete') {
                        final students = await Db.studentsOfClass(c.id);
                        if (!context.mounted) return;
                        if (students.isNotEmpty) {
                          showSnack(context, 'لا يمكن الحذف: في الفصل ${students.length} طالب. انقلهم أولاً.',
                              error: true);
                          return;
                        }
                        final ok = await confirmDialog(context, 'حذف الفصل', 'هل تريد حذف ${c.name}؟',
                            ok: 'حذف', danger: true);
                        if (ok) {
                          await Db.deleteClass(c.id);
                          setState(() => _key = UniqueKey());
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'students', child: Text('طلاب الفصل')),
                      PopupMenuItem(value: 'timetable', child: Text('الجدول')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                  onTap: () => _push(context, UsersScreen(role: Roles.student, classFilter: c.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ClassDialog extends StatefulWidget {
  final SchoolClass? existing;

  const _ClassDialog({this.existing});

  @override
  State<_ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends State<_ClassDialog> {
  late int _grade = widget.existing?.grade ?? 1;
  late String _section = widget.existing?.section ?? Sections.boys;
  late String _track = widget.existing?.track ?? '';
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '${gradeName(1)} أ');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'فصل جديد' : 'تعديل الفصل'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _grade,
              decoration: const InputDecoration(labelText: 'الصف'),
              items: [
                for (var g = 1; g <= 12; g++) DropdownMenuItem(value: g, child: Text('الصف ${gradeName(g)}')),
              ],
              onChanged: (v) => setState(() {
                _grade = v ?? 1;
                if (widget.existing == null) _name.text = '${gradeName(_grade)} أ';
                if (_grade < 11) _track = '';
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الفصل (مثال: الخامس أ)'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: Sections.boys, label: Text('بنين')),
                ButtonSegment(value: Sections.girls, label: Text('بنات')),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
            if (_grade >= 11) ...[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sci', label: Text('علمي')),
                  ButtonSegment(value: 'lit', label: Text('أدبي')),
                ],
                emptySelectionAllowed: true,
                selected: _track.isEmpty ? <String>{} : {_track},
                onSelectionChanged: (s) => setState(() => _track = s.isEmpty ? '' : s.first),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        BusyButton(
          label: 'حفظ',
          onPressed: () async {
            if (_name.text.trim().isEmpty) throw Exception('اكتب اسم الفصل');
            await Db.saveClass(SchoolClass(
              id: widget.existing?.id ?? '',
              name: _name.text.trim(),
              grade: _grade,
              section: _section,
              track: _grade >= 11 ? _track : '',
            ));
            if (context.mounted) Navigator.pop(context, true);
          },
        ),
      ],
    );
  }
}

// ───────────────────────── قائمة المستخدمين ─────────────────────────

class UsersScreen extends StatefulWidget {
  final String role;
  final String? classFilter;

  const UsersScreen({super.key, required this.role, this.classFilter});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  Key _key = UniqueKey();
  String _q = '';
  late String? _classFilter = widget.classFilter;
  List<SchoolClass> _classes = [];

  String get _title => switch (widget.role) {
        'student' => 'الطلاب',
        'parent' => 'أولياء الأمور',
        'teacher' => 'المعلمون',
        'principal' => 'المدير',
        'admin' => 'موظفو الإدارة',
        _ => 'المستخدمون',
      };

  Future<List<AppUser>> _load() async {
    _classes = await Db.classes();
    if (widget.role == Roles.student && _classFilter != null) return Db.studentsOfClass(_classFilter!);
    return Db.usersByRole(widget.role);
  }

  void _refresh() => setState(() => _key = UniqueKey());

  Future<void> _open([AppUser? u]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(role: widget.role, existing: u, defaultClassId: _classFilter),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (widget.role == Roles.student)
            IconButton(
              tooltip: 'إضافة مجموعة طلاب',
              icon: const Icon(Icons.playlist_add),
              onPressed: () async {
                await _push2(context, BulkStudentsScreen(defaultClassId: _classFilter));
                _refresh();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة'),
      ),
      body: AsyncBody<List<AppUser>>(
        key: _key,
        load: _load,
        builder: (context, all, reload) {
          final classNames = {for (final c in _classes) c.id: c.label};
          final list = all.where((u) => _q.isEmpty || u.name.contains(_q) || u.username.contains(_q)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم'),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              if (widget.role == Roles.student)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _classFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفصل', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('كل الطلاب')),
                      for (final c in _classes) DropdownMenuItem<String?>(value: c.id, child: Text(c.label)),
                    ],
                    onChanged: (v) {
                      _classFilter = v;
                      _refresh();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('العدد: ${list.length}', style: const TextStyle(color: Colors.black54)),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyView(icon: Icons.person_off_outlined, text: 'لا يوجد أحد بعد')
                    : RefreshIndicator(
                        onRefresh: reload,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final u = list[i];
                            String sub = u.username;
                            if (u.role == Roles.student) sub = '${classNames[u.classId] ?? 'بدون فصل'} · ${u.username}';
                            if (u.role == Roles.parent) sub = '${u.childrenIds.length} أبناء · ${u.phone}';
                            if (u.role == Roles.teacher) sub = '${u.assignments.length} مواد · ${u.phone}';
                            return Card(
                              child: ListTile(
                                leading: Avatar(u.name),
                                title: Text(u.name),
                                subtitle: Text(sub),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => _open(u),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _push2(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

// ───────────────────────── نموذج المستخدم ─────────────────────────

class UserFormScreen extends StatefulWidget {
  final String role;
  final AppUser? existing;
  final String? defaultClassId;

  const UserFormScreen({super.key, required this.role, this.existing, this.defaultClassId});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _username =
      TextEditingController(text: widget.existing?.username ?? AuthService.suggestUsername(widget.role));
  final TextEditingController _password = TextEditingController(text: AuthService.suggestPassword());
  late final TextEditingController _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late String _section = widget.existing?.section ?? Sections.all;
  late String _classId = widget.existing?.classId ?? (widget.defaultClassId ?? '');
  late String _parentUid = widget.existing?.parentUid ?? '';
  late List<Assignment> _assignments = List.of(widget.existing?.assignments ?? const <Assignment>[]);

  List<SchoolClass> _classes = [];
  List<AppUser> _parents = [];
  bool _ready = false;

  bool get _isNew => widget.existing == null;
  bool get _isStudent => widget.role == Roles.student;
  bool get _isTeacher => widget.role == Roles.teacher;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final classes = await Db.classes();
      final parents = _isStudent ? await Db.usersByRole(Roles.parent) : <AppUser>[];
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _parents = parents;
        if (_classId.isNotEmpty && !classes.any((c) => c.id == _classId)) _classId = '';
        _ready = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _ready = true);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  SchoolClass? get _cls {
    for (final c in _classes) {
      if (c.id == _classId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) throw Exception('اكتب الاسم');
    if (_isStudent && _classId.isEmpty) throw Exception('اختر فصل الطالب');
    final section = _isStudent ? (_cls?.section ?? Sections.all) : _section;
    if (_isNew) {
      if (!AuthService.validUsername(_username.text)) {
        throw Exception('اسم المستخدم: حروف إنجليزية وأرقام فقط (3 أحرف على الأقل)');
      }
      if (_password.text.length < 6) throw Exception('كلمة المرور 6 أحرف على الأقل');
      final saved = await AuthService.createAccount(
        AppUser(
          uid: '',
          name: name,
          username: _username.text.trim(),
          role: widget.role,
          section: section,
          phone: _phone.text.trim(),
          classId: _isStudent ? _classId : '',
          parentUid: _isStudent ? _parentUid : '',
          assignments: _isTeacher ? _assignments : const [],
        ),
        _password.text,
      );
      if (_isStudent && _parentUid.isNotEmpty) await Db.refreshParentLinks(_parentUid);
      if (!mounted) return;
      await _showCreated(saved, _password.text);
    } else {
      final old = widget.existing!;
      final updated = old.copyWith(
        name: name,
        section: section,
        phone: _phone.text.trim(),
        classId: _isStudent ? _classId : old.classId,
        parentUid: _isStudent ? _parentUid : old.parentUid,
        assignments: _isTeacher ? _assignments : old.assignments,
      );
      await Db.saveUser(updated);
      if (_isStudent) {
        if (old.parentUid.isNotEmpty && old.parentUid != _parentUid) await Db.refreshParentLinks(old.parentUid);
        if (_parentUid.isNotEmpty) await Db.refreshParentLinks(_parentUid);
      }
      if (updated.uid == Session.user.uid) Session.me = updated;
      if (mounted) {
        showSnack(context, 'تم الحفظ');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showCreated(AppUser u, String password) async {
    final msg = credentialsMessage(u, password);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم إنشاء الحساب ✅'),
        content: SelectableText('${u.name}\nاسم المستخدم: ${u.username}\nكلمة المرور: $password'),
        actions: [
          TextButton(onPressed: () => copyText(ctx, msg), child: const Text('نسخ')),
          if (u.phone.isNotEmpty)
            TextButton(onPressed: () => openWhatsApp(ctx, u.phone, msg), child: const Text('إرسال واتساب')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resetPassword() async {
    final c = TextEditingController(text: AuthService.suggestPassword());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كلمة مرور جديدة'),
        content: TextField(
          controller: c,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          BusyButton(
            label: 'تغيير',
            onPressed: () async {
              if (c.text.length < 6) throw Exception('6 أحرف على الأقل');
              await AuthService.resetPassword(widget.existing!.uid, c.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await _showCreated(widget.existing!, c.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCredentials() async {
    final c = await AuthService.credentialsOf(widget.existing!.uid);
    if (!mounted) return;
    final u = widget.existing!;
    final msg = credentialsMessage(u, c['password'] ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات الدخول'),
        content: SelectableText('اسم المستخدم: ${c['username']}\nكلمة المرور: ${c['password']}'),
        actions: [
          TextButton(onPressed: () => copyText(ctx, msg), child: const Text('نسخ')),
          if (u.phone.isNotEmpty)
            TextButton(onPressed: () => openWhatsApp(ctx, u.phone, msg), child: const Text('واتساب')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final u = widget.existing!;
    if (u.uid == Session.user.uid) {
      showSnack(context, 'لا يمكنك حذف حسابك', error: true);
      return;
    }
    final ok = await confirmDialog(context, 'حذف الحساب', 'سيتم حذف حساب ${u.name} نهائياً. هل أنت متأكد؟',
        ok: 'حذف', danger: true);
    if (!ok) return;
    try {
      await AuthService.deleteAccount(u);
      if (mounted) {
        showSnack(context, 'تم الحذف');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _pickParent() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ParentPicker(parents: _parents),
    );
    if (picked == null) return;
    if (picked == '__new__') {
      final created = await _createParentInline();
      if (created != null) {
        setState(() {
          _parents = [..._parents, created];
          _parentUid = created.uid;
        });
      }
    } else {
      setState(() => _parentUid = picked);
    }
  }

  Future<AppUser?> _createParentInline() async {
    final name = TextEditingController(
        text: _name.text.trim().isEmpty ? '' : 'ولي أمر ${_name.text.trim().split(' ').first}');
    final phone = TextEditingController();
    AppUser? result;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حساب ولي أمر جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم ولي الأمر')),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الجوال (واتساب)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          BusyButton(
            label: 'إنشاء',
            onPressed: () async {
              if (name.text.trim().isEmpty) throw Exception('اكتب اسم ولي الأمر');
              final pass = AuthService.suggestPassword();
              result = await AuthService.createAccount(
                AppUser(
                  uid: '',
                  name: name.text.trim(),
                  username: AuthService.suggestUsername(Roles.parent),
                  role: Roles.parent,
                  phone: phone.text.trim(),
                ),
                pass,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted && result != null) {
                showSnack(context, 'تم إنشاء حساب ولي الأمر: ${result!.username} / $pass');
              }
            },
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _addAssignment() async {
    final a = await showDialog<Assignment>(
      context: context,
      builder: (_) => _AssignmentDialog(classes: _classes),
    );
    if (a == null) return;
    if (_assignments.any((x) => x.key == a.key)) {
      if (mounted) showSnack(context, 'هذه المادة مضافة مسبقاً', error: true);
      return;
    }
    setState(() => _assignments = [..._assignments, a]);
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = Roles.label(widget.role);
    AppUser? parent;
    for (final p in _parents) {
      if (p.uid == _parentUid) parent = p;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'إضافة $roleLabel' : widget.existing!.name),
        actions: [
          if (!_isNew)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'cred') _showCredentials();
                if (v == 'reset') _resetPassword();
                if (v == 'report') _push(context, StudentReportScreen(student: widget.existing!));
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'cred', child: Text('عرض بيانات الدخول')),
                const PopupMenuItem(value: 'reset', child: Text('تغيير كلمة المرور')),
                if (_isStudent) const PopupMenuItem(value: 'report', child: Text('تقرير الطالب')),
                const PopupMenuItem(value: 'delete', child: Text('حذف الحساب')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BusyButton(label: _isNew ? 'إنشاء الحساب' : 'حفظ التعديلات', icon: Icons.save, onPressed: _save),
        ),
      ),
      body: !_ready
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: 'اسم $roleLabel الكامل', prefixIcon: const Icon(Icons.badge)),
                ),
                const SizedBox(height: 12),
                if (_isNew) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _username,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _password,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(labelText: 'كلمة المرور'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('اقترحنا اسماً وكلمة مرور تلقائياً، ويمكنك تغييرهما.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                ] else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text('اسم المستخدم: ${widget.existing!.username}'),
                      subtitle: const Text('لعرض كلمة المرور أو تغييرها استخدم القائمة ⋮ بالأعلى'),
                    ),
                  ),
                if (!_isNew) const SizedBox(height: 12),
                if (!_isStudent) ...[
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'رقم الجوال (واتساب)', prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.role == Roles.teacher || widget.role == Roles.admin || widget.role == Roles.principal) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _section,
                    decoration: const InputDecoration(labelText: 'القسم'),
                    items: const [
                      DropdownMenuItem(value: Sections.all, child: Text('كل الأقسام')),
                      DropdownMenuItem(value: Sections.boys, child: Text('قسم البنين')),
                      DropdownMenuItem(value: Sections.girls, child: Text('قسم البنات')),
                    ],
                    onChanged: (v) => setState(() => _section = v ?? Sections.all),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isStudent) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _classId.isEmpty ? null : _classId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفصل', prefixIcon: Icon(Icons.class_)),
                    items: [for (final c in _classes) DropdownMenuItem(value: c.id, child: Text(c.label))],
                    onChanged: (v) => setState(() => _classId = v ?? ''),
                  ),
                  if (_classes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('أضف الفصول أولاً من «الفصول»', style: TextStyle(color: kDanger)),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.family_restroom, color: kPrimary),
                      title: Text(parent == null ? 'ولي الأمر: غير محدد' : 'ولي الأمر: ${parent.name}'),
                      subtitle: Text(parent == null ? 'اضغط لاختيار أو إنشاء حساب' : parent.phone),
                      trailing: _parentUid.isEmpty
                          ? const Icon(Icons.chevron_left)
                          : IconButton(
                              icon: const Icon(Icons.link_off),
                              tooltip: 'فك الربط',
                              onPressed: () => setState(() => _parentUid = ''),
                            ),
                      onTap: _pickParent,
                    ),
                  ),
                ],
                if (_isTeacher) ...[
                  SectionTitle('المواد والفصول التي يدرّسها',
                      trailing: TextButton.icon(
                        onPressed: _classes.isEmpty ? null : _addAssignment,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة'),
                      )),
                  if (_assignments.isEmpty)
                    const Card(child: ListTile(title: Text('لم تُضف مواد بعد')))
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final a in _assignments)
                            ListTile(
                              leading: const Icon(Icons.menu_book, color: kPrimary),
                              title: Text(a.subjectName),
                              subtitle: Text(a.className),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                    () => _assignments = _assignments.where((x) => x.key != a.key).toList()),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _ParentPicker extends StatefulWidget {
  final List<AppUser> parents;

  const _ParentPicker({required this.parents});

  @override
  State<_ParentPicker> createState() => _ParentPickerState();
}

class _ParentPickerState extends State<_ParentPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.parents.where((p) => _q.isEmpty || p.name.contains(_q) || p.phone.contains(_q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم أو الرقم'),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: kPrimary),
            title: const Text('إنشاء حساب ولي أمر جديد', style: TextStyle(color: kPrimary)),
            onTap: () => Navigator.pop(context, '__new__'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: Avatar(list[i].name, size: 34),
                title: Text(list[i].name),
                subtitle: Text(list[i].phone),
                onTap: () => Navigator.pop(context, list[i].uid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  final List<SchoolClass> classes;

  const _AssignmentDialog({required this.classes});

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  SchoolClass? _cls;
  List<Subject> _subjects = [];
  Subject? _subject;
  bool _loading = false;

  Future<void> _selectClass(SchoolClass? c) async {
    setState(() {
      _cls = c;
      _subject = null;
      _subjects = [];
      _loading = c != null;
    });
    if (c == null) return;
    final subs = await subjectsForClass(c);
    if (!mounted) return;
    setState(() {
      _subjects = subs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إسناد مادة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<SchoolClass>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفصل'),
            items: [for (final c in widget.classes) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: _selectClass,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<Subject>(
              key: ValueKey(_cls?.id ?? ''),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المادة'),
              items: [for (final s in _subjects) DropdownMenuItem(value: s, child: Text(s.name))],
              onChanged: (s) => setState(() => _subject = s),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _cls == null || _subject == null
              ? null
              : () => Navigator.pop(
                    context,
                    Assignment(
                      classId: _cls!.id,
                      className: _cls!.label,
                      subjectId: _subject!.id,
                      subjectName: _subject!.name,
                    ),
                  ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

// ───────────────────────── إضافة مجموعة طلاب ─────────────────────────

class BulkStudentsScreen extends StatefulWidget {
  final String? defaultClassId;

  const BulkStudentsScreen({super.key, this.defaultClassId});

  @override
  State<BulkStudentsScreen> createState() => _BulkStudentsScreenState();
}

class _BulkStudentsScreenState extends State<BulkStudentsScreen> {
  final _text = TextEditingController();
  List<SchoolClass> _classes = [];
  String? _classId;
  bool _withParents = true;
  bool _running = false;
  int _done = 0;
  int _total = 0;
  final List<String> _results = [];
  final List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _classId = widget.defaultClassId;
    Db.classes().then((c) {
      if (mounted) setState(() => _classes = c);
    });
  }

  Future<void> _run() async {
    final cls = _classes.where((c) => c.id == _classId).toList();
    if (cls.isEmpty) {
      showSnack(context, 'اختر الفصل', error: true);
      return;
    }
    final lines = _text.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      showSnack(context, 'اكتب أسماء الطلاب، كل اسم في سطر', error: true);
      return;
    }
    setState(() {
      _running = true;
      _done = 0;
      _total = lines.length;
      _results.clear();
      _errors.clear();
    });
    final c = cls.first;
    for (final line in lines) {
      // الشكل: الاسم - رقم ولي الأمر (الرقم اختياري)
      final parts = line.split(RegExp(r'\s*[-،,]\s*'));
      final name = parts.first.trim();
      final phone = parts.length > 1 ? parts[1].trim() : '';
      try {
        var parentUid = '';
        var parentLine = '';
        if (_withParents) {
          final pp = AuthService.suggestPassword();
          final parent = await AuthService.createAccount(
            AppUser(
              uid: '',
              name: 'ولي أمر ${name.split(' ').first} ${name.split(' ').length > 1 ? name.split(' ')[1] : ''}'.trim(),
              username: AuthService.suggestUsername(Roles.parent),
              role: Roles.parent,
              phone: phone,
            ),
            pp,
          );
          parentUid = parent.uid;
          parentLine = '   ولي الأمر: ${parent.username} / $pp';
        }
        final sp = AuthService.suggestPassword();
        final student = await AuthService.createAccount(
          AppUser(
            uid: '',
            name: name,
            username: AuthService.suggestUsername(Roles.student),
            role: Roles.student,
            section: c.section,
            classId: c.id,
            parentUid: parentUid,
          ),
          sp,
        );
        if (parentUid.isNotEmpty) await Db.refreshParentLinks(parentUid);
        _results.add('$name\n   الطالب: ${student.username} / $sp${parentLine.isEmpty ? '' : '\n$parentLine'}');
      } catch (e) {
        _errors.add('$name: ${friendlyError(e)}');
        if (e.toString().contains('too-many-requests')) break;
      }
      if (!mounted) return;
      setState(() => _done++);
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final className = _classes.where((c) => c.id == _classId).map((c) => c.label).join();
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مجموعة طلاب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_classes.length),
            initialValue: _classes.any((c) => c.id == _classId) ? _classId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفصل'),
            items: [for (final c in _classes) DropdownMenuItem(value: c.id, child: Text(c.label))],
            onChanged: _running ? null : (v) => setState(() => _classId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            enabled: !_running,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'أسماء الطلاب، كل طالب في سطر',
              hintText: 'محمد أحمد علي - 777123456\nفاطمة صالح محمد - 733111222\nعلي حسن',
            ),
          ),
          const SizedBox(height: 4),
          const Text('يمكنك كتابة رقم ولي الأمر بعد الاسم وعلامة -',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _withParents,
            onChanged: _running ? null : (v) => setState(() => _withParents = v),
            title: const Text('إنشاء حساب ولي أمر لكل طالب'),
          ),
          const SizedBox(height: 8),
          if (_running || _total > 0) ...[
            LinearProgressIndicator(value: _total == 0 ? 0 : _done / _total),
            const SizedBox(height: 6),
            Text('تم $_done من $_total'),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.group_add),
            label: const Text('إنشاء الحسابات'),
          ),
          if (_errors.isNotEmpty) ...[
            const SectionTitle('أخطاء'),
            for (final e in _errors) Text(e, style: const TextStyle(color: kDanger)),
            const Text('إذا ظهرت «محاولات كثيرة» انتظر ساعة ثم أكمل بقية الأسماء.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (_results.isNotEmpty) ...[
            SectionTitle('الحسابات التي أُنشئت (${_results.length})',
                trailing: TextButton.icon(
                  onPressed: () => copyText(
                    context,
                    'بيانات دخول طلاب $className - تطبيق ${Session.settings.name}\n\n${_results.join('\n\n')}',
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ الكل'),
                )),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(_results.join('\n\n'), textDirection: TextDirection.rtl),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── بيانات الدخول ─────────────────────────

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  String? _classId;
  bool _teachers = false;

  Future<List<String>> _load() async {
    final rows = <String>[];
    if (_teachers) {
      final teachers = await Db.usersByRole(Roles.teacher);
      final creds = await Future.wait(teachers.map((t) => AuthService.credentialsOf(t.uid)));
      for (var i = 0; i < teachers.length; i++) {
        rows.add('${teachers[i].name}\n   ${creds[i]['username']} / ${creds[i]['password']}');
      }
      return rows;
    }
    if (_classId == null) return rows;
    final students = await Db.studentsOfClass(_classId!);
    final creds = await Future.wait(students.map((s) => AuthService.credentialsOf(s.uid)));
    final parentIds = students.map((s) => s.parentUid).where((p) => p.isNotEmpty).toSet().toList();
    final parentCreds = <String, Map<String, String>>{};
    for (final p in parentIds) {
      parentCreds[p] = await AuthService.credentialsOf(p);
    }
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      var line = '${i + 1}. ${s.name}\n   الطالب: ${creds[i]['username']} / ${creds[i]['password']}';
      final pc = parentCreds[s.parentUid];
      if (pc != null) line += '\n   ولي الأمر: ${pc['username']} / ${pc['password']}';
      rows.add(line);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات الدخول')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AsyncBody<List<SchoolClass>>(
              load: Db.classes,
              builder: (context, classes, _) => Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('الطلاب وأولياء الأمور')),
                      ButtonSegment(value: true, label: Text('المعلمون')),
                    ],
                    selected: {_teachers},
                    onSelectionChanged: (s) => setState(() => _teachers = s.first),
                  ),
                  if (!_teachers) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _classId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'اختر الفصل'),
                      items: [for (final c in classes) DropdownMenuItem(value: c.id, child: Text(c.label))],
                      onChanged: (v) => setState(() => _classId = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncBody<List<String>>(
              key: ValueKey('$_teachers$_classId'),
              load: _load,
              builder: (context, rows, _) {
                if (rows.isEmpty) {
                  return EmptyView(
                    icon: Icons.key,
                    text: _teachers || _classId != null ? 'لا توجد حسابات' : 'اختر فصلاً لعرض بيانات دخول طلابه',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    FilledButton.icon(
                      onPressed: () => copyText(context, rows.join('\n\n'), msg: 'تم النسخ، الصقه في واتساب أو ملف للطباعة'),
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الكل'),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(rows.join('\n\n')),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── الجدول الدراسي ─────────────────────────

class TimetableClassesScreen extends StatelessWidget {
  const TimetableClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الجدول الدراسي')),
      body: AsyncBody<List<SchoolClass>>(
        load: Db.classes,
        builder: (context, list, reload) {
          if (list.isEmpty) return const EmptyView(icon: Icons.class_outlined, text: 'أضف الفصول أولاً');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_view_week, color: kAccent),
                title: Text(list[i].label),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () => _push(context, TimetableEditorScreen(cls: list[i])),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TimetableEditorScreen extends StatefulWidget {
  final SchoolClass cls;

  const TimetableEditorScreen({super.key, required this.cls});

  @override
  State<TimetableEditorScreen> createState() => _TimetableEditorScreenState();
}

class _TimetableEditorScreenState extends State<TimetableEditorScreen> {
  Map<int, List<String>> _table = {};
  List<String> _subjects = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final r = await Future.wait<Object?>([Db.timetable(widget.cls.id), subjectsForClass(widget.cls)]);
      final existing = r[0] as Map<int, List<String>>;
      final subs = (r[1] as List<Subject>).map((s) => s.name).toList();
      final periods = Session.settings.periods;
      final table = <int, List<String>>{};
      for (final d in Session.settings.days) {
        final row = List<String>.filled(periods, '');
        final old = existing[d] ?? const <String>[];
        for (var i = 0; i < periods && i < old.length; i++) {
          row[i] = old[i];
        }
        table[d] = row;
      }
      // مواد موجودة في الجدول القديم وغير موجودة في الفهرس
      for (final row in table.values) {
        for (final s in row) {
          if (s.isNotEmpty && !subs.contains(s)) subs.add(s);
        }
      }
      if (!mounted) return;
      setState(() {
        _table = table;
        _subjects = subs;
        _ready = true;
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _save() async {
    await Db.saveTimetable(widget.cls.id, _table);
    if (mounted) {
      showSnack(context, 'تم حفظ الجدول');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جدول ${widget.cls.name}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BusyButton(label: 'حفظ الجدول', icon: Icons.save, onPressed: _save),
        ),
      ),
      body: !_ready
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final d in _table.keys) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(weekdayName(d),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryDark)),
                          const SizedBox(height: 8),
                          for (var i = 0; i < _table[d]!.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(width: 70, child: Text('الحصة ${i + 1}')),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _table[d]![i],
                                      isExpanded: true,
                                      decoration: const InputDecoration(isDense: true),
                                      items: [
                                        const DropdownMenuItem(value: '', child: Text('—')),
                                        for (final s in _subjects) DropdownMenuItem(value: s, child: Text(s)),
                                      ],
                                      onChanged: (v) => _table[d]![i] = v ?? '',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}

// ───────────────────────── الإعدادات ─────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Session.settings;
  late final TextEditingController _name = TextEditingController(text: s.name);
  late final TextEditingController _phone = TextEditingController(text: s.phone);
  late final TextEditingController _year = TextEditingController(text: s.year);
  late int _term = s.term;
  late int _periods = s.periods;
  late final Set<int> _days = s.days.toSet();

  static const _allDays = [6, 7, 1, 2, 3, 4, 5];

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) throw Exception('اكتب اسم المدرسة');
    if (_days.isEmpty) throw Exception('اختر أيام الدراسة');
    final updated = SchoolSettings(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      year: _year.text.trim(),
      term: _term,
      periods: _periods,
      days: _allDays.where(_days.contains).toList(),
    );
    await Db.saveSettings(updated);
    Session.settings = updated;
    if (mounted) {
      showSnack(context, 'تم حفظ الإعدادات');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المدرسة')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BusyButton(label: 'حفظ', icon: Icons.save, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المدرسة')),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم واتساب الإدارة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _year,
            decoration: const InputDecoration(labelText: 'العام الدراسي (مثال: 2026-2027)'),
          ),
          const SectionTitle('الترم الحالي'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('الترم الأول')),
              ButtonSegment(value: 2, label: Text('الترم الثاني')),
            ],
            selected: {_term},
            onSelectionChanged: (v) => setState(() => _term = v.first),
          ),
          const SectionTitle('عدد الحصص في اليوم'),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _periods > 1 ? () => setState(() => _periods--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_periods', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                onPressed: _periods < 10 ? () => setState(() => _periods++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SectionTitle('أيام الدراسة'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in _allDays)
                FilterChip(
                  label: Text(weekdayName(d)),
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
