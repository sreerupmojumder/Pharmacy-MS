import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pharmacy_app/model/employee_model.dart';
import 'package:pharmacy_app/screens/create_employee_screen.dart';
import 'package:pharmacy_app/widgets/employee_card.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final Stream<QuerySnapshot> _employeeStream = FirebaseFirestore.instance
      .collection('employees')
      .snapshots();

  int managerCount = 0;
  int salesCount = 0;
  int dataEntryCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text('Employee Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _employeeStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          int managerCount = 0;
          int salesCount = 0;
          int dataEntryCount = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            String role = data['role']?.toString().toLowerCase() ?? '';
            if (role == 'manager')
              managerCount++;
            else if (role == 'sales')
              salesCount++;
            else if (role == 'dataentry')
              dataEntryCount++;
          }
          return Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Card(
                      color: Colors.green.shade700,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateEmployeeScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Create Employee',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Card(
                      color: Colors.green.shade700,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'Employees',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(
                  spacing: 5,
                  children: [
                    Text('All Employees', style: TextStyle(fontSize: 16)),
                    Spacer(),
                    Text('Manager: $managerCount |'),
                    Text('Sales: $salesCount |'),
                    Text('DataEntry: $dataEntryCount'),
                  ],
                ),
              ),
              Divider(),

              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final emp = EmployeeModel.fromMap(
                      docs[index].data() as Map<String, dynamic>,
                      docs[index].id,
                    );
                    return EmployeeCard(employeeModel: emp);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
