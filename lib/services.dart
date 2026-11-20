import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// ⚙️ ضع هنا رابط ملف catalog.json بعد رفعه (مثلاً على GitHub بصيغة raw).
/// إذا تركته فارغاً يستخدم التطبيق النسخة الموجودة داخل التطبيق فقط.
const String kRemoteCatalogUrl = '';

/// مسؤول عن تحميل فهرس المكتبة:
/// 1) من الإنترنت إذا توفر، ويحفظ نسخة محلية
/// 2) وإلا من آخر نسخة محفوظة
/// 3) وإلا من النسخة المدمجة في التطبيق
class CatalogRepository {
  static const _cacheKey = 'catalog_cache';

  Future<Catalog> load() async {
    final prefs = await SharedPreferences.getInstance();

    if (kRemoteCatalogUrl.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(kRemoteCatalogUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = utf8.decode(res.bodyBytes);
          final catalog = Catalog.fromJson(jsonDecode(body));
          await prefs.setString(_cacheKey, body);
          return catalog;
        }
      } catch (_) {
        // لا يوجد إنترنت: نكمل للنسخة المحفوظة
      }
    }

    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        return Catalog.fromJson(jsonDecode(cached));
      } catch (_) {}
    }

    final bundled = await rootBundle.loadString('assets/catalog.json');
    return Catalog.fromJson(jsonDecode(bundled));
  }
}

/// تنزيل الكتب وحفظها في الهاتف للقراءة بدون إنترنت
class BookStorage {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/books');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> fileFor(Book book) async => File('${(await _dir()).path}/${book.id}.pdf');

  Future<bool> isDownloaded(Book book) async {
    final f = await fileFor(book);
    return f.exists();
  }

  /// يرسل نسبة التقدم من 0 إلى 1 (أو -1 إذا كان الحجم غير معروف)
  Future<File> download(Book book, void Function(double progress) onProgress) async {
    final target = await fileFor(book);
    final temp = File('${target.path}.part');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(book.pdfUrl)));
      if (res.statusCode != 200) {
        throw Exception('تعذر التنزيل (رمز ${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = temp.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : -1);
      }
      await sink.close();
      await temp.rename(target.path);
      return target;
    } catch (e) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> delete(Book book) async {
    final f = await fileFor(book);
    if (await f.exists()) await f.delete();
  }

  /// كل الكتب المحملة مع حجمها بالميجابايت
  Future<Map<String, double>> downloaded() async {
    final d = await _dir();
    final result = <String, double>{};
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.pdf')) {
        final id = e.uri.pathSegments.last.replaceAll('.pdf', '');
        result[id] = (await e.length()) / (1024 * 1024);
      }
    }
    return result;
  }
}

/// إعدادات الطالب: صفه، قسمه (علمي/أدبي)، وآخر صفحة في كل كتاب
class UserPrefs {
  static Future<String?> getGrade() async =>
      (await SharedPreferences.getInstance()).getString('my_grade');

  static Future<void> setGrade(String id) async =>
      (await SharedPreferences.getInstance()).setString('my_grade', id);

  static Future<String> getTrack() async =>
      (await SharedPreferences.getInstance()).getString('my_track') ?? '';

  static Future<void> setTrack(String t) async =>
      (await SharedPreferences.getInstance()).setString('my_track', t);

  static Future<int> lastPage(String bookId) async =>
      (await SharedPreferences.getInstance()).getInt('page_$bookId') ?? 1;

  static Future<void> saveLastPage(String bookId, int page) async =>
      (await SharedPreferences.getInstance()).setInt('page_$bookId', page);
}
