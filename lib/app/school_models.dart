import 'package:cloud_firestore/cloud_firestore.dart';

// ───────────────────────── الأدوار والأقسام ─────────────────────────

class Roles {
  static const owner = 'owner';
  static const admin = 'admin';
  static const principal = 'principal';
  static const teacher = 'teacher';
  static const parent = 'parent';
  static const student = 'student';

  static const _labels = {
    owner: 'مشرف النظام',
    admin: 'الإدارة',
    principal: 'المدير',
    teacher: 'معلم',
    parent: 'ولي أمر',
    student: 'طالب',
  };

  static String label(String r) => _labels[r] ?? r;

  static bool isAdmin(String r) => r == owner || r == admin;
  static bool isManager(String r) => r == owner || r == admin || r == principal;
}

class Sections {
  static const boys = 'boys';
  static const girls = 'girls';
  static const all = 'all';

  static String label(String s) => switch (s) {
        'boys' => 'قسم البنين',
        'girls' => 'قسم البنات',
        _ => 'كل الأقسام',
      };
}

class Att {
  static const present = 'present';
  static const absent = 'absent';
  static const late = 'late';
  static const excused = 'excused';

  static String label(String s) => switch (s) {
        'present' => 'حاضر',
        'absent' => 'غائب',
        'late' => 'متأخر',
        'excused' => 'غياب بعذر',
        _ => s,
      };
}

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();

List<String> _list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

// ───────────────────────── المستخدم ─────────────────────────

class Assignment {
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;

  const Assignment({
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  factory Assignment.fromMap(Map<String, dynamic> m) => Assignment(
        classId: _s(m, 'classId'),
        className: _s(m, 'className'),
        subjectId: _s(m, 'subjectId'),
        subjectName: _s(m, 'subjectName'),
      );

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'className': className,
        'subjectId': subjectId,
        'subjectName': subjectName,
      };

  String get key => '$classId|$subjectId';
}

class AppUser {
  final String uid;
  final String name;
  final String username;
  final String role;
  final String section; // boys / girls / all
  final String phone;
  final String classId; // للطالب
  final String parentUid; // للطالب
  final List<String> childrenIds; // لولي الأمر
  final List<String> childClassIds; // لولي الأمر
  final List<Assignment> assignments; // للمعلم

  const AppUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.role,
    this.section = Sections.all,
    this.phone = '',
    this.classId = '',
    this.parentUid = '',
    this.childrenIds = const [],
    this.childClassIds = const [],
    this.assignments = const [],
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final a = m['assignments'];
    return AppUser(
      uid: d.id,
      name: _s(m, 'name'),
      username: _s(m, 'username'),
      role: _s(m, 'role'),
      section: m['section']?.toString() ?? Sections.all,
      phone: _s(m, 'phone'),
      classId: _s(m, 'classId'),
      parentUid: _s(m, 'parentUid'),
      childrenIds: _list(m['childrenIds']),
      childClassIds: _list(m['childClassIds']),
      assignments: a is List
          ? a.whereType<Map>().map((e) => Assignment.fromMap(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'username': username,
        'role': role,
        'section': section,
        'phone': phone,
        'classId': classId,
        'parentUid': parentUid,
        'childrenIds': childrenIds,
        'childClassIds': childClassIds,
        'assignments': assignments.map((e) => e.toMap()).toList(),
      };

  AppUser copyWith({
    String? uid,
    String? name,
    String? username,
    String? role,
    String? section,
    String? phone,
    String? classId,
    String? parentUid,
    List<String>? childrenIds,
    List<String>? childClassIds,
    List<Assignment>? assignments,
  }) =>
      AppUser(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        username: username ?? this.username,
        role: role ?? this.role,
        section: section ?? this.section,
        phone: phone ?? this.phone,
        classId: classId ?? this.classId,
        parentUid: parentUid ?? this.parentUid,
        childrenIds: childrenIds ?? this.childrenIds,
        childClassIds: childClassIds ?? this.childClassIds,
        assignments: assignments ?? this.assignments,
      );

  /// الفصول التي يدرّسها المعلم (بدون تكرار)
  List<String> get teacherClassIds => assignments.map((e) => e.classId).toSet().toList();
}

// ───────────────────────── الفصل ─────────────────────────

class SchoolClass {
  final String id;
  final String name; // مثال: الخامس أ
  final int grade; // 1..12
  final String section; // boys / girls
  final String track; // '' أو sci / lit

  const SchoolClass({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    this.track = '',
  });

  factory SchoolClass.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return SchoolClass(
      id: d.id,
      name: _s(m, 'name'),
      grade: (m['grade'] as num?)?.toInt() ?? 1,
      section: m['section']?.toString() ?? Sections.boys,
      track: _s(m, 'track'),
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'grade': grade, 'section': section, 'track': track};

  String get label => section == Sections.girls ? '$name (بنات)' : '$name (بنين)';
}

// ───────────────────────── الحضور ─────────────────────────

class AttendanceDay {
  final String classId;
  final String date; // yyyy-MM-dd
  final Map<String, String> records; // uid -> status
  final String takenBy;

  const AttendanceDay({
    required this.classId,
    required this.date,
    required this.records,
    this.takenBy = '',
  });

  String get id => '${classId}_$date';

  factory AttendanceDay.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final r = m['records'];
    return AttendanceDay(
      classId: _s(m, 'classId'),
      date: _s(m, 'date'),
      records: r is Map ? r.map((k, v) => MapEntry(k.toString(), v.toString())) : <String, String>{},
      takenBy: _s(m, 'takenBy'),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'date': date,
        'records': records,
        'takenBy': takenBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  int count(String status) => records.values.where((v) => v == status).length;
}

// ───────────────────────── التقييمات والدرجات ─────────────────────────

class Assessment {
  final String id;
  final String classId;
  final String subjectId;
  final String subjectName;
  final int term;
  final String title;
  final double maxScore;
  final String date;
  final String teacherUid;
  final String teacherName;
  final Map<String, double> scores;

  const Assessment({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.term,
    required this.title,
    required this.maxScore,
    required this.date,
    required this.teacherUid,
    required this.teacherName,
    required this.scores,
  });

  factory Assessment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final s = m['scores'];
    return Assessment(
      id: d.id,
      classId: _s(m, 'classId'),
      subjectId: _s(m, 'subjectId'),
      subjectName: _s(m, 'subjectName'),
      term: (m['term'] as num?)?.toInt() ?? 1,
      title: _s(m, 'title'),
      maxScore: (m['maxScore'] as num?)?.toDouble() ?? 100,
      date: _s(m, 'date'),
      teacherUid: _s(m, 'teacherUid'),
      teacherName: _s(m, 'teacherName'),
      scores: s is Map
          ? s.map((k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0))
          : <String, double>{},
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'term': term,
        'title': title,
        'maxScore': maxScore,
        'date': date,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'scores': scores,
      };

  double? percentOf(String uid) {
    final v = scores[uid];
    if (v == null || maxScore <= 0) return null;
    return v / maxScore * 100;
  }

  double? get classAverage {
    if (scores.isEmpty || maxScore <= 0) return null;
    final sum = scores.values.fold<double>(0, (a, b) => a + b);
    return sum / scores.length / maxScore * 100;
  }
}

// ───────────────────────── الواجبات ─────────────────────────

class Homework {
  final String id;
  final String classId;
  final String className;
  final String subjectName;
  final String title;
  final String details;
  final String dueDate; // yyyy-MM-dd
  final String teacherUid;
  final String teacherName;
  final DateTime? createdAt;

  const Homework({
    required this.id,
    required this.classId,
    required this.className,
    required this.subjectName,
    required this.title,
    required this.details,
    required this.dueDate,
    required this.teacherUid,
    required this.teacherName,
    this.createdAt,
  });

  factory Homework.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Homework(
      id: d.id,
      classId: _s(m, 'classId'),
      className: _s(m, 'className'),
      subjectName: _s(m, 'subjectName'),
      title: _s(m, 'title'),
      details: _s(m, 'details'),
      dueDate: _s(m, 'dueDate'),
      teacherUid: _s(m, 'teacherUid'),
      teacherName: _s(m, 'teacherName'),
      createdAt: _ts(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'className': className,
        'subjectName': subjectName,
        'title': title,
        'details': details,
        'dueDate': dueDate,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ───────────────────────── الإعلانات ─────────────────────────

class Audience {
  static const all = 'all';
  static const staff = 'staff';
  static const parents = 'parents';
  static const students = 'students';

  static String label(String a) {
    if (a.startsWith('class:')) return 'فصل محدد';
    return switch (a) {
      'all' => 'الجميع',
      'staff' => 'المعلمون والإدارة',
      'parents' => 'أولياء الأمور',
      'students' => 'الطلاب',
      _ => a,
    };
  }
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final String audience; // all / staff / parents / students / class:<id>
  final String section; // all / boys / girls
  final String authorUid;
  final String authorName;
  final String authorRole;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.section,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    this.createdAt,
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Announcement(
      id: d.id,
      title: _s(m, 'title'),
      body: _s(m, 'body'),
      audience: m['audience']?.toString() ?? Audience.all,
      section: m['section']?.toString() ?? Sections.all,
      authorUid: _s(m, 'authorUid'),
      authorName: _s(m, 'authorName'),
      authorRole: _s(m, 'authorRole'),
      createdAt: _ts(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'audience': audience,
        'section': section,
        'authorUid': authorUid,
        'authorName': authorName,
        'authorRole': authorRole,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ───────────────────────── الإشعارات ─────────────────────────

class AppNotification {
  final String id;
  final String toUid;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return AppNotification(
      id: d.id,
      toUid: _s(m, 'toUid'),
      title: _s(m, 'title'),
      body: _s(m, 'body'),
      read: m['read'] == true,
      createdAt: _ts(m['createdAt']),
    );
  }
}

// ───────────────────────── الشروحات المضافة من المعلمين ─────────────────────────

class OnlineLesson {
  final String id;
  final String subjectId; // نفس معرّف المادة في المكتبة مثل g5-math
  final int term;
  final String title;
  final String url;
  final String teacherUid;
  final String teacherName;
  final DateTime? createdAt;

  const OnlineLesson({
    required this.id,
    required this.subjectId,
    required this.term,
    required this.title,
    required this.url,
    required this.teacherUid,
    required this.teacherName,
    this.createdAt,
  });

  factory OnlineLesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return OnlineLesson(
      id: d.id,
      subjectId: _s(m, 'subjectId'),
      term: (m['term'] as num?)?.toInt() ?? 1,
      title: _s(m, 'title'),
      url: _s(m, 'url'),
      teacherUid: _s(m, 'teacherUid'),
      teacherName: _s(m, 'teacherName'),
      createdAt: _ts(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'subjectId': subjectId,
        'term': term,
        'title': title,
        'url': url,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ───────────────────────── إعدادات المدرسة ─────────────────────────

class SchoolSettings {
  final String name;
  final String phone; // رقم واتساب المدرسة
  final String year; // العام الدراسي
  final int term; // الترم الحالي
  final int periods; // عدد الحصص في اليوم
  final List<int> days; // أيام الدراسة بأرقام DateTime.weekday

  const SchoolSettings({
    this.name = 'مدرستي',
    this.phone = '',
    this.year = '',
    this.term = 1,
    this.periods = 7,
    this.days = const [6, 7, 1, 2, 3, 4],
  });

  factory SchoolSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const SchoolSettings();
    final d = m['days'];
    return SchoolSettings(
      name: (m['name'] ?? 'مدرستي').toString(),
      phone: (m['phone'] ?? '').toString(),
      year: (m['year'] ?? '').toString(),
      term: (m['term'] as num?)?.toInt() ?? 1,
      periods: (m['periods'] as num?)?.toInt() ?? 7,
      days: d is List ? d.map((e) => (e as num).toInt()).toList() : const [6, 7, 1, 2, 3, 4],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'year': year,
        'term': term,
        'periods': periods,
        'days': days,
      };
}
