// نماذج البيانات: المرحلة ← الصف ← المادة ← الكتب والشروحات

class Catalog {
  final int version;
  final String schoolName;
  final List<Stage> stages;

  Catalog({required this.version, required this.schoolName, required this.stages});

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        version: j['version'] ?? 1,
        schoolName: j['schoolName'] ?? 'مدرستي',
        stages: (j['stages'] as List? ?? []).map((e) => Stage.fromJson(e)).toList(),
      );

  Grade? findGrade(String id) {
    for (final s in stages) {
      for (final g in s.grades) {
        if (g.id == id) return g;
      }
    }
    return null;
  }

  Book? findBook(String id) {
    for (final s in stages) {
      for (final g in s.grades) {
        for (final sub in g.subjects) {
          for (final b in sub.books) {
            if (b.id == id) return b;
          }
        }
      }
    }
    return null;
  }
}

class Stage {
  final String id;
  final String name;
  final List<Grade> grades;

  Stage({required this.id, required this.name, required this.grades});

  factory Stage.fromJson(Map<String, dynamic> j) => Stage(
        id: j['id'],
        name: j['name'],
        grades: (j['grades'] as List? ?? []).map((e) => Grade.fromJson(e)).toList(),
      );
}

class Grade {
  final String id;
  final int order;
  final String name;
  final bool hasTracks; // الثاني والثالث الثانوي: علمي / أدبي
  final List<Subject> subjects;

  Grade({
    required this.id,
    required this.order,
    required this.name,
    required this.hasTracks,
    required this.subjects,
  });

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        id: j['id'],
        order: j['order'] ?? 0,
        name: j['name'],
        hasTracks: j['hasTracks'] ?? false,
        subjects: (j['subjects'] as List? ?? []).map((e) => Subject.fromJson(e)).toList(),
      );

  /// track = '' يعرض الكل، 'sci' علمي، 'lit' أدبي
  List<Subject> subjectsFor(String track) {
    if (!hasTracks || track.isEmpty) return subjects;
    return subjects.where((s) => s.track.isEmpty || s.track == track).toList();
  }
}

class Subject {
  final String id;
  final String name;
  final String icon;
  final String track;
  final List<Book> books;
  final List<Lesson> lessons;

  Subject({
    required this.id,
    required this.name,
    required this.icon,
    required this.track,
    required this.books,
    required this.lessons,
  });

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: j['id'],
        name: j['name'],
        icon: j['icon'] ?? '📘',
        track: j['track'] ?? '',
        books: (j['books'] as List? ?? []).map((e) => Book.fromJson(e)).toList(),
        lessons: (j['lessons'] as List? ?? []).map((e) => Lesson.fromJson(e)).toList(),
      );
}

class Book {
  final String id;
  final String title;
  final int term; // 0 = كتاب واحد للعام، 1 = الترم الأول، 2 = الترم الثاني
  final String pdfUrl;
  final double sizeMb;
  final String edition;

  Book({
    required this.id,
    required this.title,
    required this.term,
    required this.pdfUrl,
    required this.sizeMb,
    required this.edition,
  });

  bool get isAvailable => pdfUrl.isNotEmpty;

  String get termLabel => switch (term) {
        1 => 'الترم الأول',
        2 => 'الترم الثاني',
        _ => 'العام كاملاً',
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'],
        title: j['title'],
        term: j['term'] ?? 0,
        pdfUrl: j['pdfUrl'] ?? '',
        sizeMb: (j['sizeMb'] ?? 0).toDouble(),
        edition: j['edition'] ?? '',
      );
}

class Lesson {
  final String id;
  final String title;
  final int term;
  final String unit;
  final String youtubeUrl;
  final String teacher;

  Lesson({
    required this.id,
    required this.title,
    required this.term,
    required this.unit,
    required this.youtubeUrl,
    required this.teacher,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'],
        title: j['title'],
        term: j['term'] ?? 0,
        unit: j['unit'] ?? '',
        youtubeUrl: j['youtubeUrl'] ?? '',
        teacher: j['teacher'] ?? '',
      );
}
