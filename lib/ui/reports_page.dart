import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'dashboard_page.dart';
import 'customer_messages_pages.dart';
import 'shop_profile_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const kPrimary = Color(0xFF2ECC95);

  Future<String?> _loadStoreId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance.collection('shops').doc(uid).get();
    return doc.exists ? doc.id : null;
  }

  void _onBottomTap(BuildContext context, int i, String storeId) {
    if (i == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerMessagesIndexPage(storeId: storeId),
        ),
      );
    }
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
        if (storeId == null) {
          return const Scaffold(body: Center(child: Text('لا يوجد متجر لهذا الحساب.')));
        }

        final ordersStream = FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: storeId)
            .snapshots();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Shop Reports',
                style: TextStyle(fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              _StoreHeaderChipSmall(storeId: storeId),
              const SizedBox(width: 8),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: ordersStream,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = s.data?.docs ?? [];

              num sumOrderTotal(Map<String, dynamic> m) {
                num total =
                (m['grandTotal'] ?? m['total'] ?? m['totalPrice'] ?? 0) as num;
                if (total == 0 && m['items'] is List) {
                  for (final it in (m['items'] as List)) {
                    final price = (it['price'] ?? 0) as num;
                    final qty = (it['qty'] ?? it['quantity'] ?? 1) as num;
                    total += price * qty;
                  }
                }
                return total;
              }

              final now = DateTime.now();
              final totalOrders = docs.length;

              num totalSales = 0;
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final status = (m['status'] ?? '').toString().toLowerCase();
                if (status == 'completed' || status == 'confirmed') {
                  totalSales += sumOrderTotal(m);
                }
              }

              final List<DateTime> months = List.generate(
                6,
                    (i) {
                  final dt = DateTime(now.year, now.month - (5 - i));
                  return DateTime(dt.year, dt.month, 1);
                },
              );
              final List<num> monthly = List.filled(6, 0);
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final status = (m['status'] ?? '').toString().toLowerCase();
                final ts = m['createdAt'] as Timestamp?;
                if (ts == null) continue;
                final dt = ts.toDate();
                if (status != 'completed' && status != 'confirmed') continue;

                final monthKey = DateTime(dt.year, dt.month, 1);
                final idx = months.indexWhere(
                        (x) => x.year == monthKey.year && x.month == monthKey.month);
                if (idx != -1) {
                  monthly[idx] += sumOrderTotal(m);
                }
              }

              // ---- Status distribution (counts) ----
              int p = 0, c = 0, comp = 0, canc = 0;
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final st = (m['status'] ?? '').toString().toLowerCase();
                if (st == 'pending') p++;
                else if (st == 'confirmed') c++;
                else if (st == 'completed') comp++;
                else if (st == 'canceled' || st == 'cancelled') canc++;
              }
              final int sumStatuses = p + c + comp + canc;

              // 🚀 التعديل: تجميع المنتجات حسب ID
              final Map<String, _TopItem> topMap = {};
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final st = (m['status'] ?? '').toString().toLowerCase();
                if (st != 'completed' && st != 'confirmed') continue;
                if (m['items'] is! List) continue;
                for (final it in (m['items'] as List)) {
                  // 💡 جلب Product ID (للحصول على الصورة والاسم الحديث)
                  final productId = (it['productId'] ?? it['id'] ?? '').toString();
                  if (productId.isEmpty) continue;

                  // 💡 جلب الاسم القديم (كاسم احتياطي)
                  final name = (it['name'] ?? it['title'] ?? 'Unnamed').toString();
                  final qty = (it['qty'] ?? it['quantity'] ?? 1) as num;

                  // استخدام الـ ID كمفتاح في الـ Map
                  topMap.putIfAbsent(productId, () => _TopItem(productId, name, 0));
                  topMap[productId] = topMap[productId]!.copyWith(qty: topMap[productId]!.qty + qty);
                }
              }
              final topList = topMap.values.toList()
                ..sort((a, b) => b.qty.compareTo(a.qty));
              final top3 = topList.take(3).toList();


              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _StatBigCard(
                    leading: Icons.attach_money_rounded,
                    title: '${totalSales.toStringAsFixed(2)} JD',
                    subtitle: 'Total sales',
                  ),
                  const SizedBox(height: 12),

                  _StatBigCard(
                    leading: Icons.inventory_2_outlined,
                    title: '$totalOrders',
                    subtitle: 'Total orders',
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Sales Performance',
                    subtitle: 'Revenue over the last six months',
                    child: SizedBox(
                      height: 160,
                      child: CustomPaint(
                        painter: _LineChartPainter(
                          data: monthly.map((e) => e.toDouble()).toList(),
                          strokeColor: kPrimary,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: months
                                .map((m) {
                              final lab =
                                  '${m.month.toString().padLeft(2, '0')}/${m.year % 100}';
                              return Text(lab,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54));
                            })
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Order status Distribution (Donut) ----
                  _SectionCard(
                    title: 'Order status Distribution',
                    subtitle: 'Breakdown of orders by status',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: sumStatuses == 0
                              ? const Center(
                            child: Text('لا توجد بيانات حالات بعد.'),
                          )
                              : Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: _DonutChartPainter(
                                  values: [
                                    p.toDouble(),
                                    c.toDouble(),
                                    comp.toDouble(),
                                    canc.toDouble(),
                                  ],
                                  colors: const [
                                    Color(0xFFFFA726), // Pending
                                    Color(0xFF22C55E), // Confirmed
                                    Color(0xFF3B82F6), // Completed
                                    Color(0xFFEF4444), // Canceled
                                  ],
                                  strokeWidth: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _LegendDot(
                                color: Color(0xFFFFA726), label: 'Pending'),
                            _LegendDot(
                                color: Color(0xFF22C55E), label: 'Confirmed'),
                            _LegendDot(
                                color: Color(0xFF3B82F6), label: 'Completed'),
                            _LegendDot(
                                color: Color(0xFFEF4444), label: 'Canceled'),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Top selling products',
                    child: Column(
                      children: [
                        for (final t in top3)
                        // ✅ استخدام الـ Widget الجديد لجلب الاسم والصورة الحديثين
                          _TopProductTile(topItem: t, cleanUrlHelper: _cleanUrl),
                        if (top3.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('لا توجد مبيعات حتى الآن.'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.05), blurRadius: 8)
                ],
              ),
              child: NavigationBar(
                selectedIndex: 2,
                onDestinationSelected: (i) => _loadStoreId().then((sid) {
                  if (sid != null) _onBottomTap(context, i, sid);
                }),
                indicatorColor: Colors.transparent,
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
                  NavigationDestination(
                      icon: Icon(Icons.bar_chart), label: 'Reports'),
                ],
              ),
            ),
          ),
          backgroundColor: const Color(0xFFF5F7F8),
        );
      },
    );
  }
}

// ====== Painters, UI helpers, and Models ======

// 💡 الكلاس الجديد الذي يجلب البيانات الحديثة
class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.topItem, required this.cleanUrlHelper});
  final _TopItem topItem;
  final String Function(String?) cleanUrlHelper;

  // 🚀 الدالة تجلب الاسم والصورة الحديثين
  Future<Map<String, String?>> _fetchCurrentData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(topItem.productId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // جلب الاسم الحديث، الاحتياطي هو الاسم القديم
        final name = (data['name'] ?? data['title'] ?? topItem.name).toString();

        // جلب الصورة الحديثة
        final img = (data['product-images'] ?? data['imageUrl'] ?? data['image'] ?? data['productImage'] ?? data['photoUrl'] ?? '') as String?;

        return {'name': name, 'image': img};
      }
      // إذا لم يتم العثور على الوثيقة، نرجع الاسم القديم والصورة null
      return {'name': topItem.name, 'image': null};
    } catch (e) {
      debugPrint('Error fetching live product data for ${topItem.productId}: $e');
      return {'name': topItem.name, 'image': null};
    }
  }

  // دالة مساعدة لتقليل تكرار كود Placeholder
  Widget _buildPlaceholder(IconData? icon, {bool loading = false}) {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: loading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Icon(icon, color: Colors.black54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _fetchCurrentData(),
      builder: (context, snapshot) {

        // 🚀 استخدام الاسم الحديث (أو القديم كاحتياطي)
        final currentName = snapshot.data?['name'] ?? topItem.name;
        // 🚀 استخدام الصورة الحديثة
        final imageUrl = cleanUrlHelper(snapshot.data?['image']);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (imageUrl.isNotEmpty)
                ? Image.network(
              imageUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(Icons.broken_image_outlined),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildPlaceholder(null, loading: true);
              },
            )
                : _buildPlaceholder(Icons.image_not_supported_outlined),
          ),
          title: Text(currentName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${topItem.qty} units sold'),
          trailing: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        );
      },
    );
  }
}


class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.data, this.strokeColor = Colors.teal});
  final List<double> data;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = (data.reduce(math.max)).clamp(1.0, double.infinity);
    const minV = 0.0;

    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2 - 18;
    final dx = w / (data.length - 1);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final norm = (data[i] - minV) / (maxV - minV);
      final x = pad + dx * i;
      final y = pad + (1 - norm) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final grid = Paint()
      ..color = Colors.grey.withOpacity(.2)
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = pad + h * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(pad + w, y), grid);
    }

    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.data != data;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.colors,
    this.strokeWidth = 20,
  });

  final List<double> values; // raw counts
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;

    final shortest = math.min(size.width, size.height);
    final radius = (shortest - strokeWidth) / 2;
    if (radius <= 0) return;

    // background ring
    final bg = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bg);

    final double total = values.fold<double>(0, (p, c) => p + c);
    if (total <= 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * (2 * math.pi);
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) =>
      old.values != values || old.colors != colors || old.strokeWidth != strokeWidth;
}

class _StatBigCard extends StatelessWidget {
  const _StatBigCard({
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final IconData leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leading, color: Colors.black87),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF9AA0A6))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// 💡 تم التعديل: يحمل الآن productId والاسم القديم كاسم احتياطي
class _TopItem {
  final String productId;
  final String name; // الاسم القديم (كاحتياطي)
  final num qty;
  _TopItem(this.productId, this.name, this.qty);
  _TopItem copyWith({String? productId, String? name, num? qty}) =>
      _TopItem(productId ?? this.productId, name ?? this.name, qty ?? this.qty);
}

class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(storeId).snapshots(),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopProfilePage()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              ]),
            ),
          ),
        );
      },
    );
  }
}

// 💡 دالة مساعدة لتنظيف الرابط وإضافة البروتوكول
String _cleanUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  String cleaned = url.trim();
  // التأكد من أن الرابط يبدأ بـ http/https
  if (cleaned.isNotEmpty && !cleaned.startsWith('http')) {
    // يمكن أن يكون الرابط بدون البروتوكول في بعض قواعد البيانات، لذا نضيف https
    return 'https://$cleaned';
  }
  return cleaned;
}