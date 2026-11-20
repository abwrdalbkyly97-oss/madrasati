import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models.dart';
import '../services.dart';

/// قارئ الكتاب: يفتح من الهاتف بدون إنترنت ويتذكر آخر صفحة
class ReaderScreen extends StatefulWidget {
  final Book book;
  final File file;

  const ReaderScreen({super.key, required this.book, required this.file});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _controller = PdfViewerController();
  int? _startPage;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    UserPrefs.lastPage(widget.book.id).then((p) => setState(() {
          _startPage = p;
          _page = p;
        }));
  }

  Future<void> _goToPage() async {
    final ctrl = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقل إلى صفحة'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 – $_total'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (page != null && page >= 1 && (_total == 0 || page <= _total)) {
      _controller.goToPage(pageNumber: page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _goToPage,
            child: Text(
              _total == 0 ? '$_page' : '$_page / $_total',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _startPage == null
          ? const Center(child: CircularProgressIndicator())
          : PdfViewer.file(
              widget.file.path,
              controller: _controller,
              initialPageNumber: _startPage!,
              params: PdfViewerParams(
                onViewerReady: (document, controller) {
                  setState(() => _total = document.pages.length);
                },
                onPageChanged: (page) {
                  if (page == null) return;
                  setState(() => _page = page);
                  UserPrefs.saveLastPage(widget.book.id, page);
                },
              ),
            ),
    );
  }
}
