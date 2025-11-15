import 'dart:async'; // للتحديث الدوري
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// لإنشاء متجر جديد عند عدم وجوده
import 'sign_up_page.dart';
// للعودة إلى شاشة تسجيل الدخول عند تسجيل الخروج
import 'sign_in_page.dart';
// صفحة ملف المتجر
import 'shop_profile_page.dart';
// ✅ صفحة المنتجات
import 'products_list_page.dart';
// ✅ صفحة الطلبات
import 'current_orders_page.dart';
// ✅ صفحة إنشاء العروض (نبدأ باختيار المنتج)
import 'create_promotion_page.dart';
// ✅ صفحات الرسائل الجديدة (قائمة المحادثات)
import 'customer_messages_pages.dart';
// ✅ صفحة التقارير الحقيقية
import 'reports_page.dart' as rp;

// ✅ استيراد صفحة الكوبونات الجديدة
import 'coupons_list_page.dart';

// 🛑 الاستيراد الافتراضي لصفحة الضريبة (إذا كانت في ملف منفصل)
// import 'store_tax_settings_page.dart';
// (تم وضع الكلاس في نهاية هذا الملف لتجنب مشاكل الاستيراد)


/// الـ Dashboard مع الـ Bottom Navigation
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const kPrimary = Color(0xFF2ECC95);
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardHome(), // Home
      const MessagesPage(),   // Inbox (ما زالت Placeholder)
      const ReportsPage(),    // Reports (Placeholder)
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == 0) {
                setState(() => _index = 0);
              } else if (i == 1) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerMessagesIndexPage(storeId: uid),
                    ),
                  );
                }
              } else if (i == 2) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
                );
              }
            },
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: kPrimary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox, color: kPrimary),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart, color: kPrimary),
                label: 'Reports',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  static const kPrimary = Color(0xFF2ECC95);

  Timer? _ticker; // لإعادة البناء دوريًا كي يتغيّر عدّ العروض مع الوقت

  @override
  void initState() {
    super.initState();
    // يحدّث عدّ العروض/الكوبونات حسب الوقت الحالي كل دقيقة
    _ticker = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// نجلب المتجر الخاص بالمستخدم الحالي (Doc ID = UID)
  Future<String?> _loadStoreId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance.collection('shops').doc(uid).get();
    return doc.exists ? doc.id : null;
  }

  /// تسجيل خروج + العودة لصفحة تسجيل الدخول
  Future<void> _signOutToSignIn(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminSignInPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadStoreId(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final storeId = snap.data;

        // لا يوجد متجر -> ندعو المستخدم لإنشاء متجر
        if (storeId == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Store Dashboard'),
              leading: IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => _signOutToSignIn(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_mall_directory, size: 64, color: kPrimary),
                  const SizedBox(height: 12),
                  const Text('لا يوجد متجر مرتبط بحسابك بعد.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminSignUpPage()),
                      );
                    },
                    child: const Text('أنشئ متجرًا الآن'),
                  ),
                ],
              ),
            ),
          );
        }

        // Streams مرتبطة بالمتجر
        final productsStream = FirebaseFirestore.instance
            .collection('products')
            .where('storeId', isEqualTo: storeId)
            .snapshots();

        final pendingOrdersStream = FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: storeId)
            .where('status', isEqualTo: 'pending')
            .snapshots();

        // عدّ العروض النشطة
        final promotionsStream = FirebaseFirestore.instance
            .collection('promotions')
            .where('storeId', isEqualTo: storeId)
            .where('endAt', isGreaterThanOrEqualTo: Timestamp.now())
            .snapshots();

        // عدّ المحادثات غير المقروءة للمتجر
        final unreadConversationsStream = FirebaseFirestore.instance
            .collection('conversations')
            .where('storeId', isEqualTo: storeId)
            .where('unreadForStore', isGreaterThan: 0)
            .snapshots();

        // Stream الكوبونات النشطة - يجلب كل الكوبونات لفلترتها في Dart
        final couponsStream = FirebaseFirestore.instance
            .collection('coupons')
            .where('storeId', isEqualTo: storeId)
            .snapshots();

        // 🛑 Stream جلب قيمة الضريبة (نحتاج إلى DocSnapshot لنفس المتجر)
        final taxStream = FirebaseFirestore.instance
            .collection('shops')
            .doc(storeId)
            .snapshots();


        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => _signOutToSignIn(context),
            ),
            title: const Text(
              'Store Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: const [
              _StoreHeaderChip(),
              SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Total Products
              StreamBuilder<QuerySnapshot>(
                stream: productsStream,
                builder: (context, s) {
                  final count = s.hasData ? s.data!.size : 0;
                  return _StatCard(
                    title: 'Total Products',
                    subtitle: 'View all inventory',
                    value: '$count',
                    color: const Color(0xFFBFD7FF),
                    leadingIcon: Icons.inventory_2_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductsListPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Current Orders
              StreamBuilder<QuerySnapshot>(
                stream: pendingOrdersStream,
                builder: (context, s) {
                  final count = s.hasData ? s.data!.size : 0;
                  return _StatCard(
                    title: 'Current Orders',
                    subtitle: 'Awaiting fulfillment',
                    value: '$count',
                    color: const Color(0xFFCFF8E2),
                    leadingIcon: Icons.attach_money_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CurrentOrdersPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Active Promotions
              StreamBuilder<QuerySnapshot>(
                stream: promotionsStream,
                builder: (context, s) {
                  final now = DateTime.now();
                  final docs = s.data?.docs ?? [];
                  final activeCount = docs.where((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final tsStart = m['startAt'] as Timestamp?;
                    final tsEnd = m['endAt'] as Timestamp?;
                    if (tsStart == null || tsEnd == null) return false;
                    final start = tsStart.toDate();
                    final end = tsEnd.toDate();
                    return !now.isBefore(start) && !now.isAfter(end);
                  }).length;

                  return _StatCard(
                    title: 'Active Promotions',
                    subtitle: 'Create new promotion',
                    value: '$activeCount',
                    color: const Color(0xFFFFE2CF),
                    leadingIcon: Icons.local_offer_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SelectProductForPromotionPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Active Coupons - تطبيق منطق الفلترة الكاملة في Dart
              StreamBuilder<QuerySnapshot>(
                stream: couponsStream,
                builder: (context, s) {
                  int activeCount = 0;

                  if (s.hasData) {
                    final now = DateTime.now(); // جلب الوقت الحالي بالكامل

                    final docs = s.data!.docs;

                    activeCount = docs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final tsStart = m['startAt'] as Timestamp?;
                      final tsEnd = m['endAt'] as Timestamp?;

                      // 1. تعريف وقت البداية والنهاية
                      final start = tsStart?.toDate() ?? DateTime(1900); // تاريخ قديم إذا لم يحدد
                      final end = tsEnd?.toDate() ?? DateTime(9999); // تاريخ بعيد إذا لم يحدد

                      // 2. الشرط النهائي: يجب أن يكون الوقت الحالي ليس قبل البداية (بدأ) AND ليس بعد النهاية (لم ينتهِ).
                      return !now.isBefore(start) && !now.isAfter(end);
                    }).length;
                  }

                  return _StatCard(
                    title: 'Active Coupons',
                    subtitle: 'Create & manage codes',
                    value: '$activeCount',
                    color: const Color(0xFFC7C7FF),
                    leadingIcon: Icons.discount_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CouponsListPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // 🛑 التعديل الثالث: Store Taxes Card
              StreamBuilder<DocumentSnapshot>(
                stream: taxStream,
                builder: (context, s) {
                  double taxRate = 0.0;
                  if (s.hasData && s.data!.exists) {
                    final data = s.data!.data() as Map<String, dynamic>;
                    // تخزن كـ (0.16) ويتم تحويلها للعرض كـ (16.00)
                    taxRate = (data['taxRate'] as num? ?? 0.0) * 100;
                  }

                  final taxDisplay = taxRate.toStringAsFixed(taxRate == taxRate.toInt() ? 0 : 2);

                  return _StatCard(
                    title: 'Store Taxes',
                    subtitle: 'Set store-wide tax rate',
                    value: '$taxDisplay%', // عرض النسبة المئوية
                    color: const Color(0xFFC4DFFF), // لون أزرق فاتح جديد
                    leadingIcon: Icons.percent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          // الانتقال للصفحة الجديدة
                          builder: (_) => StoreTaxSettingsPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),


              // Customer Messages (عدد غير المقروء)
              StreamBuilder<QuerySnapshot>(
                stream: unreadConversationsStream,
                builder: (context, s) {
                  final count = s.hasData ? s.data!.size : 0;
                  return _StatCard(
                    title: 'Customer Messages',
                    subtitle: 'Respond promptly',
                    value: '$count',
                    color: const Color(0xFFE7D5FF),
                    leadingIcon: Icons.chat_bubble_outline,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerMessagesIndexPage(storeId: storeId),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),

              // Recent Activity
              const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('storeId', isEqualTo: storeId)
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final docs = s.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _box(),
                      child: const Text('لا يوجد نشاط حديث حتى الآن.'),
                    );
                  }
                  return Container(
                    decoration: _box(),
                    child: Column(
                      children: [for (final d in docs) _OrderActivityTile(d)],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static BoxDecoration _box() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}

// الكلاسات المساعدة (تبقى كما هي)
class _StoreHeaderChip extends StatelessWidget {
  const _StoreHeaderChip();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(uid).snapshots(),
      builder: (context, snap) {
        String name = 'Store';
        String? logo;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          name = (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] : 'Store';
          logo = data['logoUrl'] as String?;
        }

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 6.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: kToolbarHeight - 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopProfilePage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: primary.withOpacity(.15),
                        backgroundImage: (logo != null && logo.isNotEmpty) ? NetworkImage(logo) : null,
                        child: (logo == null || logo.isEmpty)
                            ? Icon(Icons.store, color: primary, size: 16)
                            : null,
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 80,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.leadingIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final IconData leadingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(leadingIcon, color: Colors.black87),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 13)),
                ],
              ),
            ),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _OrderActivityTile extends StatelessWidget {
  const _OrderActivityTile(this.doc);

  final QueryDocumentSnapshot doc;

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final orderNo = data['orderNo']?.toString() ?? '#';
    final status = (data['status'] as String?) ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;

    Color chipColor;
    switch (status) {
      case 'pending':
        chipColor = const Color(0xFFFFE9A6);
        break;
      case 'shipped':
        chipColor = const Color(0xFFBDE5FF);
        break;
      case 'canceled':
        chipColor = const Color(0xFFFFC9C9);
        break;
      default:
        chipColor = const Color(0xFFE7E7E7);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
      title: Text('Order $orderNo', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_timeAgo(createdAt)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(30)),
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// Placeholders (تبقى كما هي)
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Orders')), body: Center(child: Text('Orders of $storeId')));
  }
}

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key, required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Promotions')), body: Center(child: Text('Promos of $storeId')));
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, this.storeId});
  final String? storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Messages')), body: const Center(child: Text('Messages')));
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(child: Text('Reports')),
    );
  }
}


// =========================================================================
// 🛑 الكلاس الجديد: StoreTaxSettingsPage
// =========================================================================

class StoreTaxSettingsPage extends StatefulWidget {
  const StoreTaxSettingsPage({super.key, required this.storeId});
  final String storeId;

  @override
  State<StoreTaxSettingsPage> createState() => _StoreTaxSettingsPageState();
}

class _StoreTaxSettingsPageState extends State<StoreTaxSettingsPage> {
  final TextEditingController _taxController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  static const kPrimary = Color(0xFF2ECC95); // استخدام لون التطبيق الأساسي

  // جلب قيمة الضريبة الحالية
  Future<void> _fetchTaxRate() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.storeId)
          .get();

      final data = doc.data();
      // يتم تخزينها كنسبة (0.16) ونعرضها كنسبة مئوية (16)
      final rate = (data?['taxRate'] as num? ?? 0.0) * 100;
      _taxController.text = rate.toStringAsFixed(rate == rate.toInt() ? 0 : 2);
    } catch (e) {
      // إظهار رسالة خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tax rate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // حفظ قيمة الضريبة
  Future<void> _saveTaxRate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final ratePercentage = double.parse(_taxController.text);
      // نحول القيمة المدخلة (16) إلى نسبة (0.16) قبل الحفظ
      final taxRate = ratePercentage / 100.0;

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.storeId)
          .update({'taxRate': taxRate});

      // إظهار رسالة نجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax rate updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tax rate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTaxRate();
  }

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Taxes and Fees'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your store-wide tax rate. This percentage will be applied to all product totals at checkout.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _taxController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tax Rate',
                  hintText: 'e.g., 16',
                  suffixText: '% (Percentage)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a tax rate.';
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0 || rate > 100) {
                    return 'Please enter a valid percentage (0-100).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTaxRate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Save Tax Rate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}