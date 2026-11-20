import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'shell.dart';
import 'ui.dart';

/// البوابة: تحدد ماذا يظهر حسب حالة الدخول
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!firebaseConfigured) return const _NotConfiguredScreen();
    return StreamBuilder<User?>(
      stream: AuthService.auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }
        final user = snap.data;
        if (user == null) return const _SignedOutGate();
        return _ProfileLoader(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  final String uid;

  const _ProfileLoader({super.key, required this.uid});

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<bool> _load() async {
    // بعد إنشاء الحساب مباشرة قد يتأخر حفظ الملف الشخصي ثوانٍ
    var me = await Db.user(widget.uid);
    for (var i = 0; i < 6 && me == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      me = await Db.user(widget.uid);
    }
    if (me == null) return false;
    Session.me = me;
    Session.settings = await Db.settings();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snap.hasError) {
          return Scaffold(
            body: ErrorView(
              error: snap.error!,
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }
        if (snap.data != true) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('هذا الحساب غير مسجّل في النظام'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: AuthService.signOut, child: const Text('تسجيل الخروج')),
                ],
              ),
            ),
          );
        }
        return const RoleShell();
      },
    );
  }
}

/// قبل الدخول: إما إعداد أول مرة أو شاشة الدخول
class _SignedOutGate extends StatefulWidget {
  const _SignedOutGate();

  @override
  State<_SignedOutGate> createState() => _SignedOutGateState();
}

class _SignedOutGateState extends State<_SignedOutGate> {
  late Future<bool> _setupDone;

  @override
  void initState() {
    super.initState();
    _setupDone = AuthService.isSetupDone();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _setupDone,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snap.hasError) {
          return Scaffold(
            body: ErrorView(
              error: snap.error!,
              onRetry: () => setState(() => _setupDone = AuthService.isSetupDone()),
            ),
          );
        }
        return snap.data == true ? const LoginScreen() : const SetupOwnerScreen();
      },
    );
  }
}

// ───────────────────────── تسجيل الدخول ─────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      showSnack(context, 'أدخل اسم المستخدم وكلمة المرور', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_user.text, _pass.text);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, size: 64, color: kPrimary),
                ),
                const SizedBox(height: 16),
                const Text('مدرستي',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kPrimaryDark)),
                const SizedBox(height: 6),
                const Text('سجّل الدخول بالحساب الذي أعطته لك المدرسة',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 28),
                TextField(
                  controller: _user,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('دخول', style: TextStyle(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('نسيت كلمة المرور؟ تواصل مع إدارة المدرسة',
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── إعداد أول مرة ─────────────────────────

class SetupOwnerScreen extends StatefulWidget {
  const SetupOwnerScreen({super.key});

  @override
  State<SetupOwnerScreen> createState() => _SetupOwnerScreenState();
}

class _SetupOwnerScreenState extends State<SetupOwnerScreen> {
  final _school = TextEditingController();
  final _name = TextEditingController();
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();

  Future<void> _save() async {
    if (_school.text.trim().isEmpty || _name.text.trim().isEmpty) {
      throw Exception('اكتب اسم المدرسة واسمك');
    }
    if (!AuthService.validUsername(_user.text)) {
      throw Exception('اسم المستخدم: حروف إنجليزية وأرقام فقط (3 أحرف على الأقل)');
    }
    if (_pass.text.length < 6) throw Exception('كلمة المرور 6 أحرف على الأقل');
    await AuthService.setupOwner(_name.text.trim(), _user.text, _pass.text, _school.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد النظام لأول مرة')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const HeaderCard(
            title: 'أهلاً بك 👋',
            subtitle: 'هذه الشاشة تظهر مرة واحدة فقط. ستنشئ حساب مشرف النظام الذي يدير كل شيء.',
            icon: Icons.admin_panel_settings,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _school,
            decoration: const InputDecoration(labelText: 'اسم المدرسة', prefixIcon: Icon(Icons.school)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسمك الكامل', prefixIcon: Icon(Icons.badge)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'اسم المستخدم (إنجليزي)', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            textDirection: TextDirection.ltr,
            decoration:
                const InputDecoration(labelText: 'كلمة المرور (6 على الأقل)', prefixIcon: Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 8),
          const Text('احفظ اسم المستخدم وكلمة المرور في مكان آمن.',
              style: TextStyle(color: kDanger, fontSize: 13)),
          const SizedBox(height: 20),
          BusyButton(label: 'إنشاء الحساب والبدء', icon: Icons.rocket_launch, onPressed: _save),
        ],
      ),
    );
  }
}

class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyView(
        icon: Icons.cloud_off,
        text: 'لم يتم ربط التطبيق بقاعدة البيانات بعد.\nأضف السر FIREBASE_CONFIG في GitHub ثم أعد البناء.',
      ),
    );
  }
}
