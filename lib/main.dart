import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workflo/screens/splashscreen.dart';
import 'firebase_options.dart';

void main() async {

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const WorkfloApp());
}

class WorkfloApp extends StatelessWidget {
  const WorkfloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workflo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F172A),
      ),
      home: const SplashScreen(),
    );
  }
}