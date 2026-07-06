import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpiryTrackerScreen extends StatefulWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Expired', 'Expiring Soon'
  DateTime? _customExpiryLimitDate; // কাস্টম তারিখ ফিল্টার করার ভেরিয়েবল
  
  final TextEditingController _searchController = TextEditingController();
  late Stream<QuerySnapshot> _medicinesStream;

  @override
  void initState() {
    super.initState();
    // লাইফ সাইকেলে স্ট্রিমটি একবার সাবস্ক্রাইব করে রাখা হলো যাতে রি-রেন্ডারে কি-বোর্ড ফোকাস নষ্ট না হয়
    _medicinesStream = FirebaseFirestore.instance.collection('medicines').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // একটি ব্যাচের মেয়াদ কেমন অবস্থায় আছে তা বের করার লজিক
  String _getExpiryStatus(DateTime expiryDate) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expiringSoonLimit = today.add(const Duration(days: 90)); // আগামী ৯০ দিন

    if (expiryDate.isBefore(today)) {
      return 'Expired';
    } else if (expiryDate.isBefore(expiringSoonLimit)) {
      return 'Expiring Soon';
    } else {
      return 'Safe';
    }
  }

  // কতদিন মেয়াদ বাকি আছে বা কতদিন আগে শেষ হয়েছে তা চমৎকারভাবে হিসাব করার ফাংশন
  String _getDaysRemainingText(DateTime expiryDate) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final int difference = expDateOnly.difference(today).inDays;

    if (difference < 0) {
      return 'মেয়াদ শেষ হয়েছে ${difference.abs()} দিন আগে';
    } else if (difference == 0) {
      return 'আজকেই মেয়াদ শেষ!';
    } else {
      return '$difference দিন বাকি আছে';
    }
  }

  // মেয়াদ অনুযায়ী ব্যাচের চমৎকার রঙের ব্যাকগ্রাউন্ড তৈরি
  Color _getStatusColor(String status, DateTime expiryDate) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final int difference = expDateOnly.difference(today).inDays;

    if (difference < 0) {
      return Colors.red[700]!;
    } else if (difference <= 90) {
      return Colors.orange[800]!;
    } else {
      return Colors.green[700]!;
    }
  }

  // মেয়াদ শেষ হয়ে যাওয়া ব্যাচ সম্পূর্ণ ডিসপোজ বা বাদ দেওয়ার লজিক (নিরাপদ ট্রানজেকশন)
  Future<void> _disposeExpiredBatch(
    BuildContext context, 
    String docId, 
    String medicineName, 
    Map<String, dynamic> targetBatch
  ) async {
    final bool? confirmDispose = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red[700], size: 28),
              const SizedBox(width: 8),
              const Text('Confirm Dispose'),
            ],
          ),
          content: Text(
            'আপনি কি নিশ্চিতভাবে "$medicineName" এর ব্যাচ "${targetBatch['batchNo']}" বাতিল (Dispose) করতে চান?\n\n'
            'এতে করে ডাটাবেসের ওই ব্যাচের অবশিষ্ট ${targetBatch['stock']} পিস ওষুধ ধ্বংস/বাতিল হয়ে যাবে এবং মোট স্টক সমন্বয় হবে।',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm Dispose', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmDispose == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('medicines').doc(docId);

        await firestore.runTransaction((transaction) async {
          final docSnapshot = await transaction.get(docRef);
          if (!docSnapshot.exists) throw Exception('Medicine not found!');

          final data = docSnapshot.data() as Map<String, dynamic>;
          final List<dynamic> dbBatches = List.from(data['batches'] as List<dynamic>? ?? []);
          int totalStock = (data['totalStock'] as num? ?? 0).toInt();

          // নির্দিষ্ট ব্যাচটি খুঁজে বের করে স্টক রিডিউস করা হচ্ছে
          int targetIndex = dbBatches.indexWhere((b) => b['batchNo'] == targetBatch['batchNo']);
          if (targetIndex != -1) {
            int batchStock = (dbBatches[targetIndex]['stock'] as num? ?? 0).toInt();
            
            // ব্যাচটি লিস্ট থেকে সম্পূর্ণ রিমুভ করে দেওয়া হবে
            dbBatches.removeAt(targetIndex);
            
            // মোট স্টক থেকে ওই ব্যাচের পরিমাণ বিয়োগ করা হবে
            totalStock = totalStock - batchStock;
            if (totalStock < 0) totalStock = 0;

            transaction.update(docRef, {
              'batches': dbBatches,
              'totalStock': totalStock,
            });
          }
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batch ${targetBatch['batchNo']} of $medicineName successfully disposed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Disposal failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Expiry Tracker & Alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _medicinesStream,
        builder: (context, snapshot) {
          // রিয়্যাল-টাইম টাইপিংয়ের সময় পেজ ঝাঁকুনি দেওয়া রোধে Smart ConnectionState পরীক্ষা
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading inventory: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          // ডেটা প্রসেসিং এবং মেয়াদের হিসাব নিকাশ
          int expiredBatchesCount = 0;
          int expiringSoonBatchesCount = 0;
          double potentialLoss = 0.0;
          
          // ভিউ লিস্টের জন্য ফ্ল্যাট লিস্ট তৈরি করা হচ্ছে যেখানে প্রতিটি আইটেম একটি সিঙ্গেল ব্যাচ দেখাবে
          final List<Map<String, dynamic>> allActiveBatches = [];

          for (var doc in docs) {
            final medData = doc.data() as Map<String, dynamic>;
            final String medId = doc.id;
            final String name = medData['name'] ?? 'N/A';
            final String generic = medData['genericName'] ?? 'N/A';
            final String category = medData['category'] ?? 'N/A';
            final List<dynamic> batches = medData['batches'] as List<dynamic>? ?? [];

            for (var b in batches) {
              final batchMap = Map<String, dynamic>.from(b as Map);
              final Timestamp? expTimestamp = batchMap['expiryDate'] as Timestamp?;
              if (expTimestamp == null) continue;

              final DateTime expDate = expTimestamp.toDate();
              final String status = _getExpiryStatus(expDate);
              final int stock = (batchMap['stock'] as num? ?? 0).toInt();
              final double buyingPrice = (batchMap['buyingPrice'] as num? ?? 0.0).toDouble();

              // শুধুমাত্র স্টকে থাকা সক্রিয় ওষুধের মেয়াদ ট্র্যাক হবে
              if (stock > 0) {
                if (status == 'Expired') {
                  expiredBatchesCount++;
                  potentialLoss += (buyingPrice * stock);
                } else if (status == 'Expiring Soon') {
                  expiringSoonBatchesCount++;
                }

                allActiveBatches.add({
                  'medicineId': medId,
                  'name': name,
                  'genericName': generic,
                  'category': category,
                  'batchNo': batchMap['batchNo'],
                  'stock': stock,
                  'buyingPrice': buyingPrice,
                  'sellingPrice': (batchMap['sellingPrice'] as num? ?? 0.0).toDouble(),
                  'expiryDate': expDate,
                  'status': status,
                  'fullMap': batchMap,
                });
              }
            }
          }

          // সার্চ, চিপস এবং কাস্টম লিমিট তারিখ অনুযায়ী ব্যাচ ফিল্টার
          final filteredBatches = allActiveBatches.where((item) {
            final nameMatches = item['name'].toString().toLowerCase().contains(_searchQuery) ||
                                item['genericName'].toString().toLowerCase().contains(_searchQuery);
            
            // কাস্টম তারিখ ফিল্টারিং (যদি সিলেক্ট করা থাকে)
            bool dateMatches = true;
            if (_customExpiryLimitDate != null) {
              final DateTime expDate = item['expiryDate'] as DateTime;
              // সিলেক্টেড ডেটের সমান বা তার আগের ডেটে এক্সপায়ার হওয়া প্রোডাক্টগুলো
              dateMatches = expDate.isBefore(_customExpiryLimitDate!.add(const Duration(days: 1)));
            }

            bool statusMatches = true;
            if (_statusFilter != 'All') {
              statusMatches = item['status'] == _statusFilter;
            }

            return nameMatches && dateMatches && statusMatches;
          }).toList();

          // কাস্টম ডেট সিলেক্ট করা থাকলে কাস্টম সম্ভাব্য লোকসান হিসাব করা
          double customLossSum = 0.0;
          for (var item in filteredBatches) {
            final DateTime expDate = item['expiryDate'] as DateTime;
            final DateTime now = DateTime.now();
            final DateTime today = DateTime(now.year, now.month, now.day);
            if (expDate.isBefore(today)) {
              customLossSum += (item['buyingPrice'] as double) * (item['stock'] as int);
            }
          }

          // মেয়াদ অনুযায়ী সর্টিং (সবচেয়ে আগে Expired এবং Expiring Soon ব্যাচগুলো উপরে দেখাবে)
          filteredBatches.sort((a, b) => (a['expiryDate'] as DateTime).compareTo(b['expiryDate'] as DateTime));

          return Column(
            children: [
              // ড্যাশবোর্ড প্যানেল
              _buildMetricDashboard(
                expiredBatchesCount, 
                expiringSoonBatchesCount, 
                _customExpiryLimitDate != null ? customLossSum : potentialLoss,
                _customExpiryLimitDate != null,
              ),

              // সার্চ ও ফিল্টার কন্ট্রোলস
              _buildSearchAndFilters(primaryColor),

              // ডাইনামিক ফিল্টারকৃত সামারি ব্যানার
              _buildFilteredResultBanner(filteredBatches.length),

              // ব্যাচগুলোর ইনফরমেশন লিস্ট
              Expanded(
                child: filteredBatches.isEmpty
                    ? const Center(
                        child: Text('No batches matches your selection.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredBatches.length,
                        itemBuilder: (context, index) {
                          final item = filteredBatches[index];
                          final DateTime expDate = item['expiryDate'] as DateTime;
                          final formattedExpDate = DateFormat('dd MMM yyyy').format(expDate);
                          final color = _getStatusColor(item['status'], expDate);
                          final daysText = _getDaysRemainingText(expDate);

                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // বামপাশে মেয়াদের আইকন ব্যাজ
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item['status'] == 'Expired' 
                                          ? Icons.gpp_bad_rounded 
                                          : (item['status'] == 'Expiring Soon' ? Icons.warning_amber_rounded : Icons.verified_user_rounded), 
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // ওষুধ ও ব্যাচ ডিটেইলস
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['name'], 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            _buildStatusBadge(item['status'], color),
                                          ],
                                        ),
                                        Text('${item['genericName']} • ${item['category']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'Batch: ${item['batchNo']}', 
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Stock: ${item['stock']} pcs', 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[850], fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // ডাইনামিক দিন গণনার সুন্দর টেক্সট
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            daysText,
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Expiry Date: $formattedExpDate', 
                                          style: TextStyle(
                                            color: Colors.grey[600], 
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // অ্যাকশন বাটন (মেয়াদোত্তীর্ণ হলে তাৎক্ষণিক বাতিল করার সুবিধা)
                                  if (item['status'] == 'Expired')
                                    IconButton(
                                      icon: Icon(Icons.delete_sweep, color: Colors.red[700]),
                                      tooltip: 'Dispose Expired Stock',
                                      onPressed: () => _disposeExpiredBatch(
                                        context, 
                                        item['medicineId'], 
                                        item['name'], 
                                        item['fullMap']
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
    );
  }

  Widget _buildMetricDashboard(int expiredCount, int expiringSoonCount, double potentialLoss, bool isCustomDateActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return GridView.count(
            crossAxisCount: isWide ? 3 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: isWide ? 2.2 : 1.3,
            children: [
              _buildMetricCard('Expired', '$expiredCount Batches', Colors.red, Icons.gpp_bad_rounded),
              _buildMetricCard('Expiring Soon', '$expiringSoonCount Batches', Colors.orange[800]!, Icons.warning_amber_rounded),
              _buildMetricCard(
                isCustomDateActive ? 'Loss (Filter)' : 'Potential Loss', 
                '৳${potentialLoss.toStringAsFixed(0)}', 
                Colors.purple, 
                Icons.trending_down
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color color, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.08),
              radius: 15,
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              title, 
              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              val, 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[850]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(Color primaryColor) {
    final formattedCustomDate = _customExpiryLimitDate != null 
        ? DateFormat('dd MMM yyyy').format(_customExpiryLimitDate!) 
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medicine by name or generic...',
              prefixIcon: Icon(Icons.search, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                _searchQuery = val.trim().toLowerCase(); // সার্চ কোয়েরি কেস-ইনসেনসিটিভ করা হলো
              });
            },
          ),
          const SizedBox(height: 10),

          // কাস্টম তারিখ ফিল্টারিং প্যানেল
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'তারিখ অনুযায়ী মেয়াদ চেক করুন:',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedCustomDate != null 
                            ? '$formattedCustomDate এর মধ্যে এক্সপায়ার হবে' 
                            : 'যেকোনো কাস্টম তারিখ নির্বাচন করুন...',
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: formattedCustomDate != null ? Colors.teal[800] : Colors.black
                        ),
                      ),
                    ],
                  ),
                ),
                if (_customExpiryLimitDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    tooltip: 'Reset Custom Date',
                    onPressed: () {
                      setState(() {
                        _customExpiryLimitDate = null;
                      });
                    },
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.edit_calendar, size: 14),
                  label: const Text('তারিখ বাছুন', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _customExpiryLimitDate ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
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
                          child: child ?? const SizedBox(),
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _customExpiryLimitDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // চিপস ফিল্টার (শুধুমাত্র কাস্টম তারিখ নিষ্ক্রিয় থাকলে চিপস কাজ করবে)
          if (_customExpiryLimitDate == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['All', 'Expired', 'Expiring Soon'].map((filter) {
                final isSelected = _statusFilter == filter;
                return ChoiceChip(
                  label: Text(
                    filter, 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )
                  ),
                  selected: isSelected,
                  selectedColor: primaryColor,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _statusFilter = filter;
                      });
                    }
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFilteredResultBanner(int count) {
    final hasCustomDate = _customExpiryLimitDate != null;
    final dateString = hasCustomDate ? DateFormat('dd MMM yyyy').format(_customExpiryLimitDate!) : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF005088).withOpacity(0.05),
        border: Border.all(color: const Color(0xFF005088).withOpacity(0.12)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF005088)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasCustomDate 
                  ? 'আজ থেকে $dateString এর মধ্যে $count টি ব্যাচ মেয়াদোত্তীর্ণ হবে।'
                  : 'মেয়াদ অনুযায়ী ফিল্টারে $count টি ব্যাচ পাওয়া গেছে।',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF005088)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }
}