import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import 'reader_screen.dart';

/// الكتب الموجودة على الهاتف: تفتح بدون إنترنت ويمكن حذفها لتوفير المساحة
class DownloadsScreen extends StatefulWidget {
  final Catalog catalog;

  const DownloadsScreen({super.key, required this.catalog});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _storage = BookStorage();
  Map<String, double> _files = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await _storage.downloaded();
    if (mounted) setState(() => _files = f);
  }

  Future<void> _delete(Book b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الكتاب من الهاتف؟'),
        content: Text('${b.title}\nيمكنك تنزيله مرة أخرى في أي وقت.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await _storage.delete(b);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _files.entries
        .map((e) => MapEntry(widget.catalog.findBook(e.key), e.value))
        .where((e) => e.key != null)
        .toList();
    final total = _files.values.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('كتبي المحمّلة')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: entries.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.cloud_download_outlined, size: 64, color: Colors.black26),
                SizedBox(height: 12),
                Center(child: Text('لم تنزّل أي كتاب بعد')),
              ])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('المساحة المستخدمة: ${total.toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  for (final e in entries)
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(e.key!.title),
                        subtitle: Text('${e.value.toStringAsFixed(1)} MB'),
                        onTap: () async {
                          final file = await _storage.fileFor(e.key!);
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReaderScreen(book: e.key!, file: file)),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(e.key!),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
