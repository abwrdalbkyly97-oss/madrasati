import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/auth_screens.dart';
import 'app/db.dart';
import 'app/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseConfigured) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  runApp(const MadrasatiApp());
}

class MadrasatiApp extends StatelessWidget {
  const MadrasatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدرستي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const AuthGate(),
    );
  }
}
