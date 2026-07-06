import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class CartItem {
  final String medicineId;
  final String name;
  final String genericName;
  final String batchNo;
  final double sellingPrice;
  int quantity;
  final int maxStock;

  CartItem({
    required this.medicineId,
    required this.name,
    required this.genericName,
    required this.batchNo,
    required this.sellingPrice,
    required this.quantity,
    required this.maxStock,
  });
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final List<CartItem> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  String _searchQuery = '';
  bool _isProcessingSale = false;
  bool _isBakiSale = false;

  // Track the state setter of the modal bottom sheet to refresh dynamically
  StateSetter? _sheetState;

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _cart.fold(
      0.0,
      (sum, item) => sum + (item.sellingPrice * item.quantity),
    );
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _total {
    double calculated = _subtotal - _discount;
    return calculated < 0 ? 0.0 : calculated;
  }

  double get _paidAmount {
    if (!_isBakiSale) {
      final customPaid = double.tryParse(_paidAmountController.text);
      return customPaid ?? _total;
    }
    return double.tryParse(_paidAmountController.text) ?? 0.0;
  }

  double get _dueAmount {
    if (_paidAmount >= _total) return 0.0;
    return _total - _paidAmount;
  }

  double get _change {
    if (_paidAmount <= _total) return 0.0;
    return _paidAmount - _total;
  }

  void _updateStateWithSheet() {
    if (mounted) {
      setState(() {});
    }
    if (_sheetState != null) {
      _sheetState!(() {});
    }
  }

  void _onPaymentTypeChanged(bool isBaki) {
    setState(() {
      _isBakiSale = isBaki;
      if (!isBaki) {
        _paidAmountController.text = _total.toStringAsFixed(2);
      } else {
        _paidAmountController.clear();
      }
    });
    _updateStateWithSheet();
  }

  void _addMedicineToCart(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final String medicineId = doc.id;
    final String name = data['name'] ?? 'N/A';
    final String generic = data['genericName'] ?? 'N/A';
    final List<dynamic> batches = data['batches'] as List<dynamic>? ?? [];

    if (batches.isEmpty) {
      _showErrorSnackBar('This medicine has no active stock batches.');
      return;
    }

    final stockBatches = batches.where((b) {
      if (b is Map) {
        return (b['stock'] ?? 0) > 0;
      }
      return false;
    }).toList();

    if (stockBatches.isEmpty) {
      _showErrorSnackBar('All batches are out of stock!');
      return;
    }

    if (stockBatches.length == 1) {
      _addToCartWithBatch(
        medicineId,
        name,
        generic,
        Map<String, dynamic>.from(stockBatches[0] as Map),
      );
    } else {
      _showBatchSelectionDialog(medicineId, name, generic, stockBatches);
    }
  }

  void _showBatchSelectionDialog(
    String medId,
    String name,
    String generic,
    List<dynamic> batches,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Select Batch for $name',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final batch = Map<String, dynamic>.from(batches[index] as Map);
                final expDate = batch['expiryDate'] as Timestamp?;
                final formattedExp = expDate != null
                    ? DateFormat('yyyy-MM-dd').format(expDate.toDate())
                    : 'N/A';
                final int stock = (batch['stock'] ?? 0 as num).toInt();
                final double price = (batch['sellingPrice'] ?? 0.0 as num)
                    .toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      'Batch: ${batch['batchNo']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Exp: $formattedExp • Price: ৳$price'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Qty: $stock',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _addToCartWithBatch(medId, name, generic, batch);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _addToCartWithBatch(
    String medId,
    String name,
    String generic,
    Map<dynamic, dynamic> batch,
  ) {
    final String batchNo = batch['batchNo'] ?? 'N/A';
    final double price = (batch['sellingPrice'] ?? 0.0 as num).toDouble();
    final int maxStock = (batch['stock'] ?? 0 as num).toInt();

    final existingIndex = _cart.indexWhere(
      (item) => item.medicineId == medId && item.batchNo == batchNo,
    );

    if (existingIndex >= 0) {
      if (_cart[existingIndex].quantity < maxStock) {
        _cart[existingIndex].quantity++;
      } else {
        _showErrorSnackBar('Cannot add more. Maximum available stock reached.');
      }
    } else {
      _cart.add(
        CartItem(
          medicineId: medId,
          name: name,
          genericName: generic,
          batchNo: batchNo,
          sellingPrice: price,
          quantity: 1,
          maxStock: maxStock,
        ),
      );
    }

    if (!_isBakiSale) {
      _paidAmountController.text = _total.toStringAsFixed(2);
    }
    _updateStateWithSheet();
  }

  void _updateCartItemQuantity(int index, int newQty) {
    if (newQty <= 0) {
      _cart.removeAt(index);
    } else if (newQty > _cart[index].maxStock) {
      _showErrorSnackBar('Maximum available stock is ${_cart[index].maxStock}');
      return;
    } else {
      _cart[index].quantity = newQty;
    }

    if (!_isBakiSale) {
      _paidAmountController.text = _total.toStringAsFixed(2);
    }
    _updateStateWithSheet();
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  Future<void> _processCheckout() async {
    if (_cart.isEmpty) {
      _showErrorSnackBar('Your cart is empty!');
      return;
    }

    final String customerName = _customerNameController.text.trim();
    final String customerPhone = _customerPhoneController.text.trim();

    if (_isBakiSale) {
      if (customerName.isEmpty || customerPhone.isEmpty) {
        _showErrorSnackBar(
          'বাকি বা আংশিক বাকিতে বিক্রয় করতে কাস্টমারের নাম এবং মোবাইল নম্বর অবশ্যই দিতে হবে!',
        );
        return;
      }
    }

    setState(() {
      _isProcessingSale = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('Checkout: starting Firestore atomic transaction...');

      await firestore.runTransaction((transaction) async {
        debugPrint('Checkout: transaction callback initiated...');

        // ১. READ Phase: ফায়ারস্টোরের নিয়ম অনুযায়ী আগে কার্টের সকল ডাটা রিড করে নিচ্ছি
        final Map<String, DocumentSnapshot> fetchedDocs = {};
        for (var item in _cart) {
          debugPrint('Checkout: Reading doc for ID: ${item.medicineId}');
          final medRef = firestore.collection('medicines').doc(item.medicineId);
          final docSnapshot = await transaction.get(medRef);
          fetchedDocs[item.medicineId] = docSnapshot;
        }

        debugPrint(
          'Checkout: All reads completed. Starting data validation and writes...',
        );

        // ২. WRITE Phase: সমস্ত ডাটা রিড করা শেষ, এবার ব্যাচ ও টোটাল স্টক আপডেট করব
        for (var item in _cart) {
          final docSnapshot = fetchedDocs[item.medicineId]!;
          if (!docSnapshot.exists) {
            throw Exception(
              'Medicine "${item.name}" no longer exists in database!',
            );
          }

          final medData = docSnapshot.data() as Map<String, dynamic>?;
          if (medData == null) {
            throw Exception('Data missing for "${item.name}"');
          }

          final List<dynamic> dbBatches = List.from(
            medData['batches'] as List<dynamic>? ?? [],
          );
          int totalStock = (medData['totalStock'] as num? ?? 0).toInt();

          int targetBatchIndex = dbBatches.indexWhere((b) {
            if (b is Map) {
              return b['batchNo'] == item.batchNo;
            }
            return false;
          });

          if (targetBatchIndex == -1) {
            throw Exception('Batch ${item.batchNo} of ${item.name} not found!');
          }

          final batchMap = Map<String, dynamic>.from(
            dbBatches[targetBatchIndex] as Map,
          );
          int currentBatchStock = (batchMap['stock'] as num? ?? 0).toInt();

          if (currentBatchStock < item.quantity) {
            throw Exception(
              'Insufficient stock for ${item.name} (Batch: ${item.batchNo})!',
            );
          }

          // স্টক আপডেট করা হচ্ছে
          batchMap['stock'] = currentBatchStock - item.quantity;
          dbBatches[targetBatchIndex] = batchMap;
          totalStock = totalStock - item.quantity;

          final medRef = firestore.collection('medicines').doc(item.medicineId);
          transaction.update(medRef, {
            'batches': dbBatches,
            'totalStock': totalStock,
          });
          debugPrint('Checkout: Queued stock update for ${item.name}');
        }

        debugPrint('Checkout: compiling invoice details...');
        final salesRef = firestore.collection('sales').doc();
        final List<Map<String, dynamic>> itemsList = _cart.map((item) {
          return {
            'medicineId': item.medicineId,
            'name': item.name,
            'genericName': item.genericName,
            'batchNo': item.batchNo,
            'sellingPrice': item.sellingPrice,
            'quantity': item.quantity,
            'subtotal': item.sellingPrice * item.quantity,
          };
        }).toList();

        String paymentStatus = 'Paid';
        if (_isBakiSale) {
          paymentStatus = _paidAmount == 0 ? 'Due' : 'Partial';
        }

        final String timestampStr = DateTime.now().millisecondsSinceEpoch
            .toString();
        final String generatedInvoiceSuffix = timestampStr.length >= 7
            ? timestampStr.substring(timestampStr.length - 6)
            : timestampStr;

        // ইনভয়েস ডাটা ট্রানজেকশনে রাইট করা হচ্ছে
        transaction.set(salesRef, {
          'invoiceNo': 'INV-$generatedInvoiceSuffix',
          'customerName': customerName.isEmpty
              ? 'Walking Customer'
              : customerName,
          'customerPhone': customerPhone,
          'items': itemsList,
          'subtotal': _subtotal,
          'discount': _discount,
          'total': _total,
          'paidAmount': _paidAmount,
          'changeAmount': _change,
          'dueAmount': _isBakiSale ? _dueAmount : 0.0,
          'paymentStatus': paymentStatus,
          'createdAt': Timestamp.now(),
        });

        debugPrint('Checkout: writes mapped to transaction pipeline.');
      });

      debugPrint(
        'Checkout: Transaction committed successfully to Cloud Firestore!',
      );

      if (mounted) {
        // ১. আগে মেমো শিটটি স্ক্রিন থেকে রিমুভ (pop) করি
        if (_sheetState != null) {
          Navigator.pop(context);
        }

        // ২. ফ্লাটার ওয়েব ইঞ্জিনকে মেমো শিটটি মেমরি থেকে সফলভাবে রিলিজ করার সুযোগ দেই (২০০ মিলি-সেকেন্ড বিরতি)
        await Future.delayed(const Duration(milliseconds: 200));

        if (!mounted) return;

        // ৩. এখন কোনো ধরনের এরর ছাড়াই শান্তভাবে সাকসেস ডায়ালগটি প্রদর্শন করি
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Sale Completed!'),
              ],
            ),
            content: Text(
              _isBakiSale && _dueAmount > 0
                  ? 'Invoice created. Baki recorded: ৳${_dueAmount.toStringAsFixed(2)} for $customerName.'
                  : 'Invoice created successfully and stock updated.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  ); // dialogContext দিয়ে শুধুমাত্র ডায়ালগটি বন্ধ করা হচ্ছে
                  _resetPOS();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Checkout transaction error detected: $e');
      debugPrint('Checkout Stacktrace: $stackTrace');
      _showErrorSnackBar(
        'Checkout failed: ${e.toString().replaceAll('Exception:', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSale = false;
        });
      }
    }
  }

  void _resetPOS() {
    setState(() {
      _cart.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _discountController.clear();
      _paidAmountController.clear();
      _searchController.clear();
      _searchQuery = '';
      _isBakiSale = false;
    });
    _updateStateWithSheet();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);
    final isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'New Sale / POS Counter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetPOS,
            tooltip: 'Reset Cart',
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildLeftProductSelectionPanel(primaryColor),
                ),
                VerticalDivider(width: 1, color: Colors.grey[300]),
                Expanded(
                  flex: 4,
                  child: _buildRightCheckoutPanel(primaryColor),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(child: _buildLeftProductSelectionPanel(primaryColor)),
                _buildCartSummaryBottomSheet(primaryColor),
              ],
            ),
    );
  }

  Widget _buildLeftProductSelectionPanel(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medicine by name or generic...',
              prefixIcon: Icon(Icons.search, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medicines')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }
                final docs = snapshot.data?.docs ?? [];

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final generic = (data['genericName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      generic.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No medicines found in store.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'N/A';
                    final generic = data['genericName'] ?? 'N/A';
                    final category = data['category'] ?? 'N/A';
                    final totalStock = (data['totalStock'] ?? 0 as num).toInt();

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
                          backgroundColor: primaryColor.withOpacity(0.08),
                          child: Icon(Icons.medication, color: primaryColor),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$generic • $category'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Stock: $totalStock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: totalStock <= 10
                                    ? Colors.red
                                    : Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.add_circle,
                              color: primaryColor,
                              size: 22,
                            ),
                          ],
                        ),
                        onTap: () => _addMedicineToCart(doc),
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

  Widget _buildRightCheckoutPanel(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selected Medicines',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const Divider(),
          Expanded(child: _buildCartItemsListView()),
          const Divider(),
          _buildPaymentTypeToggle(),
          const SizedBox(height: 12),
          _buildCustomerInfoFields(),
          const SizedBox(height: 12),
          _buildBillSummaryCard(primaryColor),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBakiSale
                    ? Colors.orange[800]
                    : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessingSale ? null : _processCheckout,
              child: _isProcessingSale
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isBakiSale
                          ? 'Complete Due Sale (Due: ৳${_dueAmount.toStringAsFixed(2)})'
                          : 'Complete Cash Sale (৳${_total.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsListView() {
    if (_cart.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Cart is empty. Select medicines to start.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        final itemTotal = item.sellingPrice * item.quantity;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Batch: ${item.batchNo} • Price: ৳${item.sellingPrice}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '৳${itemTotal.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                onPressed: () =>
                    _updateCartItemQuantity(index, item.quantity - 1),
              ),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                onPressed: () =>
                    _updateCartItemQuantity(index, item.quantity + 1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _onPaymentTypeChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isBakiSale ? Colors.green[700] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'নগদ বিক্রয় (Cash)',
                  style: TextStyle(
                    color: !_isBakiSale ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _onPaymentTypeChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isBakiSale ? Colors.orange[800] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'বাকি বিক্রয় (Due)',
                  style: TextStyle(
                    color: _isBakiSale ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoFields() {
    if (!_isBakiSale) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'বাকির হিসাবের জন্য কাস্টমার নাম ও মোবাইল অবশ্যই পূরণ করুন!',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name *',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillSummaryCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text(
                '৳${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Discount (৳):'),
              const Spacer(),
              SizedBox(
                width: 100,
                height: 35,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (!_isBakiSale) {
                      _paidAmountController.text = _total.toStringAsFixed(2);
                    }
                    _updateStateWithSheet();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '৳${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isBakiSale)
            Row(
              children: [
                const Text('Cash Paid (৳):'),
                const Spacer(),
                SizedBox(
                  width: 100,
                  height: 35,
                  child: TextField(
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _updateStateWithSheet(),
                  ),
                ),
              ],
            ),
          const Divider(height: 20),

          if (_change > 0 && !_isBakiSale)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change Return:',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${_change.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

          if (_dueAmount > 0 && _isBakiSale)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Due Amount (বাকি):',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '৳${_dueAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

          if (_change == 0 && _dueAmount == 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status:'),
                Text(
                  _isBakiSale ? 'Due' : 'Paid',
                  style: TextStyle(
                    color: _isBakiSale ? Colors.orange[800] : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryBottomSheet(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_cart.length} items in cart',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Total: ৳${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!_isBakiSale) {
                  _paidAmountController.text = _total.toStringAsFixed(2);
                }

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setSheetState) {
                        _sheetState = setSheetState;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: SingleChildScrollView(
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.8,
                                child: _buildRightCheckoutPanel(primaryColor),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ).then((_) {
                  _sheetState = null;
                });
              },
              child: const Text(
                'Checkout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
