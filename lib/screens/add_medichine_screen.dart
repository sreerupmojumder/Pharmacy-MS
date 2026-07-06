import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _genericController = TextEditingController();
  final _stockController = TextEditingController();
  final _batchNoController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  
  String? _selectedCategory;
  DateTime? _selectedExpiryDate;
  bool _isLoading = false;

  // ক্যাটাগরি লিস্ট
  final List<String> _categories = [
    'Tablet', 
    'Capsule', 
    'Syrup', 
    'Injection', 
    'Ointment', 
    'Drops', 
    'OTC'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _genericController.dispose();
    _stockController.dispose();
    _batchNoController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)), // ডিফল্ট ১ বছর পর
      firstDate: DateTime.now(), // অতীত ডেট বন্ধ
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF005088),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          // child! এর বদলে child ?? const SizedBox() ব্যবহার করে নাল এরর দূর করা হয়েছে
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  Future<void> _saveMedicine() async {
    final form = _formKey.currentState;
    if (form != null && form.validate()) {
      // ক্যাটাগরি চেক
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red),
        );
        return;
      }
      
      // এক্সপায়ারি ডেট চেক
      final expiryDateVal = _selectedExpiryDate;
      if (expiryDateVal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expiry date'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        int enteredStock = double.parse(_stockController.text.trim()).toInt();
        double buyingPrice = double.parse(_buyingPriceController.text.trim());
        double sellingPrice = double.parse(_sellingPriceController.text.trim());

        // প্রথম ব্যাচের ডেটা ম্যাপ তৈরি (মিলি-সেকেন্ড ব্যবহার করে এক্সপায়ারি ডেট সেভ)
        Map<String, dynamic> firstBatch = {
          'batchNo': _batchNoController.text.trim().toUpperCase(),
          'stock': enteredStock,
          'buyingPrice': buyingPrice,
          'sellingPrice': sellingPrice,
          'expiryDate': Timestamp.fromMillisecondsSinceEpoch(
            expiryDateVal.millisecondsSinceEpoch,
          ),
        };

        // ফায়ারস্টোরে সফলভাবে নতুন প্রোডাক্ট সেভ করা
        await FirebaseFirestore.instance.collection('medicines').add({
          'name': _nameController.text.trim(),
          'genericName': _genericController.text.trim(),
          'category': _selectedCategory,
          'totalStock': enteredStock, 
          'batches': [firstBatch], 
          'createdAt': Timestamp.now(), // ওয়েবের জন্য নিরাপদ কারেন্ট টাইমস্ট্যাম্প
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine and Batch added successfully!'), 
              backgroundColor: Colors.green
            ),
          );
        }

        // ফর্মের সব ডেটা ক্লিয়ার করা
        form.reset();
        _nameController.clear();
        _genericController.clear();
        _stockController.clear();
        _batchNoController.clear();
        _buyingPriceController.clear();
        _sellingPriceController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedExpiryDate = null;
        });

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add New Medicine', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: _isLoading, // ডাটা সেভ হওয়ার সময় ইউজার যেন কোনো ইনপুট পরিবর্তন করতে না পারে
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ১. মেডিসিন নাম
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Medicine Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Enter medicine name' : null,
                ),
                const SizedBox(height: 18),

                // ২. জেনেরিক নাম
                TextFormField(
                  controller: _genericController,
                  decoration: InputDecoration(
                    labelText: 'Generic Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Enter generic name' : null,
                ),
                const SizedBox(height: 18),

                // ৩. ক্যাটাগরি ড্রপডাউন
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(value: category, child: Text(category));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 18),

                // ৪. স্টক কোয়ান্টিটি
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock Quantity *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter stock quantity';
                    if (double.tryParse(value) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ৫. ব্যাচ নম্বর
                TextFormField(
                  controller: _batchNoController,
                  decoration: InputDecoration(
                    labelText: 'Batch Number *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Enter batch number' : null,
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Buying Price (৳) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter buying price';
                          if (double.tryParse(value) == null) return 'Enter a valid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Selling Price (৳) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter selling price';
                          if (double.tryParse(value) == null) return 'Enter a valid price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                InkWell(
                  onTap: () => _pickExpiryDate(context),
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[600]!),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedExpiryDate == null
                              ? 'Select Expiry Date *'
                              : 'Expiry Date: ${DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedExpiryDate == null ? Colors.grey[700] : Colors.black,
                            fontWeight: _selectedExpiryDate == null ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded, color: primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _saveMedicine,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Medicine', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}