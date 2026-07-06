import 'package:flutter/material.dart';
import 'package:pharmacy_app/screens/user_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      moveToNextScreen();
    });

    super.initState();
  }

  Future<void> moveToNextScreen() async {
    Future.delayed(Duration(seconds: 5));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => UserLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [Text('My Shop'), CircularProgressIndicator()]),
    );
  }
}
