import 'package:flutter/material.dart';

import 'db.dart';
import 'school_models.dart';
import 'ui.dart';

// ───────────────────────── الإعلانات ─────────────────────────

bool _announcementVisibleToMe(Announcement a, List<String> myClassIds) {
  final me = Session.user;
  if (Roles.isManager(me.role) || a.authorUid == me.uid) return true;
  if (me.role == Roles.teacher) {
    if (a.audience.startsWith('class:')) return myClassIds.contains(a.audience.substring(6));
    return a.audience == Audience.all || a.audience == Audience.staff;
  }
  final sectionOk = a.section == Sections.all || me.section == Sections.all || a.section == me.section;
  if (!sectionOk && me.role == Roles.student) return false;
  if (a.audience == Audience.all) return true;
  if (a.audience.startsWith('class:')) return myClassIds.contains(a.audience.substring(6));
  if (me.role == Roles.parent) return a.audience == Audience.parents;
  if (me.role == Roles.student) return a.audience == Audience.students;
  return false;
}

List<String> _myClassIds() {
  final me = Session.user;
  switch (me.role) {
    case Roles.student:
      return [me.classId];
    case Roles.parent:
      return me.childClassIds;
    case Roles.teacher:
      return me.teacherClassIds;
    default:
      return const [];
  }
}

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  bool get _canPost => Session.user.role != Roles.student && Session.user.role != Roles.parent;

  @override
  Widget build(BuildContext context) {
    final classIds = _myClassIds();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات'), actions: const [NotificationBell()]),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ComposeAnnouncementScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('إعلان جديد'),
            )
          : null,
      body: StreamBuilder<List<Announcement>>(
        stream: Db.announcements(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!.where((a) => _announcementVisibleToMe(a, classIds)).toList();
          if (list.isEmpty) return const EmptyView(icon: Icons.campaign_outlined, text: 'لا توجد إعلانات بعد');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => AnnouncementCard(a: list[i]),
          );
        },
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement a;

  const AnnouncementCard({super.key, required this.a});

  bool get _canDelete => Roles.isManager(Session.user.role) || a.authorUid == Session.user.uid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(a.authorName, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${Roles.label(a.authorRole)} · ${prettyDateTime(a.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                if (_canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.black45),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'حذف الإعلان', 'هل تريد حذف هذا الإعلان؟',
                          ok: 'حذف', danger: true);
                      if (ok) await Db.deleteAnnouncement(a.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(a.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(a.body, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                StatusChip(Audience.label(a.audience), color: kInfo),
                if (a.section != Sections.all) StatusChip(Sections.label(a.section), color: kAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ComposeAnnouncementScreen extends StatefulWidget {
  const ComposeAnnouncementScreen({super.key});

  @override
  State<ComposeAnnouncementScreen> createState() => _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState extends State<ComposeAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = Audience.all;
  String _section = Sections.all;
  List<SchoolClass> _classes = [];

  bool get _isManager => Roles.isManager(Session.user.role);

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final all = await Db.classes();
      final mine = Session.user.teacherClassIds;
      setState(() {
        _classes = _isManager ? all : all.where((c) => mine.contains(c.id)).toList();
        if (!_isManager && _classes.isNotEmpty) _audience = 'class:${_classes.first.id}';
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      throw Exception('اكتب عنوان الإعلان ونصّه');
    }
    if (!_isManager && !_audience.startsWith('class:')) throw Exception('اختر الفصل');
    final me = Session.user;
    await Db.addAnnouncement(Announcement(
      id: '',
      title: _title.text.trim(),
      body: _body.text.trim(),
      audience: _audience,
      section: _section,
      authorUid: me.uid,
      authorName: me.name,
      authorRole: me.role,
    ));
    if (mounted) {
      showSnack(context, 'تم نشر الإعلان');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      if (_isManager) ...const [
        DropdownMenuItem(value: Audience.all, child: Text('الجميع')),
        DropdownMenuItem(value: Audience.parents, child: Text('أولياء الأمور')),
        DropdownMenuItem(value: Audience.students, child: Text('الطلاب')),
        DropdownMenuItem(value: Audience.staff, child: Text('المعلمون والإدارة')),
      ],
      for (final c in _classes) DropdownMenuItem(value: 'class:${c.id}', child: Text('فصل: ${c.label}')),
    ];
    final validAudience = items.any((e) => e.value == _audience) ? _audience : null;
    return Scaffold(
      appBar: AppBar(title: const Text('إعلان جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان')),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'نص الإعلان', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('aud${_classes.length}'),
            initialValue: validAudience,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'إلى من؟'),
            items: items,
            onChanged: (v) => setState(() => _audience = v ?? Audience.all),
          ),
          if (_isManager) ...[
            const SizedBox(height: 12),
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
          ],
          const SizedBox(height: 24),
          BusyButton(label: 'نشر الإعلان', icon: Icons.send, onPressed: _send),
        ],
      ),
    );
  }
}

// ───────────────────────── الإشعارات ─────────────────────────

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: Db.myNotifications(Session.user.uid),
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[]).where((n) => !n.read).length;
        return IconButton(
          tooltip: 'الإشعارات',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: StreamBuilder<List<AppNotification>>(
        stream: Db.myNotifications(Session.user.uid),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyView(icon: Icons.notifications_none, text: 'لا توجد إشعارات');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = list[i];
              return Card(
                color: n.read ? Colors.white : const Color(0xFFE6F6F4),
                child: ListTile(
                  leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active,
                      color: n.read ? Colors.black38 : kPrimary),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(n.body),
                      const SizedBox(height: 4),
                      Text(prettyDateTime(n.createdAt), style: const TextStyle(fontSize: 11.5)),
                    ],
                  ),
                  onTap: () {
                    if (!n.read) Db.markRead(n.id);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Db.deleteNotification(n.id),
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

// ───────────────────────── حسابي ─────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.user;
    final s = Session.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Avatar(me.name, size: 76),
                  const SizedBox(height: 12),
                  Text(me.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  StatusChip(Roles.label(me.role), color: kPrimary),
                  const SizedBox(height: 10),
                  Text('اسم المستخدم: ${me.username}', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school, color: kPrimary),
                  title: Text(s.name),
                  subtitle: Text([
                    if (s.year.isNotEmpty) 'العام الدراسي ${s.year}',
                    s.term == 2 ? 'الترم الثاني' : 'الترم الأول',
                  ].join(' · ')),
                ),
                if (s.phone.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.chat, color: kSuccess),
                    title: const Text('تواصل مع إدارة المدرسة (واتساب)'),
                    onTap: () => openWhatsApp(context, s.phone, 'السلام عليكم، أنا ${me.name}'),
                  ),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: kInfo),
                  title: const Text('تغيير كلمة المرور'),
                  onTap: () => _changePassword(context),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: kDanger),
                  title: const Text('تسجيل الخروج'),
                  onTap: () async {
                    final ok = await confirmDialog(context, 'تسجيل الخروج', 'هل تريد تسجيل الخروج؟', ok: 'خروج');
                    if (ok) await AuthService.signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('مدرستي · الإصدار 2.0', style: TextStyle(color: Colors.black38, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldC,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newC,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة (6 على الأقل)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          BusyButton(
            label: 'حفظ',
            onPressed: () async {
              if (newC.text.length < 6) throw Exception('كلمة المرور الجديدة 6 أحرف على الأقل');
              await AuthService.changeMyPassword(oldC.text, newC.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showSnack(context, 'تم تغيير كلمة المرور');
              }
            },
          ),
        ],
      ),
    );
  }
}
