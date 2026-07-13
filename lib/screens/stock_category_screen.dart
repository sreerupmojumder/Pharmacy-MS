import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StockCategoryScreen extends StatefulWidget {
  const StockCategoryScreen({super.key});

  @override
  State<StockCategoryScreen> createState() => _StockCategoryScreenState();
}

class _StockCategoryScreenState extends State<StockCategoryScreen> {
  int _lowStockThreshold = 20; // ডিফল্ট অ্যালার্ট লিমিট 100
  final TextEditingController _thresholdController = TextEditingController(
    text: '20',
  );

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  // অ্যালার্ট স্ক্রিন থেকেই সরাসরি কুইক রিস্টক করার বটম শিট
  void _showQuickRestockSheet(
    BuildContext context,
    String docId,
    String medicineName,
  ) {
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
                              'Quick Restock - $medicineName',
                              style: const TextStyle(
                                fontSize: 18,
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
                          labelText: 'Batch Number *',
                          hintText: 'e.g. B-99',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter batch number'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Add Stock Qty *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid integer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: buyingPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Buying Price (৳) *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter price'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: sellingPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Selling Price (৳) *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter price'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
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
                                  color: selectedExpiryDate == null
                                      ? Colors.grey[700]
                                      : Colors.black,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF005088),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005088),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    if (selectedExpiryDate == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please select expiry date',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = true;
                                    });

                                    try {
                                      int addedStock = int.parse(
                                        stockController.text.trim(),
                                      );
                                      double buyingPrice = double.parse(
                                        buyingPriceController.text.trim(),
                                      );
                                      double sellingPrice = double.parse(
                                        sellingPriceController.text.trim(),
                                      );

                                      Map<String, dynamic> newBatch = {
                                        'batchNo': batchNoController.text
                                            .trim()
                                            .toUpperCase(),
                                        'stock': addedStock,
                                        'buyingPrice': buyingPrice,
                                        'sellingPrice': sellingPrice,
                                        'expiryDate': Timestamp.fromDate(
                                          selectedExpiryDate!,
                                        ),
                                      };

                                      await FirebaseFirestore.instance
                                          .collection('medicines')
                                          .doc(docId)
                                          .update({
                                            'totalStock': FieldValue.increment(
                                              addedStock,
                                            ),
                                            'batches': FieldValue.arrayUnion([
                                              newBatch,
                                            ]),
                                          });

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Successfully restocked $medicineName!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
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
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Add Stock Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          'Low Stock Alerts Counter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // কাস্টম থ্রেশহোল্ড ফিল্টার প্যানেল
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: primaryColor, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'অ্যালার্ট লিমিট সেট করুন:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      height: 38,
                      child: TextField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          hintText: '20',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed != null && parsed >= 0) {
                            setState(() {
                              _lowStockThreshold = parsed;
                            });
                          } else if (val.trim().isEmpty) {
                            setState(() {
                              _lowStockThreshold = 0; // খালি থাকলে ০ সেট হবে
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'পিস',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medicines')
                  .where('totalStock', isLessThanOrEqualTo: _lowStockThreshold)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final lowStockDocs = snapshot.data?.docs ?? [];

                if (lowStockDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 60,
                          color: Colors.green[600],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'সব স্টক ঠিক আছে!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'কোনো ওষুধের স্টকই $_lowStockThreshold পিসের নিচে নেই।',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // সতর্কতামূলক ব্যানার
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[100]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[800],
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'নিচের ওষুধগুলোর স্টক শেষ হওয়ার পথে!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[800],
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'মোট ${lowStockDocs.length} টি ওষুধের স্টক $_lowStockThreshold পিসের নিচে নেমেছে।',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ওষুধের তালিকা
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: lowStockDocs.length,
                        itemBuilder: (context, index) {
                          final doc = lowStockDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String name = data['name'] ?? 'N/A';
                          final String generic = data['genericName'] ?? 'N/A';
                          final String category = data['category'] ?? 'N/A';
                          final int stock = (data['totalStock'] ?? 0 as num)
                              .toInt();

                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[50],
                                child: Icon(
                                  Icons.medication,
                                  color: Colors.red[700],
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('$generic • $category'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stock == 0
                                          ? Colors.red[700]
                                          : Colors.orange[800]!.withOpacity(
                                              0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      stock == 0
                                          ? 'Out of Stock'
                                          : '$stock pcs left',
                                      style: TextStyle(
                                        color: stock == 0
                                            ? Colors.white
                                            : Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () => _showQuickRestockSheet(
                                      context,
                                      doc.id,
                                      name,
                                    ),
                                    child: const Text(
                                      'Restock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
