import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

// صفحة تسجيل الدخول
import 'ui/sign_in_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (اختياري) لالتقاط أي أخطاء أثناء الإقلاع
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // تهيئة Supabase (لا تغيّر أي شيء في Firebase)
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  // تهيئة Firebase
  await Firebase.initializeApp();

  // DEV ONLY: لضمان ظهور صفحة الـ Sign in كل مرة تشغّل فيها التطبيق
  // احذف السطر التالي عند الإنتاج.
  await FirebaseAuth.instance.signOut();

  runApp(const ShopAdminApp());
}

class ShopAdminApp extends StatelessWidget {
  const ShopAdminApp({super.key});

  static const Color kPrimary = Color(0xFF2ECC95);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        fontFamily: 'Roboto',
      ),
      // نبدأ دائمًا بصفحة تسجيل الدخول
      home: const AdminSignInPage(),
    );
  }
}
