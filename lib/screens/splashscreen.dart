import 'package:flutter/material.dart';
import 'loginscreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // TODO: replace with a real auth check if you want returning users
    // to skip straight to the dashboard, e.g.:
    // final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(
    //     builder: (_) => isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    //   ),
    // );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Workflo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading...',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF38BDF8),
            ),
          ],
        ),
      ),
    );
  }
}