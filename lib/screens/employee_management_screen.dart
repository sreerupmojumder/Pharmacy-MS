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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Salesperson';

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
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Initial Password"),
            ),
            DropdownButton<String>(
              value: _selectedRole,
              items: [
                'Sales',
                'DataEntry'
                'Manager',
               
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),
            ElevatedButton(
              onPressed: _createEmployee,
              child: const Text("Create Employee"),
            ),
          ],
        ),
      ),
    );
  }
}
