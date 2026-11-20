import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models.dart';
import '../services.dart';
import 'firebase_config.dart';
import 'school_models.dart';

// ───────────────────────── الإعداد ─────────────────────────

bool get firebaseConfigured => kFirebaseApiKey.isNotEmpty && kFirebaseProjectId.isNotEmpty;

FirebaseOptions get firebaseOptions => const FirebaseOptions(
      apiKey: kFirebaseApiKey,
      appId: kFirebaseAppId,
      messagingSenderId: kFirebaseSenderId,
      projectId: kFirebaseProjectId,
      storageBucket: kFirebaseStorageBucket,
    );

/// بيانات الجلسة الحالية (المستخدم وإعدادات المدرسة)
class Session {
  static AppUser? me;
  static SchoolSettings settings = const SchoolSettings();

  static AppUser get user => me!;
}

/// فهرس المكتبة يُحمَّل مرة واحدة ويُشارك بين الشاشات
class CatalogStore {
  static Future<Catalog>? _future;

  static Future<Catalog> get() => _future ??= CatalogRepository().load();

  static Future<Catalog> reload() => _future = CatalogRepository().load();
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String get todayKey => dayKey(DateTime.now());

// ───────────────────────── قاعدة البيانات ─────────────────────────

class Db {
  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> col(String path) => fs.collection(path);

  // ── الإعدادات
  static Future<SchoolSettings> settings() async {
    final d = await col('settings').doc('school').get();
    return SchoolSettings.fromMap(d.data());
  }

  static Future<void> saveSettings(SchoolSettings s) =>
      col('settings').doc('school').set(s.toMap(), SetOptions(merge: true));

  // ── المستخدمون
  static Future<AppUser?> user(String uid) async {
    final d = await col('users').doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  static Future<List<AppUser>> usersByRole(String role) async {
    final q = await col('users').where('role', isEqualTo: role).get();
    final list = q.docs.map(AppUser.fromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<List<AppUser>> studentsOfClass(String classId) async {
    final q = await col('users').where('classId', isEqualTo: classId).get();
    final list = q.docs.map(AppUser.fromDoc).where((u) => u.role == Roles.student).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<List<AppUser>> childrenOf(String parentUid) async {
    final q = await col('users').where('parentUid', isEqualTo: parentUid).get();
    final list = q.docs.map(AppUser.fromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<void> saveUser(AppUser u) => col('users').doc(u.uid).set(u.toMap());

  /// يعيد حساب أبناء ولي الأمر وفصولهم (يُستدعى بعد حفظ أي طالب)
  static Future<void> refreshParentLinks(String parentUid) async {
    if (parentUid.isEmpty) return;
    final kids = await childrenOf(parentUid);
    await col('users').doc(parentUid).update({
      'childrenIds': kids.map((k) => k.uid).toList(),
      'childClassIds': kids.map((k) => k.classId).where((c) => c.isNotEmpty).toSet().toList(),
    });
  }

  static Future<int> countRole(String role) async {
    final r = await col('users').where('role', isEqualTo: role).count().get();
    return r.count ?? 0;
  }

  // ── الفصول
  static Future<List<SchoolClass>> classes() async {
    final q = await col('classes').get();
    final list = q.docs.map(SchoolClass.fromDoc).toList();
    list.sort((a, b) {
      final g = a.grade.compareTo(b.grade);
      if (g != 0) return g;
      final s = a.section.compareTo(b.section);
      return s != 0 ? s : a.name.compareTo(b.name);
    });
    return list;
  }

  static Future<SchoolClass?> classById(String id) async {
    if (id.isEmpty) return null;
    final d = await col('classes').doc(id).get();
    return d.exists ? SchoolClass.fromDoc(d) : null;
  }

  static Future<void> saveClass(SchoolClass c) async {
    if (c.id.isEmpty) {
      await col('classes').add(c.toMap());
    } else {
      await col('classes').doc(c.id).set(c.toMap());
    }
  }

  static Future<void> deleteClass(String id) => col('classes').doc(id).delete();

  // ── الجدول الدراسي: { "6": ["رياضيات", ...], "7": [...] }
  static Future<Map<int, List<String>>> timetable(String classId) async {
    final d = await col('timetables').doc(classId).get();
    final m = d.data()?['days'];
    final result = <int, List<String>>{};
    if (m is Map) {
      m.forEach((k, v) {
        final day = int.tryParse(k.toString());
        if (day != null && v is List) result[day] = v.map((e) => e.toString()).toList();
      });
    }
    return result;
  }

  static Future<void> saveTimetable(String classId, Map<int, List<String>> days) =>
      col('timetables').doc(classId).set({
        'days': days.map((k, v) => MapEntry(k.toString(), v)),
      });

  // ── الحضور
  static Future<AttendanceDay?> attendance(String classId, String date) async {
    final d = await col('attendance').doc('${classId}_$date').get();
    return d.exists ? AttendanceDay.fromDoc(d) : null;
  }

  static Future<List<AttendanceDay>> attendanceOfClass(String classId) async {
    final q = await col('attendance').where('classId', isEqualTo: classId).get();
    final list = q.docs.map(AttendanceDay.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<List<AttendanceDay>> attendanceOnDate(String date) async {
    final q = await col('attendance').where('date', isEqualTo: date).get();
    return q.docs.map(AttendanceDay.fromDoc).toList();
  }

  static Future<void> saveAttendance(AttendanceDay a) => col('attendance').doc(a.id).set(a.toMap());

  // ── التقييمات
  static Future<List<Assessment>> assessmentsOfClass(String classId) async {
    final q = await col('assessments').where('classId', isEqualTo: classId).get();
    final list = q.docs.map(Assessment.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> saveAssessment(Assessment a) async {
    if (a.id.isEmpty) {
      await col('assessments').add(a.toMap());
    } else {
      await col('assessments').doc(a.id).set(a.toMap());
    }
  }

  static Future<void> deleteAssessment(String id) => col('assessments').doc(id).delete();

  // ── الواجبات
  static Future<List<Homework>> homeworkOfClass(String classId) async {
    final q = await col('homework').where('classId', isEqualTo: classId).get();
    final list = q.docs.map(Homework.fromDoc).toList();
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  static Future<List<Homework>> homeworkByTeacher(String uid) async {
    final q = await col('homework').where('teacherUid', isEqualTo: uid).get();
    final list = q.docs.map(Homework.fromDoc).toList();
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  static Future<void> addHomework(Homework h) => col('homework').add(h.toMap());

  static Future<void> deleteHomework(String id) => col('homework').doc(id).delete();

  // ── الشروحات
  static Future<List<OnlineLesson>> lessonsOfSubject(String subjectId) async {
    final q = await col('lessons').where('subjectId', isEqualTo: subjectId).get();
    final list = q.docs.map(OnlineLesson.fromDoc).toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  static Future<List<OnlineLesson>> lessonsByTeacher(String uid) async {
    final q = await col('lessons').where('teacherUid', isEqualTo: uid).get();
    return q.docs.map(OnlineLesson.fromDoc).toList();
  }

  static Future<void> addLesson(OnlineLesson l) => col('lessons').add(l.toMap());

  static Future<void> deleteLesson(String id) => col('lessons').doc(id).delete();

  // ── الإعلانات
  static Stream<List<Announcement>> announcements() => col('announcements')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map(Announcement.fromDoc).toList());

  static Future<void> addAnnouncement(Announcement a) => col('announcements').add(a.toMap());

  static Future<void> deleteAnnouncement(String id) => col('announcements').doc(id).delete();

  // ── الإشعارات
  static Stream<List<AppNotification>> myNotifications(String uid) =>
      col('notifications').where('toUid', isEqualTo: uid).snapshots().map((q) {
        final list = q.docs.map(AppNotification.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  static Future<void> notify(String toUid, String title, String body) {
    return col('notifications').add({
      'toUid': toUid,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markRead(String id) => col('notifications').doc(id).update({'read': true});

  static Future<void> deleteNotification(String id) => col('notifications').doc(id).delete();
}

// ───────────────────────── الحسابات ─────────────────────────

class AuthService {
  static const domain = 'madrasati.app';

  static FirebaseAuth get auth => FirebaseAuth.instance;

  static String emailOf(String username) => '${username.trim().toLowerCase()}@$domain';

  static bool validUsername(String u) => RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(u.trim());

  static final _rnd = Random.secure();

  static String randomDigits(int n) => List.generate(n, (_) => _rnd.nextInt(10)).join();

  static String suggestUsername(String role) {
    final prefix = switch (role) {
      'student' => 's',
      'parent' => 'p',
      'teacher' => 't',
      'principal' => 'm',
      _ => 'a',
    };
    return '$prefix${randomDigits(5)}';
  }

  static String suggestPassword() => randomDigits(6);

  static Future<FirebaseApp> _secondaryApp() async {
    for (final a in Firebase.apps) {
      if (a.name == 'secondary') return a;
    }
    return Firebase.initializeApp(name: 'secondary', options: firebaseOptions);
  }

  static Future<void> signIn(String username, String password) async {
    await auth.signInWithEmailAndPassword(email: emailOf(username), password: password);
  }

  static Future<void> signOut() async {
    await auth.signOut();
  }

  static Future<bool> isSetupDone() async {
    final d = await Db.col('meta').doc('setup').get();
    return d.exists;
  }

  /// إنشاء حساب مشرف النظام (أول مرة فقط)
  static Future<void> setupOwner(String name, String username, String password, String schoolName) async {
    final cred = await auth.createUserWithEmailAndPassword(email: emailOf(username), password: password);
    final uid = cred.user!.uid;
    final user = AppUser(uid: uid, name: name, username: username.trim().toLowerCase(), role: Roles.owner);
    final batch = Db.fs.batch();
    batch.set(Db.col('users').doc(uid), user.toMap());
    batch.set(Db.col('credentials').doc(uid), {
      'username': user.username,
      'password': password,
      'role': Roles.owner,
      'name': name,
    });
    batch.set(Db.col('meta').doc('setup'), {'ownerUid': uid, 'createdAt': FieldValue.serverTimestamp()});
    await batch.commit();
    await Db.saveSettings(SchoolSettings(name: schoolName));
  }

  /// إنشاء حساب لمستخدم آخر بدون تسجيل خروج المسؤول
  static Future<AppUser> createAccount(AppUser u, String password) async {
    final app = await _secondaryApp();
    final a2 = FirebaseAuth.instanceFor(app: app);
    final cred = await a2.createUserWithEmailAndPassword(email: emailOf(u.username), password: password);
    final uid = cred.user!.uid;
    await a2.signOut();
    final saved = u.copyWith(uid: uid, username: u.username.trim().toLowerCase());
    final batch = Db.fs.batch();
    batch.set(Db.col('users').doc(uid), saved.toMap());
    batch.set(Db.col('credentials').doc(uid), {
      'username': saved.username,
      'password': password,
      'role': saved.role,
      'name': saved.name,
    });
    await batch.commit();
    return saved;
  }

  static Future<Map<String, String>> credentialsOf(String uid) async {
    final d = await Db.col('credentials').doc(uid).get();
    final m = d.data() ?? {};
    return {
      'username': (m['username'] ?? '').toString(),
      'password': (m['password'] ?? '').toString(),
    };
  }

  /// تغيير كلمة مرور مستخدم آخر من حساب الإدارة
  static Future<void> resetPassword(String uid, String newPassword) async {
    final c = await credentialsOf(uid);
    final app = await _secondaryApp();
    final a2 = FirebaseAuth.instanceFor(app: app);
    final cred = await a2.signInWithEmailAndPassword(email: emailOf(c['username']!), password: c['password']!);
    await cred.user!.updatePassword(newPassword);
    await a2.signOut();
    await Db.col('credentials').doc(uid).update({'password': newPassword});
  }

  /// حذف حساب نهائياً
  static Future<void> deleteAccount(AppUser u) async {
    final c = await credentialsOf(u.uid);
    if (c['username']!.isNotEmpty && c['password']!.isNotEmpty) {
      try {
        final app = await _secondaryApp();
        final a2 = FirebaseAuth.instanceFor(app: app);
        final cred = await a2.signInWithEmailAndPassword(email: emailOf(c['username']!), password: c['password']!);
        await cred.user!.delete();
        await a2.signOut();
      } catch (_) {
        // إذا تعذر حذف الدخول نكمل حذف البيانات حتى لا يظهر في النظام
      }
    }
    await Db.col('users').doc(u.uid).delete();
    await Db.col('credentials').doc(u.uid).delete();
    if (u.role == Roles.student && u.parentUid.isNotEmpty) {
      await Db.refreshParentLinks(u.parentUid);
    }
  }

  /// المستخدم يغيّر كلمة مروره بنفسه
  static Future<void> changeMyPassword(String oldPassword, String newPassword) async {
    final user = auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
    await Db.col('credentials').doc(user.uid).set({'password': newPassword}, SetOptions(merge: true));
  }
}

/// رسالة خطأ عربية مفهومة
String friendlyError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'اسم المستخدم مستخدم من قبل، اختر اسماً آخر';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، يجب أن تكون 6 أحرف أو أرقام على الأقل';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً ثم حاول مرة أخرى';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت';
      case 'requires-recent-login':
        return 'سجّل الخروج ثم ادخل مرة أخرى وحاول';
    }
    return e.message ?? e.code;
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'ليس لديك صلاحية لهذه العملية';
    if (e.code == 'unavailable') return 'لا يوجد اتصال بالإنترنت';
    return e.message ?? e.code;
  }
  return e.toString().replaceFirst('Exception: ', '');
}
