import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/screens/add_medichine_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ফায়ারস্টোর থেকে সম্পূর্ণ মেডিসিন রেকর্ড মুছে ফেলার ফাংশন
  Future<void> _deleteMedicine(BuildContext context, String docId, String medicineName) async {
    // ডিলিট করার আগে ইউজারের নিশ্চিতকরণ ডায়ালগ
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
              const SizedBox(width: 8),
              const Text('Confirm Delete'),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete "$medicineName" from the inventory?\n\nThis will also delete all batches and stock associated with this medicine.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    // ইউজার ডিলিট সিলেক্ট করলে ফায়ারস্টোর থেকে ডকুমেন্ট রিমুভ হবে
    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('medicines').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$medicineName" deleted successfully!'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showRestockSheet(BuildContext context, String docId, String medicineName, int currentTotalStock) {
    final formKey = GlobalKey<FormState>();
    final batchNoController = TextEditingController();
    final stockController = TextEditingController();
    final buyingPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    DateTime? selectedExpiryDate;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Restock - $medicineName',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF005088),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: batchNoController,
                        decoration: InputDecoration(
                          labelText: 'New Batch Number *',
                          hintText: 'e.g. B-103',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter batch number' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Added Stock Quantity *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter quantity';
                          if (double.tryParse(value) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: buyingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Buying Price (৳) *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter buying price';
                                if (double.tryParse(value) == null) return 'Invalid price';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: sellingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Selling Price (৳) *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter selling price';
                                if (double.tryParse(value) == null) return 'Invalid price';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2040),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedExpiryDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[600]!),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedExpiryDate == null
                                    ? 'Select Expiry Date *'
                                    : 'Expiry Date: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: selectedExpiryDate == null ? Colors.grey[700] : Colors.black,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: Color(0xFF005088)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005088),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    final expiryDateTime = selectedExpiryDate;
                                    if (expiryDateTime == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please select an expiry date'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = true;
                                    });

                                    try {
                                      int addedStock = double.parse(stockController.text.trim()).toInt();
                                      double buyingPrice = double.parse(buyingPriceController.text.trim());
                                      double sellingPrice = double.parse(sellingPriceController.text.trim());

                                      // ফ্লাটার ওয়েবে dart2js এরর এড়াতে মিলি-সেকেন্ড ব্যবহার করে এক্সপায়ারি ডেট অবজেক্ট তৈরি
                                      Map<String, dynamic> newBatch = {
                                        'batchNo': batchNoController.text.trim().toUpperCase(),
                                        'stock': addedStock,
                                        'buyingPrice': buyingPrice,
                                        'sellingPrice': sellingPrice,
                                        'expiryDate': Timestamp.fromMillisecondsSinceEpoch(
                                          expiryDateTime.millisecondsSinceEpoch,
                                        ),
                                      };

                                      // Firestore আপডেট: totalStock বাড়িয়ে দেওয়া এবং batches অ্যারেতে নতুন ব্যাচ পুশ করা
                                      await FirebaseFirestore.instance
                                          .collection('medicines')
                                          .doc(docId)
                                          .update({
                                        'totalStock': FieldValue.increment(addedStock),
                                        'batches': FieldValue.arrayUnion([newBatch]),
                                      });

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully restocked $medicineName!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      setSheetState(() {
                                        isSaving = false;
                                      });
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Confirm Restock',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Medicines Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name or Generic name...',
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medicines')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                final docs = snapshot.data?.docs ?? [];

                // ফিল্টারিং লজিক
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final generic = (data['genericName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || generic.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No medicines found!',
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final name = data['name'] ?? 'N/A';
                    final generic = data['genericName'] ?? 'N/A';
                    final category = data['category'] ?? 'N/A';
                    final totalStock = data['totalStock'] ?? 0;
                    final batches = data['batches'] as List<dynamic>? ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.medication, color: primaryColor),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text('$generic • $category'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: totalStock <= 10 ? Colors.red[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Qty: $totalStock',
                                style: TextStyle(
                                  color: totalStock <= 10 ? Colors.red[700] : Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Active Batches & Stocks:',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    Row(
                                      children: [
                                        // ডিলিট করার বাটন
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Delete Medicine',
                                          onPressed: () => _deleteMedicine(context, docId, name),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          ),
                                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                                          label: const Text('Restock', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showRestockSheet(context, docId, name, totalStock),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                batches.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text('No batches available for this medicine.'),
                                      )
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowHeight: 35,
                                          dataRowMinHeight: 35,
                                          dataRowMaxHeight: 45,
                                          columns: const [
                                            DataColumn(label: Text('Batch No')),
                                            DataColumn(label: Text('Stock')),
                                            DataColumn(label: Text('Buying (৳)')),
                                            DataColumn(label: Text('Selling (৳)')),
                                            DataColumn(label: Text('Expiry Date')),
                                          ],
                                          rows: batches.map((batch) {
                                            final bMap = Map<String, dynamic>.from(batch as Map);
                                            final expDate = bMap['expiryDate'] as Timestamp?;
                                            final formattedExp = expDate != null
                                                ? DateFormat('yyyy-MM-dd').format(expDate.toDate())
                                                : 'N/A';

                                            return DataRow(cells: [
                                              DataCell(Text(bMap['batchNo']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500))),
                                              DataCell(Text(bMap['stock']?.toString() ?? '0')),
                                              DataCell(Text(bMap['buyingPrice']?.toString() ?? '0.0')),
                                              DataCell(Text(bMap['sellingPrice']?.toString() ?? '0.0')),
                                              DataCell(Text(formattedExp)),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
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