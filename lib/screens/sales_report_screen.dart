import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  // সার্চ এবং পেমেন্ট টাইপ ফিল্টার ভেরিয়েবলসমূহ
  String _salesSearchQuery = '';
  String _dueSearchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Paid', 'Due', 'Partial'

  // ডাইনামিক ডেট ফিল্টার (ডিফল্ট পারফরম্যান্সের জন্য 'This Month' রাখা হলো)
  String _dateFilter =
      'This Month'; // 'Today', 'This Month', 'This Year', 'All Time'

  final TextEditingController _salesSearchController = TextEditingController();
  final TextEditingController _dueSearchController = TextEditingController();

  // রিয়্যাল-টাইম কোয়েরি স্ট্রিম
  late Stream<QuerySnapshot> _salesStream;

  @override
  void initState() {
    super.initState();
    _updateSalesStream();
  }

  // এই ফাংশনটি সিলেক্ট করা ডেট ফিল্টার অনুযায়ী ডাটাবেস কোয়েরি অপ্টিমাইজ করে
  void _updateSalesStream() {
    final DateTime now = DateTime.now();
    Query query = FirebaseFirestore.instance
        .collection('sales')
        .orderBy('createdAt', descending: true);

    // ফায়ারস্টোর লেভেলেই কোয়েরি ফিল্টার করে ডাটা কম ডাউনলোড করা হচ্ছে (পারফরম্যান্স বুস্ট)
    if (_dateFilter == 'Today') {
      final DateTime startOfToday = DateTime(now.year, now.month, now.day);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
      );
    } else if (_dateFilter == 'This Month') {
      final DateTime startOfThisMonth = DateTime(now.year, now.month, 1);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfThisMonth),
      );
    } else if (_dateFilter == 'This Year') {
      final DateTime startOfThisYear = DateTime(now.year, 1, 1);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfThisYear),
      );
    }
    // 'All Time' হলে কোনো ফিল্টার ছাড়া সব ডাটা লোড হবে (প্রয়োজন সাপেক্ষে)

    setState(() {
      _salesStream = query.snapshots();
    });
  }

  @override
  void dispose() {
    _salesSearchController.dispose();
    _dueSearchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green[700]!;
      case 'due':
        return Colors.red[700]!;
      case 'partial':
        return Colors.orange[800]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

  void _showInvoiceDetailsDialog(Map<String, dynamic> invoice, String docId) {
    final List<dynamic> items = invoice['items'] as List<dynamic>? ?? [];
    const primaryColor = Color(0xFF005088);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Memo: ${invoice['invoiceNo']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Sold By: ${invoice['soldByName']}',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${invoice['customerName'] ?? 'Walking Customer'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (invoice['customerPhone'] != null &&
                      invoice['customerPhone'].toString().isNotEmpty)
                    Text('Phone: ${invoice['customerPhone']}'),
                  Text(
                    'Date: ${_formatDate(invoice['createdAt'] as Timestamp?)}',
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Purchased Items:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(
                        items[index] as Map,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['name']} (${item['batchNo']}) x ${item['quantity']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),

                            Text(
                              '৳${(item['subtotal'] as num? ?? 0).toStringAsFixed(1)}',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                        '৳${(invoice['subtotal'] as num? ?? 0.0).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  if ((invoice['discount'] as num? ?? 0) > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:'),
                        Text(
                          '-৳${(invoice['discount'] as num? ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bill:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '৳${(invoice['total'] as num? ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paid Amount:'),
                      Text(
                        '৳${(invoice['paidAmount'] as num? ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Due (বাকি):',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '৳${(invoice['dueAmount'] as num? ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDueCollectionDialog(Map<String, dynamic> invoice, String docId) {
    final double outstandingDue = (invoice['dueAmount'] as num? ?? 0.0)
        .toDouble();
    final double previousPaid = (invoice['paidAmount'] as num? ?? 0.0)
        .toDouble();
    final double totalBill = (invoice['total'] as num? ?? 0.0).toDouble();

    final TextEditingController collectionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.payment, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'Collect Due (বাকি আদায়)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${invoice['customerName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Invoice: ${invoice['invoiceNo']}'),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Bill:'),
                        Text('৳${totalBill.toStringAsFixed(2)}'),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paid Till Now:'),
                        Text(
                          '৳${previousPaid.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Outstanding Due:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '৳${outstandingDue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: collectionController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Collect Amount (৳) *',
                        hintText: 'e.g. ${outstandingDue.toStringAsFixed(0)}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter collection amount';
                        final double? amt = double.tryParse(value);
                        if (amt == null || amt <= 0)
                          return 'Enter a valid positive amount';
                        if (amt > outstandingDue)
                          return 'Cannot collect more than due amount!';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isProcessing = true;
                            });

                            try {
                              final double collectedAmt = double.parse(
                                collectionController.text.trim(),
                              );
                              final double newPaid =
                                  previousPaid + collectedAmt;
                              final double newDue =
                                  outstandingDue - collectedAmt;

                              String newStatus = 'Paid';
                              if (newDue > 0) {
                                newStatus = 'Partial';
                              }

                              // ফায়ারস্টোর আপডেট করা হচ্ছে
                              await FirebaseFirestore.instance
                                  .collection('sales')
                                  .doc(docId)
                                  .update({
                                    'paidAmount': newPaid,
                                    'dueAmount': newDue,
                                    'paymentStatus': newStatus,
                                    'lastDueCollectedAt': Timestamp.now(),
                                  });

                              if (context.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '৳${collectedAmt.toStringAsFixed(0)} collected successfully for ${invoice['invoiceNo']}!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating record: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setDialogState(() {
                                isProcessing = false;
                              });
                            }
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Payment',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Sales & Due Collection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.tealAccent,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.receipt_long),
                text: 'Sales Report (বিক্রয় রিপোর্ট)',
              ),
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Due Tracker (বাকি খাতা)',
              ),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _salesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];

            // রিয়্যাল-টাইম স্ট্যাটিস্টিক ক্যালকুলেশন (টাইমফ্রেম ফিল্টার অনুযায়ী)
            double totalSales = 0.0;
            double totalReceived = 0.0;
            double totalDue = 0.0;
            double totalDiscount = 0.0;
            int totalInvoicesCount = docs.length;
            int totalMedicineItemsSold = 0;

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              totalSales += (data['total'] as num? ?? 0.0).toDouble();
              totalReceived += (data['paidAmount'] as num? ?? 0.0).toDouble();
              totalDue += (data['dueAmount'] as num? ?? 0.0).toDouble();
              totalDiscount += (data['discount'] as num? ?? 0.0).toDouble();

              // ওষুধ বিক্রির মোট পিস সংখ্যা হিসাব করা হচ্ছে
              final List<dynamic> items = data['items'] as List<dynamic>? ?? [];
              for (var item in items) {
                totalMedicineItemsSold += (item['quantity'] as num? ?? 0)
                    .toInt();
              }
            }

            return TabBarView(
              children: [
                _buildSalesReportTab(
                  docs,
                  totalSales,
                  totalReceived,
                  totalDue,
                  totalDiscount,
                  totalInvoicesCount,
                  totalMedicineItemsSold,
                  primaryColor,
                ),
                _buildDueTrackerTab(docs, totalDue, primaryColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSalesReportTab(
    List<QueryDocumentSnapshot> docs,
    double totalSales,
    double totalReceived,
    double totalDue,
    double totalDiscount,
    int totalInvoicesCount,
    int totalMedicineItemsSold,
    Color primaryColor,
  ) {
    // সার্চ এবং ডাইনামিক ফিল্টার অ্যাপ্লাই করা হচ্ছে
    final filteredSales = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final invNo = (data['invoiceNo'] ?? '').toString().toLowerCase();
      final name = (data['customerName'] ?? '').toString().toLowerCase();
      final phone = (data['customerPhone'] ?? '').toString().toLowerCase();
      final status = (data['paymentStatus'] ?? '').toString().toLowerCase();

      final matchesSearch =
          invNo.contains(_salesSearchQuery) ||
          name.contains(_salesSearchQuery) ||
          phone.contains(_salesSearchQuery);

      if (_statusFilter == 'All') {
        return matchesSearch;
      } else {
        return matchesSearch && status == _statusFilter.toLowerCase();
      }
    }).toList();

    // ফিল্টার হওয়া মেমোগুলোর জন্য লাইভ সামারি হিসাব
    double filteredTotalSum = 0.0;
    double filteredPaidSum = 0.0;
    double filteredDueSum = 0.0;
    int filteredPaidCount = 0;
    int filteredDueOrPartialCount = 0;

    for (var doc in filteredSales) {
      final data = doc.data() as Map<String, dynamic>;
      filteredTotalSum += (data['total'] as num? ?? 0.0).toDouble();
      filteredPaidSum += (data['paidAmount'] as num? ?? 0.0).toDouble();
      filteredDueSum += (data['dueAmount'] as num? ?? 0.0).toDouble();

      final String status = (data['paymentStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (status == 'paid') {
        filteredPaidCount++;
      } else {
        filteredDueOrPartialCount++;
      }
    }

    return Column(
      children: [
        // ডাইনামিক ডেট ফিল্টারিং বার (Today, Month, Year, All Time)
        _buildDateRangeSelectorBar(primaryColor),

        // রেসপনসিভ রিপোর্টিং কার্ডসমূহ (মোট ইনভয়েস ও ওষুধ বিক্রির সংখ্যাসহ)
        _buildStatDashboard(
          totalSales,
          totalReceived,
          totalDue,
          totalDiscount,
          totalInvoicesCount,
          totalMedicineItemsSold,
        ),

        // সার্চ এবং ফিল্টার সেকশন
        _buildSearchAndFilterControls(primaryColor),

        // ডাইনামিক ফিল্টার সামারি ব্যানার (যা টাইপ বা ফিল্টার সিলেক্ট করার সাথে সাথে আপডেট হবে)
        _buildFilteredSummaryBanner(
          filteredCount: filteredSales.length,
          paidCount: filteredPaidCount,
          dueCount: filteredDueOrPartialCount,
          totalBill: filteredTotalSum,
          totalCash: filteredPaidSum,
          totalDue: filteredDueSum,
        ),

        // ইনভয়েসের লাইভ তালিকা
        Expanded(
          child: filteredSales.isEmpty
              ? const Center(
                  child: Text(
                    'No invoice matches your selection.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final doc = filteredSales[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final sellerName = data['soldByName'];

                    final String invoiceNo = data['invoiceNo'] ?? 'N/A';
                    final String customer =
                        data['customerName'] ?? 'Walking Customer';
                    final double total = (data['total'] as num? ?? 0.0)
                        .toDouble();
                    final String paymentStatus =
                        data['paymentStatus'] ?? 'Paid';
                    final timestamp = data['createdAt'] as Timestamp?;

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
                          child: Icon(Icons.receipt, color: primaryColor),
                        ),
                        title: Row(
                          children: [
                            Text(
                              invoiceNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPaymentStatusBadge(paymentStatus),
                          ],
                        ),
                        subtitle: Text(
                          '$customer • ${_formatDate(timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '৳${total.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),

                            Text("Sold by: $sellerName"),
                          ],
                        ),
                        onTap: () => _showInvoiceDetailsDialog(data, docId),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelectorBar(Color primaryColor) {
    final filters = ['Today', 'This Month', 'This Year', 'All Time'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: filters.map((filter) {
          final isSelected = _dateFilter == filter;
          return ChoiceChip(
            label: Text(
              filter,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: primaryColor,
            onSelected: (val) {
              if (val) {
                setState(() {
                  _dateFilter = filter;
                  _updateSalesStream();
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatDashboard(
    double totalSales,
    double totalReceived,
    double totalDue,
    double totalDiscount,
    int totalInvoicesCount,
    int totalMedicineItemsSold,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.count(
            crossAxisCount: isWide ? 6 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: isWide ? 1.8 : 1.3,
            children: [
              _buildStatCard(
                'Total Sales',
                '৳${totalSales.toStringAsFixed(0)}',
                Colors.blue,
                Icons.monetization_on,
              ),
              _buildStatCard(
                'Cash In Hand',
                '৳${totalReceived.toStringAsFixed(0)}',
                Colors.green,
                Icons.check_circle,
              ),
              _buildStatCard(
                'Total Due',
                '৳${totalDue.toStringAsFixed(0)}',
                Colors.red,
                Icons.hourglass_full,
              ),
              _buildStatCard(
                'Discounts',
                '৳${totalDiscount.toStringAsFixed(0)}',
                Colors.purple,
                Icons.percent,
              ),
              _buildStatCard(
                'Total Memo',
                '$totalInvoicesCount টি',
                Colors.indigo,
                Icons.receipt_long_rounded,
              ),
              _buildStatCard(
                'Sold Qty',
                '$totalMedicineItemsSold পিস',
                Colors.orange[800]!,
                Icons.medication_liquid_sharp,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String displayValue,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.08),
              radius: 14,
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterControls(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _salesSearchController,
              decoration: InputDecoration(
                hintText: 'Search by Invoice, Customer or Phone...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _salesSearchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox(),
              items: ['All', 'Paid', 'Due', 'Partial'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _statusFilter = val;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredSummaryBanner({
    required int filteredCount,
    required int paidCount,
    required int dueCount,
    required double totalBill,
    required double totalCash,
    required double totalDue,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF005088).withOpacity(0.05),
        border: Border.all(color: const Color(0xFF005088).withOpacity(0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 16,
                color: Color(0xFF005088),
              ),
              const SizedBox(width: 6),
              Text(
                'ফিল্টার অনুযায়ী ফলাফল: $filteredCount টি মেমো পাওয়া গেছে',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF005088),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBannerSubStat(
                'পরিশোধিত',
                '$paidCount টি',
                Colors.green[800]!,
              ),
              _buildBannerSubStat(
                'বকেয়া/আংশিক',
                '$dueCount টি',
                Colors.red[800]!,
              ),
              _buildBannerSubStat(
                'মোট বিল',
                '৳${totalBill.toStringAsFixed(1)}',
                Colors.black,
              ),
              _buildBannerSubStat(
                'মোট আদায়',
                '৳${totalCash.toStringAsFixed(1)}',
                Colors.green[700]!,
              ),
              _buildBannerSubStat(
                'মোট বাকি',
                '৳${totalDue.toStringAsFixed(1)}',
                Colors.red[700]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSubStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildDueTrackerTab(
    List<QueryDocumentSnapshot> docs,
    double totalDue,
    Color primaryColor,
  ) {
    final filteredDues = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final double dueAmt = (data['dueAmount'] as num? ?? 0.0).toDouble();
      if (dueAmt <= 0) return false;

      final invNo = (data['invoiceNo'] ?? '').toString().toLowerCase();
      final name = (data['customerName'] ?? '').toString().toLowerCase();
      final phone = (data['customerPhone'] ?? '').toString().toLowerCase();

      return invNo.contains(_dueSearchQuery) ||
          name.contains(_dueSearchQuery) ||
          phone.contains(_dueSearchQuery);
    }).toList();

    // ফিল্টার হওয়া বাকি টাকার রিয়্যাল-টাইম যোগফল বের করা হচ্ছে
    double filteredDuesSum = 0.0;
    for (var doc in filteredDues) {
      final data = doc.data() as Map<String, dynamic>;
      filteredDuesSum += (data['dueAmount'] as num? ?? 0.0).toDouble();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _dueSearchController,
            decoration: InputDecoration(
              hintText: 'Search due by Name, Phone or Invoice...',
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _dueSearchQuery = val.trim().toLowerCase();
              });
            },
          ),
        ),

        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red[100]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'বকেয়া পরিমাণ (ফিল্টারকৃত):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
              Text(
                '৳${filteredDuesSum.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredDues.isEmpty
              ? const Center(
                  child: Text(
                    'No outstanding dues found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: filteredDues.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDues[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final String invoiceNo = data['invoiceNo'] ?? 'N/A';
                    final String customer =
                        data['customerName'] ?? 'Walking Customer';
                    final String phone = data['customerPhone'] ?? '';
                    final double dueAmount = (data['dueAmount'] as num? ?? 0.0)
                        .toDouble();
                    final double total = (data['total'] as num? ?? 0.0)
                        .toDouble();

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              customer,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '৳${dueAmount.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Invoice: $invoiceNo • Total Bill: ৳$total\nPhone: $phone',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _showDueCollectionDialog(data, docId),
                          child: const Text(
                            'Collect',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
