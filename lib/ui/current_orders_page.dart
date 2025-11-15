import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// صفحات سابقة عندك
import 'dashboard_page.dart';
import 'shop_profile_page.dart';

// ✅ إضافات للتنقل من الـ bottom bar
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp;

// =======================================================================
// 💡 الدالة المُحسّنة لجلب اسم العميل (أو الجزء الأول من الإيميل)
// =======================================================================
Future<String> _fetchCustomerName(String uid) async {
  if (uid.isEmpty) return 'Customer (No UID)';
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users') // 💡 افتراض اسم المجموعة 'users'
        .doc(uid)
        .get(const GetOptions(source: Source.serverAndCache));

    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>?;

      // 1. الترتيب التفضيلى: Name, ثم DisplayName, ثم Email
      final nameOrEmail = data?['name'] ?? data?['displayName'] ?? data?['email'];

      if (nameOrEmail != null && nameOrEmail.toString().isNotEmpty) {
        final nameString = nameOrEmail.toString();

        // 2. إذا كانت المعلومة تبدو كإيميل، نأخذ الجزء الذي قبل علامة @
        if (nameString.contains('@')) {
          // مثال: 'john.doe@example.com' يُصبح 'john.doe'
          return nameString.split('@').first;
        }

        // 3. إذا كانت اسماً صريحاً (لا يحتوي @)، نعرضه كما هو
        return nameString;
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Error fetching user profile for $uid: $e');
    return 'Customer (Error)';
  }
  return 'Customer (Profile Missing)';
}
// =======================================================================

class CurrentOrdersPage extends StatelessWidget {
  const CurrentOrdersPage({super.key, required this.storeId});
  final String storeId;

  static const kPrimary = Color(0xFF2ECC95);

  @override
  Widget build(BuildContext context) {
    final ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true);

    // 👇 نسمع التغييرات مع metadata حتى نعرف إذا البيانات من الكاش/فيها pendingWrites
    final ordersStream = ordersQuery.snapshots(includeMetadataChanges: true);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Current Orders',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ===== شريط تشخيصي عام للمصدر والكاش =====
          _SnapshotDebugHeader(stream: ordersStream),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ordersStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  // لا يوجد نتائج للمتجر الحالي -> نفحص أحدث الطلبات بدون فلتر
                  return _EmptyWithDiagnosis(storeId: storeId);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data =
                        (d.data() as Map<String, dynamic>?) ?? const {};
                    return _OrderCardCompact(
                      docId: d.id,
                      data: data,
                      pendingWrites: d.metadata.hasPendingWrites,
                      fromCache: d.metadata.isFromCache,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditOrderStatusesPage(storeId: storeId),
                    ));
                  },
                  child: const Text(
                    'Edit statuses',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // ✅ bottom bar
      bottomNavigationBar: _BottomNav(onTap: (i) {
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
        } else if (i == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
          );
        }
      }),
    );
  }
}

//// ================== EditOrderStatusesPage ==================
class EditOrderStatusesPage extends StatelessWidget {
  const EditOrderStatusesPage({super.key, required this.storeId});
  final String storeId;

  static const kPrimary = Color(0xFF2ECC95);

  @override
  Widget build(BuildContext context) {
    final ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true);

    final ordersStream = ordersQuery.snapshots(includeMetadataChanges: true);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit statuses',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyWithDiagnosis(storeId: storeId);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = (d.data() as Map<String, dynamic>?) ?? const {};
              return _OrderCardWithActions(docId: d.id, data: data);
            },
          );
        },
      ),
      bottomNavigationBar: _BottomNav(onTap: (i) {
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
        } else if (i == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
          );
        }
      }),
    );
  }
}

//// ================== Snapshot Debug Header ==================
class _SnapshotDebugHeader extends StatelessWidget {
  const _SnapshotDebugHeader({required this.stream});
  final Stream<QuerySnapshot> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final snap = s.data!;
        final fromCache = snap.metadata.isFromCache;
        final hasPending = snap.docChanges
            .any((c) => c.doc.metadata.hasPendingWrites == true);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: fromCache
              ? const Color(0xFFFFF7E6)
              : (hasPending ? const Color(0xFFEFFAF0) : const Color(0xFFF6F7FB)),
          child: Row(
            children: [
              Icon(
                fromCache
                    ? Icons.cloud_off
                    : (hasPending ? Icons.schedule : Icons.cloud_done),
                size: 18,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromCache
                      ? 'تعرض بيانات من الكاش (قد تتغير بعد تأكيد الخادم)'
                      : (hasPending
                      ? 'هناك تعديلات قيد الإرسال…'
                      : 'بيانات مؤكدة من الخادم'),
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

//// ================== EmptyWithDiagnosis ==================
class _EmptyWithDiagnosis extends StatelessWidget {
  const _EmptyWithDiagnosis({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final diagQuery = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(3);

    return FutureBuilder<QuerySnapshot>(
      future: diagQuery.get(const GetOptions(source: Source.serverAndCache)),
      builder: (_, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('لا توجد طلبات حتى الآن.'));
        }
        final docs = s.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات حتى الآن.'));
        }

        // نفحص الأسباب الشائعة
        final diagnostics = <String>[];
        for (final d in docs) {
          final m = (d.data() as Map<String, dynamic>? ) ?? {};
          final sid = (m['storeId'] ?? '').toString();
          if (sid.isEmpty) {
            diagnostics.add('الطلب ${d.id} بدون storeId → لن يظهر في قائمة المتجر.');
          } else if (sid != storeId) {
            diagnostics.add(
                'الطلب ${d.id} له storeId="$sid" ≠ storeId الحالي="$storeId".');
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('لا توجد طلبات حتى الآن.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              if (diagnostics.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تشخيص محتمل:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      ...diagnostics.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $t',
                            style: const TextStyle(fontSize: 12.5)),
                      )),
                      const SizedBox(height: 6),
                      const Text(
                        'نصيحة: تأكد أن الطلب يُحفَظ مع storeId الصحيح أو فعّل Cloud Function لإلحاق storeId تلقائيًا.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

//// ================== Order Card Compact ==================
class _OrderCardCompact extends StatelessWidget {
  const _OrderCardCompact({
    required this.docId,
    required this.data,
    required this.pendingWrites,
    required this.fromCache,
  });

  final String docId;
  final Map<String, dynamic> data;
  final bool pendingWrites;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    // 🛑 تم إزالة تشخيص اسم العميل القديم

    final idLabel = (data['orderNo']?.toString().padLeft(4, '0')) ?? docId;
    final customerUid = (data['customerUid'] ?? '').toString(); // 💡 جلب الـ UID
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final items = (data['items'] as List?) ?? const [];
    final total = _calcTotal(items);

    // 💡 استخدام FutureBuilder لجلب اسم العميل
    return FutureBuilder<String>(
      future: _fetchCustomerName(customerUid),
      builder: (context, snapshot) {
        final customer = snapshot.data ?? 'Customer'; // الاسم الذي يتم عرضه

        return Container(
          decoration: _box(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Order ID:#$idLabel',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black87)),
                  const Spacer(),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              // 💡 عرض الاسم الذي تم جلبه
              Text(customer,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              for (final it in items.take(3)) _OrderItemTile(item: it as Map),
              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('… +${items.length - 3} more',
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              Text('Total: ${_format(total)}',
                  style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),


            ],
          ),
        );
      },
    );
  }
}

//// ================== Order Card With Actions ==================
class _OrderCardWithActions extends StatelessWidget {
  const _OrderCardWithActions({required this.docId, required this.data});

  final String docId;
  final Map<String, dynamic> data;

  Future<void> _update(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(docId)
          .update({'status': newStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الحالة إلى $newStatus')),
        );
      }
    } catch (_) {
      // ⚠️ هذا هو المكان الذي تظهر فيه رسالة PERMISSION_DENIED
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر التحديث، حاول مجددًا (تحقق من قواعد الأمان)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛑 تم إزالة تشخيص اسم العميل القديم

    final idLabel = (data['orderNo']?.toString().padLeft(4, '0')) ?? docId;
    final customerUid = (data['customerUid'] ?? '').toString(); // 💡 جلب الـ UID
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final items = (data['items'] as List?) ?? const [];
    final total = _calcTotal(items);

    // 💡 استخدام FutureBuilder لجلب اسم العميل
    return FutureBuilder<String>(
      future: _fetchCustomerName(customerUid),
      builder: (context, snapshot) {
        final customer = snapshot.data ?? 'Customer'; // الاسم الذي يتم عرضه

        return Container(
          decoration: _box(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Order ID:#$idLabel',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.black87)),
                  const Spacer(),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              // 💡 عرض اسم العميل
              Text(customer,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              for (final it in items) _OrderItemTile(item: it as Map),
              const SizedBox(height: 8),
              Text('Total: ${_format(total)}',
                  style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),

              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Cancel',
                        color: const Color(0xFFE74C3C),
                        onPressed: () => _update(context, 'canceled'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Confirm',
                        color: const Color(0xFF2ECC71),
                        onPressed: () => _update(context, 'confirmed'),
                      ),
                    ),
                  ],
                )
              else if (status == 'confirmed')
                _ActionButton(
                  label: 'Completed',
                  color: const Color(0xFF3498DB),
                  onPressed: () => _update(context, 'completed'),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}

//// ================== Order Item Tile (الإصدار المُصحَّح والنهائي) ==================
class _OrderItemTile extends StatefulWidget {
  const _OrderItemTile({required this.item});
  final Map item;

  @override
  State<_OrderItemTile> createState() => _OrderItemTileState();
}

class _OrderItemTileState extends State<_OrderItemTile> {
  // 1. تحديد معرّف المنتج واسمه بناءً على التشخيص
  late final String? productIdFromItem;
  late final String productNameFromItem;

  @override
  void initState() {
    super.initState();
    // 💡 تصحيح اسم الحقل: الـ ID كان صحيحاً، لكن الاسم كان 'title'
    productIdFromItem = (widget.item['productId'] ?? widget.item['id'] ?? widget.item['product_id']) as String?;

    // 🔍 التشخيص: نطبع جميع المفاتيح الموجودة في الـ "item" - هذا السطر مهم جداً
    if (kDebugMode) {
      debugPrint('*** DIAGNOSIS - Order Item Keys: ${widget.item.keys.join(', ')}');
      debugPrint('*** DIAGNOSIS - Item Data: ${widget.item.toString()}');
    }

    // 🛑 التعديل لاسم المنتج: إضافة مفاتيح محتملة جديدة
    productNameFromItem = (widget.item['title'] ??
        widget.item['name'] ??
        widget.item['productName'] ??
        widget.item['product_name'] ??
        'Unnamed Product').toString();
  }

  // 2. دالة جلب الصورة الأحدث من المنتج الأصلي
  Future<String> _getUpdatedImageUrl() async {
    // 💡 تصحيح اسم الحقل: الصورة القديمة في الطلب هي 'imageUrl'
    final originalUrl = (widget.item['imageUrl'] ??
        widget.item['product-images'] ??
        widget.item['image'] ?? '') as String;

    if (productIdFromItem == null || productIdFromItem!.isEmpty) {
      debugPrint('*** DEBUG-FAIL: Product ID is MISSING in item. Using old URL: $originalUrl');
      return _cleanUrl(originalUrl);
    }

    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productIdFromItem!)
          .get(const GetOptions(source: Source.server));

      if (!productDoc.exists) {
        debugPrint('*** DEBUG-FAIL: Product document ID: ${productIdFromItem!} DOES NOT EXIST on SERVER.');
        return _cleanUrl(originalUrl);
      }

      final productData = productDoc.data() as Map<String, dynamic>;

      // 🛑 التعديل الحاسم للصورة: نبحث عن أحدث صورة في وثيقة المنتج
      final newImageUrl = productData['imageUrl'] ??
          productData['product-images'] ??
          productData['imgURL'] as String?;

      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        debugPrint('*** DEBUG-SUCCESS-FINAL: Fetched NEW URL for ${productNameFromItem}. URL: $newImageUrl');
        return _cleanUrl(newImageUrl);
      }

      debugPrint('*** DEBUG-FAIL: Product document exists, but imageUrl field is empty or missing. Using old URL.');

    } catch (e) {
      debugPrint('*** DEBUG-CATCH: Server fetch error for ${productIdFromItem!}: $e');
    }

    return _cleanUrl(originalUrl);
  }

  // دالة مساعدة لتنظيف الرابط (نتركها كما هي)
  String _cleanUrl(String url) {
    String cleaned = url.trim();
    if (cleaned.isNotEmpty && !cleaned.startsWith('http')) {
      return 'https://$cleaned';
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // 💡 استخدام الاسم الصحيح
    final name = productNameFromItem;
    final qty = (item['quantity'] ?? item['qty'] ?? 1) as num;
    final price = (item['price'] ?? item['itemPrice'] ?? 0).toDouble();
    final total = price * qty;

    // 3. نستخدم FutureBuilder لجلب الصورة ثم عرضها
    return FutureBuilder<String>(
      future: _getUpdatedImageUrl(),
      builder: (context, snapshot) {
        final img = snapshot.data ?? ''; // الرابط الذي تم جلبه

        // 🔴 سطر التشخيص: للتأكد من الرابط الذي يتم جلبه (سيظهر الآن الاسم الصحيح)
        if (kDebugMode) {
          debugPrint('*** SMART-IMAGE: Product Name: $name | URL: $img | Status: ${snapshot.connectionState}');
        }


        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (snapshot.connectionState == ConnectionState.waiting)
                    ? Container( // حالة الانتظار
                  width: 70, height: 70, color: const Color(0xFFF1F5F9),
                  child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
                    : (img.isNotEmpty
                    ? Image.network( // الصورة النهائية
                  img,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70, height: 70, color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                )
                    : Container( // الصورة فارغة
                  width: 70, height: 70, color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.image_not_supported_outlined),
                )
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name (${qty.toInt()})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('Item Price: ${_format(price)}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Text(_format(total),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

//// ================== Status Chip, Action Button, Store Header, BottomNav, Helpers ==================
// ... (بقية الـ Widgets المساعدة لم يتم تغييرها)

class _StatusChip extends StatelessWidget {
// ... (الكود لا يتغير)
  const _StatusChip({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'pending':
        return const Color(0xFFF1C40F);
      case 'confirmed':
        return const Color(0xFF2ECC71);
      case 'completed':
        return const Color(0xFF3498DB);
      case 'canceled':
      case 'cancelled':
        return const Color(0xFFE74C3C);
      default:
        return Colors.grey;
    }
  }

  String get _label =>
      status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _label,
        style:
        TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.color, required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(storeId)
          .snapshots(),
      builder: (context, snap) {
        String name = 'Store';
        String? logo;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          name = (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name']
              : 'Store';
          logo = data['logoUrl'] as String?;
        }

        final chip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: primary.withOpacity(.15),
              backgroundImage:
              (logo != null && logo!.isNotEmpty) ? NetworkImage(logo!) : null,
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
                style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 6.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShopProfilePage()),
              );
            },
            child: chip,
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.onTap});
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)
          ],
        ),
        child: NavigationBar(
          selectedIndex: 1,
          onDestinationSelected: onTap,
          indicatorColor: Colors.transparent,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _box() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
        color: Colors.black.withOpacity(.05),
        blurRadius: 10,
        offset: const Offset(0, 4))
  ],
);

double _calcTotal(List items) {
  double t = 0;
  for (final raw in items) {
    final it = (raw as Map);
    final qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
    final price = (it['price'] ?? it['itemPrice'] ?? 0).toDouble();
    t += price * qty;
  }
  return t;
}
String _format(num v) => '${v.toStringAsFixed(2)} JD';