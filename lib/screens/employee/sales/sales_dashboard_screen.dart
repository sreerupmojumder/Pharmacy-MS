import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_app/screens/user_login_screen.dart';

class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // Firebase থেকে ইউজারকে সাইন আউট করা
      await FirebaseAuth.instance.signOut();

      // সব আগের রুট (routes) ডিলিট করে লগইন স্ক্রিনে পাঠানো
      // যাতে ইউজার ব্যাক বাটনে ক্লিক করে আবার ড্যাশবোর্ডে ফিরে আসতে না পারে
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserLoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Icon(Icons.person),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              _logout(context);
            },
          ),
        ],
      ),
      body: Center(child: Text('Sales Screen')),
    );
  }
}
