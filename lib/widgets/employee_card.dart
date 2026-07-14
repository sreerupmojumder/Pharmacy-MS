import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_app/model/employee_model.dart';

class EmployeeCard extends StatefulWidget {
  final EmployeeModel employeeModel;
  final VoidCallback? refreshParent;

  const EmployeeCard({
    super.key,
    required this.employeeModel,
    this.refreshParent,
  });

  @override
  State<EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<EmployeeCard> {
  bool isEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Card(
        color: Theme.of(context).secondaryHeaderColor,
        child: ListTile(
          leading: Icon(Icons.person),
          title: Text(
            '${widget.employeeModel.name.toString()} (${widget.employeeModel.role.toString()})',
          ),
          subtitle: Column(
            crossAxisAlignment: .start,
            children: [
              Text(widget.employeeModel.email.toString()),
              Text(widget.employeeModel.mobile.toString()),
            ],
          ),

          trailing: Row(
            mainAxisSize: .min,
            children: [
              Switch(
                inactiveThumbColor: Colors.red,

                value: isEnabled,
                onChanged: (bool newValue) async {
                  setState(() {
                    isEnabled = newValue;
                  });

                  await FirebaseFirestore.instance
                      .collection('employees')
                      .doc(widget.employeeModel.uid)
                      .update({
                        'isActive':
                            newValue, // নতুন ভ্যালু (true বা false) ডাটাবেসে সেভ হচ্ছে
                      });
                },
              ),

              SizedBox(width: 4),
              IconButton(
                onPressed: () async {
                  // ১. কনফার্মেশন ডায়ালগ
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Employee"),
                      content: const Text(
                        "Are you sure you want to delete this employee? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );

                  // ২. কনফার্ম করলে ডিলিট হবে
                  if (confirm == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('employees')
                          .doc(
                            widget.employeeModel.uid,
                          ) // আপনার মডেল থেকে UID নেওয়া হচ্ছে
                          .delete();

                      User? user = FirebaseAuth.instance.currentUser;

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Employee deleted successfully!"),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      }
                    }
                  }
                },
                icon: Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
