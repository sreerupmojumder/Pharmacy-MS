import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // স্ক্রিন লোড হওয়ামাত্র অটোম্যাটিক্যালি ডিফল্ট ক্যাটাগরি চেক ও সিঙ্ক করবে
    _prepopulateDefaultCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  // ফায়ারস্টোরে ক্যাটাগরি পপুলেট করার লজিক (প্রথমবার ডাটাবেস ফাঁকা থাকলে অটো ব্যাকআপ)
  Future<void> _prepopulateDefaultCategories() async {
    try {
      final categoriesRef = FirebaseFirestore.instance.collection('categories');
      final snapshot = await categoriesRef.limit(1).get();

      if (snapshot.docs.isEmpty) {
        final List<String> defaultCats = [
          'Tablet',
          'Capsule',
          'Syrup',
          'Injection',
          'Ointment',
          'Drops',
          'OTC'
        ];

        for (var cat in defaultCats) {
          await categoriesRef.add({
            'name': cat,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error prepopulating default categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // নতুন ক্যাটাগরি যুক্ত করার ইনপুট ফর্ম
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      hintText: 'Add new category (e.g., Inhaler, Herbal)...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final catName = _categoryController.text.trim();
                    if (catName.isEmpty) return;

                    try {
                      await FirebaseFirestore.instance.collection('categories').add({
                        'name': catName,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      _categoryController.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Category "$catName" added successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add category: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // ক্যাটাগরি রিয়েল-টাইম তালিকা
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                final categoriesDocs = snapshot.data?.docs ?? [];

                if (categoriesDocs.isEmpty) {
                  return const Center(child: Text('No categories available.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categoriesDocs.length,
                  itemBuilder: (context, index) {
                    final doc = categoriesDocs[index];
                    final catName = doc['name'] ?? 'N/A';

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.08),
                          child: const Icon(Icons.label_outline, color: primaryColor),
                        ),
                        title: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final bool? confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Text('Delete Category?'),
                                  content: Text('Are you sure you want to delete the category "$catName"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmDelete == true) {
                              await FirebaseFirestore.instance.collection('categories').doc(doc.id).delete();
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}