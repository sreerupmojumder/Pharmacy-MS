import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Sales';

  void _createEmployee() async {
    try {
      // ১. Firebase Auth এ ইউজার তৈরি
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // ২. Firestore এ এমপ্লয়ির তথ্য সেভ করা
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(userCredential.user!.uid)
          .set({
            'name': _nameController.text,
            'email': _emailController.text,
            'role': _selectedRole,
            'isActive': true,
          });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Employee Account")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the Name.';
                  }

                  return null;
                },
                decoration: const InputDecoration(
                  labelText: "Name",

                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the email.';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email address.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Email",

                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the Password.';
                  }

                  return null;
                },
                decoration: const InputDecoration(
                  labelText: "Initial Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white, // ব্যাকগ্রাউন্ড কালার
                  borderRadius: BorderRadius.circular(12), // রাউন্ডেড কর্নার
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ), // হালকা বর্ডার
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(
                        0.1,
                      ), // হালকা শ্যাডো বা ছায়া
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  // ডিফল্ট নিচের দাগটি লুকানোর জন্য
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true, // ড্রপডাউনটি যেন পুরো জায়গা জুড়ে থাকে
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.blueAccent,
                    ), // সুন্দর আইকন
                    iconSize: 28,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: Colors.white, // ড্রপডাউন মেনুর ব্যাকগ্রাউন্ড
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // মেনুর কর্নার রাউন্ডেড করার জন্য
                    items: ['Sales', 'DataEntry', 'Manager']
                        .map(
                          (r) => DropdownMenuItem<String>(
                            value: r,
                            child: Text(r),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRole = val);
                      }
                    },
                  ),
                ),
              ),

              SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white, // ব্যাকগ্রাউন্ড কালার
                  borderRadius: BorderRadius.circular(12), // রাউন্ডেড কর্নার
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ), // হালকা বর্ডার
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(
                        0.1,
                      ), // হালকা শ্যাডো বা ছায়া
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _createEmployee();
                    }
                  },
                  child: const Text("Create Employee"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
