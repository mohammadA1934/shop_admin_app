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
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {}); // يحدّث عدّ العروض حسب الوقت الحالي
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

        // ✅ عدّ العروض النشطة: شرط endAt >= now في الاستعلام،
        // ثم نفلتر startAt <= now على الكلاينت.
        final promotionsStream = FirebaseFirestore.instance
            .collection('promotions')
            .where('storeId', isEqualTo: storeId)
            .where('endAt', isGreaterThanOrEqualTo: Timestamp.now())
            .snapshots();

        // ✅ عدّ المحادثات غير المقروءة للمتجر
        final unreadConversationsStream = FirebaseFirestore.instance
            .collection('conversations')
            .where('storeId', isEqualTo: storeId)
            .where('unreadForStore', isGreaterThan: 0)
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
                        backgroundImage: (logo != null && logo!.isNotEmpty) ? NetworkImage(logo!) : null,
                        child: (logo == null || logo!.isEmpty)
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

// Placeholders القديمة تبقى كما هي بالأسفل
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
