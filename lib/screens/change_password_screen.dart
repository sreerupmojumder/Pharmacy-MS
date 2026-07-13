import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_app/widgets/custom_text_button.dart';
import 'package:pharmacy_app/widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;

  Future<void> changePassword() async {
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // ২. পাসওয়ার্ড লেন্থ চেক (ফায়ারবেসে মিনিমাম ৬ ক্যারেক্টার লাগে)
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("পাসওয়ার্ড অবশ্যই কমপক্ষে ৬ অক্ষরের হতে হবে।"),
        ),
      );
      return;
    }

    // ৩. দুই ফিল্ডের পাসওয়ার্ড মিলছে কিনা চেক
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("পাসওয়ার্ড দুটি মেলেনি! আবার চেক করুন।")),
      );
      return;
    }

    // লোডিং শুরু
    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // ৪. ফায়ারবেস অথেন্টিকেশনে পাসওয়ার্ড আপডেট
        await user.updatePassword(password);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("পাসওয়ার্ড সফলভাবে আপডেট হয়েছে!")),
        );

        // ফিল্ডগুলো খালি করে দেওয়া
        passwordController.clear();
        confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "কিছু একটা ভুল হয়েছে।")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).primaryColor),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: .center,
            children: [
              CustomTextField(
                hintText: 'Password',
                controller: passwordController,
              ),
              SizedBox(height: 10),
              CustomTextField(
                hintText: 'Confirm Password',
                controller: confirmPasswordController,
              ),

              SizedBox(height: 30),
              CustomTextButton(
                onTap: isLoading ? null : changePassword,
                title: isLoading
                    ? const SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text(
                        "Update Password",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
