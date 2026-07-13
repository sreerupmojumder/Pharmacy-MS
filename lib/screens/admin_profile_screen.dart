import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_app/screens/change_password_screen.dart';
import 'package:pharmacy_app/widgets/custom_text_button.dart';
import 'package:pharmacy_app/widgets/custom_text_field.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String name = '';
  String email = '';

  Future<void> updateAdminProfile() async {
    try {
      // ১. বর্তমান লগইন থাকা ইউজারের তথ্য নেওয়া
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        String uid = currentUser.uid;
        String email = currentUser.email ?? ""; // অথেন্টিকেশন থেকে ইমেইল নেওয়া
        setState(() {
          isLoading = true;
        });
        // ২. ফায়ারস্টোরের 'admins' কালেকশনে ডেটা সেভ বা আপডেট করা

        await FirebaseFirestore.instance.collection('admins').doc(uid).set(
          {
            'uid': uid,
            'email': email, // এটি রিড-অনলি হিসেবে থাকবে
            'name': nameController.text.trim(),
            'mobile': mobileController.text.trim(),
            'address': addressController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ); // merge: true দিলে আগের ডেটা মুছে যাবে না, শুধু আপডেট হবে

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Update Success!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
    setState(() {});
  }

  Future<void> loadAdminData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        nameController.text = data['name'] ?? '';
        mobileController.text = data['mobile'] ?? '';
        addressController.text = data['address'] ?? '';
        name = data['name'] ?? 'Admin';
        email = data['email'] ?? 'abc@gmail.com';
      }
      setState(() {});
    }
  }

  void refreshData() {
    setState(() {
      loadAdminData();
    });
  }

  @override
  initState() {
    super.initState();
    loadAdminData();
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
            crossAxisAlignment: .start,
            mainAxisAlignment: .center,
            children: [
              Row(
                mainAxisSize: .min,
                children: [
                  CircleAvatar(radius: 40),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(email, style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordScreen(),
                        ),
                      );
                    },
                    child: Text('Change Password'),
                  ),
                ],
              ),
              SizedBox(height: 30),

              CustomTextField(hintText: 'Name', controller: nameController),

              SizedBox(height: 10),

              CustomTextField(hintText: 'Mobile', controller: mobileController),
              SizedBox(height: 10),
              CustomTextField(
                hintText: 'Address',
                controller: addressController,
              ),

              SizedBox(height: 30),
              CustomTextButton(
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    isLoading ? null : updateAdminProfile();
                    refreshData();
                  }
                },
                title: isLoading
                    ? const SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text(
                        "Update",
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
