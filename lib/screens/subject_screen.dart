import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services.dart';
import 'reader_screen.dart';

/// صفحة المادة: تبويب للكتب (ترم أول / ثاني) وتبويب للشروحات
class SubjectScreen extends StatelessWidget {
  final Subject subject;
  final String gradeName;

  const SubjectScreen({super.key, required this.subject, required this.gradeName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(subject.name),
              Text(gradeName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'الكتب'),
              Tab(icon: Icon(Icons.play_circle_outline), text: 'الشروحات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BooksTab(books: subject.books),
            _LessonsTab(lessons: subject.lessons),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── الكتب ─────────────────────────────

class _BooksTab extends StatelessWidget {
  final List<Book> books;

  const _BooksTab({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(child: Text('لا توجد كتب لهذه المادة بعد'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => BookTile(book: books[i]),
    );
  }
}

class BookTile extends StatefulWidget {
  final Book book;

  const BookTile({super.key, required this.book});

  @override
  State<BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<BookTile> {
  final _storage = BookStorage();
  bool _downloaded = false;
  double? _progress; // null = لا يوجد تنزيل جارٍ

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final d = await _storage.isDownloaded(widget.book);
    if (mounted) setState(() => _downloaded = d);
  }

  Future<void> _download() async {
    setState(() => _progress = 0);
    try {
      await _storage.download(widget.book, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _downloaded = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر التنزيل، تأكد من الاتصال بالإنترنت وحاول مرة أخرى')),
        );
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _open() async {
    final file = await _storage.fileFor(widget.book);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(book: widget.book, file: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final scheme = Theme.of(context).colorScheme;

    Widget action;
    if (!b.isAvailable) {
      action = const Chip(label: Text('قريباً'));
    } else if (_progress != null) {
      action = SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(value: _progress! < 0 ? null : _progress),
      );
    } else if (_downloaded) {
      action = FilledButton.icon(
        onPressed: _open,
        icon: const Icon(Icons.chrome_reader_mode),
        label: const Text('اقرأ'),
      );
    } else {
      action = OutlinedButton.icon(
        onPressed: _download,
        icon: const Icon(Icons.download),
        label: Text(b.sizeMb > 0 ? 'تنزيل ${b.sizeMb.toStringAsFixed(0)}MB' : 'تنزيل'),
      );
    }

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 62,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.menu_book, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    [b.termLabel, if (b.edition.isNotEmpty) 'طبعة ${b.edition}'].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── الشروحات ─────────────────────────────

class _LessonsTab extends StatelessWidget {
  final List<Lesson> lessons;

  const _LessonsTab({required this.lessons});

  Future<void> _play(BuildContext context, Lesson l) async {
    final ok = await launchUrl(Uri.parse(l.youtubeUrl), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح الشرح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('سيضيف المعلمون شروحات هذه المادة قريباً', textAlign: TextAlign.center),
        ),
      );
    }

    // تجميع الشروحات حسب الترم ثم الوحدة
    final groups = <String, List<Lesson>>{};
    for (final l in lessons) {
      final term = l.term == 2 ? 'الترم الثاني' : (l.term == 1 ? 'الترم الأول' : 'عام');
      final key = l.unit.isEmpty ? term : '$term – ${l.unit}';
      groups.putIfAbsent(key, () => []).add(l);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final l in entry.value)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 36),
                title: Text(l.title),
                subtitle: l.teacher.isEmpty ? null : Text('أ. ${l.teacher}'),
                onTap: () => _play(context, l),
              ),
            ),
        ],
      ],
    );
  }
}
