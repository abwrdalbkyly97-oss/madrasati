import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db.dart';

// ───────────────────────── الألوان والثيم ─────────────────────────

const kPrimary = Color(0xFF0F766E);
const kPrimaryDark = Color(0xFF115E59);
const kAccent = Color(0xFFF59E0B);
const kDanger = Color(0xFFDC2626);
const kSuccess = Color(0xFF16A34A);
const kInfo = Color(0xFF2563EB);
const kBg = Color(0xFFF4F7F6);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

// ───────────────────────── التواريخ ─────────────────────────

const _weekdayNames = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

String weekdayName(int weekday) => _weekdayNames[weekday] ?? '';

DateTime? parseDay(String key) {
  try {
    return DateTime.parse(key);
  } catch (_) {
    return null;
  }
}

/// مثال: السبت 12/10
String prettyDay(String key) {
  final d = parseDay(key);
  if (d == null) return key;
  return '${weekdayName(d.weekday)} ${d.day}/${d.month}';
}

String prettyDateTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'م' : 'ص';
  return '${d.day}/${d.month}/${d.year} - $h:${d.minute.toString().padLeft(2, '0')} $ampm';
}

String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(v >= 99.95 ? 0 : 1)}%';

Color pctColor(double? v) {
  if (v == null) return Colors.grey;
  if (v >= 85) return kSuccess;
  if (v >= 65) return kInfo;
  if (v >= 50) return kAccent;
  return kDanger;
}

// ───────────────────────── أدوات مساعدة ─────────────────────────

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? kDanger : null),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: kDanger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

Future<void> copyText(BuildContext context, String text, {String msg = 'تم النسخ'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, msg);
}

/// يحوّل رقم يمني مثل 77xxxxxxx إلى 96777xxxxxxx
String normalizePhone(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('00')) p = p.substring(2);
  if (p.startsWith('0')) p = p.substring(1);
  if (p.length == 9 && p.startsWith('7')) p = '967$p';
  return p;
}

Future<void> openWhatsApp(BuildContext context, String phone, String text) async {
  final p = normalizePhone(phone);
  if (p.isEmpty) {
    showSnack(context, 'لا يوجد رقم هاتف مسجّل', error: true);
    return;
  }
  final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'تعذر فتح واتساب', error: true);
}

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'تعذر فتح الرابط', error: true);
}

// ───────────────────────── عناصر الواجهة ─────────────────────────

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyView({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(friendlyError(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// يحمّل بيانات ويعرضها، مع حالة التحميل والخطأ وإعادة المحاولة والسحب للتحديث
class AsyncBody<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  const AsyncBody({super.key, required this.load, required this.builder});

  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        return widget.builder(context, snap.data as T, _reload);
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimaryDark)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = kPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر كبير في لوحات التحكم
class ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  const ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = kPrimary,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ActionGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double? aspectRatio;

  const ActionGrid({super.key, required this.children, this.columns = 3, this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: aspectRatio ?? (columns >= 4 ? 0.78 : (columns == 3 ? 0.95 : 1.35)),
      children: children,
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const Avatar(this.name, {super.key, this.size = 40, this.color = kPrimary});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Text(letter,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.42)),
    );
  }
}

/// بطاقة ترحيب ملونة أعلى لوحات التحكم
class HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? bottom;

  const HeaderCard({super.key, required this.title, required this.subtitle, required this.icon, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimary, Color(0xFF14B8A6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white, size: 44),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const StatusChip(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// زر حفظ يُظهر مؤشر تحميل أثناء العملية
class BusyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function() onPressed;

  const BusyButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Icon(widget.icon ?? Icons.check),
      label: Text(widget.label),
    );
  }
}

Color attColor(String s) => switch (s) {
      'present' => kSuccess,
      'absent' => kDanger,
      'late' => kAccent,
      'excused' => kInfo,
      _ => Colors.grey,
    };

IconData attIcon(String s) => switch (s) {
      'present' => Icons.check_circle,
      'absent' => Icons.cancel,
      'late' => Icons.schedule,
      'excused' => Icons.assignment_turned_in,
      _ => Icons.help_outline,
    };
