import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/screens/expiry_tracker_screen.dart';
import 'package:pharmacy_app/screens/new_sale_screen.dart';
import 'package:pharmacy_app/screens/sales_report_screen.dart';
import 'package:pharmacy_app/screens/stock_category_screen.dart';
import 'package:pharmacy_app/screens/user_login_screen.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  // আজকের শুরু এবং শেষ সময় নির্ধারণ করার ফাংশন
  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Widget _buildStripeCard({
    required String title,
    required String value,
    required Color themeColor,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // বামপাশের রঙের গাঢ় স্ট্রাইপটি (image_d2bb79.png অনুযায়ী)
              Container(width: 6, color: themeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // টেক্সট ইনফরমেশন
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.grey[550],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              value,
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // ডানের সার্কেল আইকন (image_d2bb79.png অনুযায়ী)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: themeColor.withOpacity(0.8),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ড্যাশবোর্ডের কুইক নেভিগেশন বাটন ডিজাইন
  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Firebase থেকে ইউজারকে সাইন আউট করা
      await FirebaseAuth.instance.signOut();

      // সব আগের রুট (routes) ডিলিট করে লগইন স্ক্রিনে পাঠানো
      // যাতে ইউজার ব্যাক বাটনে ক্লিক করে আবার ড্যাশবোর্ডে ফিরে আসতে না পারে
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserLoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005088);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/images/profileimage.png'),
          ),
        ),
        title: Column(
          children: [
            Text(
              'SalesPerson',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              'abc@gmail.com',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ১. সম্ভাষণ ও স্বাগতম সেকশন
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back, SalePerson!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[850],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                // লোগো ব্যাজ
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ২. রিয়াল-টাইম স্ট্যাটিস্টিক কার্ড প্যানেল (image_d2bb79.png এর আদলে তৈরি)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: isWide ? 1.9 : 1.95,
                  children: [
                    // ক) Today's Sales স্ট্রাইপ কার্ড (সবুজ)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('sales')
                          .where(
                            'createdAt',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                              _startOfToday,
                            ),
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        double totalSalesToday = 0.0;
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            totalSalesToday += (data['total'] as num? ?? 0.0)
                                .toDouble();
                          }
                        }
                        return _buildStripeCard(
                          title: "Today's Sales",
                          value:
                              '৳ ${NumberFormat('#,##0').format(totalSalesToday)}',
                          themeColor: const Color(0xFF2E7D32), // গাঢ় সবুজ
                          icon: Icons.attach_money_rounded,
                        );
                      },
                    ),

                    // খ) Out of Stock স্ট্রাইপ কার্ড (লাল)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('medicines')
                          .where('totalStock', isEqualTo: 0)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int outOfStockCount = 0;
                        if (snapshot.hasData) {
                          outOfStockCount = snapshot.data!.docs.length;
                        }
                        return _buildStripeCard(
                          title: "Out of Stock",
                          value: '$outOfStockCount Items',
                          themeColor: const Color(0xFFC62828), // গাঢ় লাল
                          icon: Icons.warning_amber_rounded,
                        );
                      },
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 20),

            // ৩. প্রধান নেভিগেশন সেকশন টাইটেল
            Text(
              'Quick Control Board',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
              ),
            ),
            const SizedBox(height: 12),

            // ৪. ফাংশনাল বাটন গ্রিড প্যানেল
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                return GridView.count(
                  crossAxisCount: isWide ? 6 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: isWide ? 1.0 : 0.85,
                  children: [
                    _buildMenuButton(
                      icon: Icons.point_of_sale_rounded,
                      label: 'POS Counter',
                      color: primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NewSaleScreen(),
                        ),
                      ),
                    ),

                    _buildMenuButton(
                      icon: Icons.assessment_rounded,
                      label: 'Sales & Due',
                      color: Colors.blueAccent[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SalesReportScreen(),
                        ),
                      ),
                    ),
                    _buildMenuButton(
                      icon: Icons.notification_important_rounded,
                      label: 'Stock Alerts',
                      color: Colors.orange[800]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockCategoryScreen(),
                        ),
                      ),
                    ),
                    _buildMenuButton(
                      icon: Icons.gpp_maybe_rounded,
                      label: 'Expiry Alerts',
                      color: Colors.purple[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpiryTrackerScreen(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
