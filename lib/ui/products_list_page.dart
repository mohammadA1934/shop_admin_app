import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// صفحات لديك مسبقاً
import 'dashboard_page.dart';
import 'shop_profile_page.dart';

// الصفحات الحقيقية
import 'add_product_page.dart';
import 'edit_product_page.dart';

// ✅ إضافات للتنقّل من الـ Bottom Bar
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp; // لتجنّب تعارض الاسم مع الـ ReportsPage الموجودة بـ dashboard_page.dart

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key, required this.storeId});
  final String storeId;

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  static const kPrimary = Color(0xFF2ECC95);

  // حذف منتج بعد التأكيد
  Future<void> _deleteProduct(String productId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل أنت متأكد من حذف "$name"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المنتج')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف المنتج، حاول مجددًا')),
        );
      }
    }
  }

  // شريط سفلي — الانتقال بين الصفحات
  void _onBottomTap(int i) {
    if (i == 0) {
      // Home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 1) {
      // ✅ Inbox -> صفحة المحادثات
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerMessagesIndexPage(storeId: widget.storeId),
        ),
      );
    } else if (i == 2) {
      // ✅ Reports -> صفحة التقارير الفعلية
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsQuery = FirebaseFirestore.instance
        .collection('products')
        .where('storeId', isEqualTo: widget.storeId)
        .orderBy('name', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Product Inventory',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: widget.storeId),
          const SizedBox(width: 8),
        ],
      ),

      // قائمة المنتجات
      body: StreamBuilder<QuerySnapshot>(
        stream: productsQuery,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد منتجات بعد.\nاضغط + لإضافة أول منتج',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;

              final name = (data['name'] ?? data['title'] ?? 'Unnamed').toString();
              final price = (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
              final qtyNum = (data['quantity'] ?? data['qty'] ?? 0);
              final qty = (qtyNum is num) ? qtyNum.toInt() : 0;
              final imageUrl = (data['imageUrl'] ?? data['image'] ?? '') as String;

              return _ProductCard(
                name: name,
                price: price,
                quantity: qty,
                imageUrl: imageUrl,
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProductPage(
                        storeId: widget.storeId,
                        productId: d.id,
                        initialData: data,
                      ),
                    ),
                  );
                },
                onDelete: () => _deleteProduct(d.id, name),
              );
            },
          );
        },
      ),

      // زر الإضافة +
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddProductPage(storeId: widget.storeId),
            ),
          );
        },
        tooltip: 'إضافة منتج',
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),

      // شريط سفلي
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
          ),
          child: NavigationBar(
            selectedIndex: 0, // إبراز Home
            onDestinationSelected: _onBottomTap,
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inStock = quantity > 0;
    final stockColor = inStock ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final stockLabel = inStock ? 'In Stock' : 'Out of Stock';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 84, height: 84, fit: BoxFit.cover)
                : Container(
              width: 84,
              height: 84,
              color: const Color(0xFFF1F5F9),
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${price.toStringAsFixed(2)} JD', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Available: $quantity',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: stockColor.withOpacity(.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        stockLabel,
                        style: TextStyle(
                          color: stockColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE4E4),
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      stream: FirebaseFirestore.instance.collection('shops').doc(storeId).snapshots(),
      builder: (context, snap) {
        String name = 'Store';
        String? logo;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          name = (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] : 'Store';
          logo = data['logoUrl'] as String?;
        }

        final chip = Container(
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
