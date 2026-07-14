class EmployeeModel {
  final String uid;
  final String? name;
  final String? email;
  final String? mobile;
  final String? role; // e.g., 'Admin', 'Staff'
  final DateTime? createdAt;

  EmployeeModel({
    required this.uid,
    this.name,
    this.email,
    this.mobile,
    this.role,
    this.createdAt,
  });

  // Firestore থেকে ডেটা পাওয়ার জন্য (fromMap)
  factory EmployeeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmployeeModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? 'N/A',
      role: map['role'] ?? 'Staff',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // Firestore এ ডেটা পাঠানোর জন্য (toMap)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'mobile': mobile,
      'role': role,
      'createdAt': createdAt,
    };
  }
}
