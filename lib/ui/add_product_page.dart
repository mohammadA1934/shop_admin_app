import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'shop_profile_page.dart';

// ✅ إضافات للتنقل من الـ bottom bar
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp;

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key, this.storeId});

  /// لو أرسلتها من products_list_page خذها؛ وإلا نستخدم UID الحالي كـ storeId
  final String? storeId;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  static const kPrimary = Color(0xFF2ECC95);
  static const kBorder = Color(0xFFE5E7EB);
  static const kHint = Color(0xFF9AA0A6);
  static const kText = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _addProduct() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final storeId = widget.storeId ?? uid;
    if (storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على المعرّف. أعد تسجيل الدخول.')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final price = double.parse(_priceCtrl.text.trim());
    final qty = int.parse(_qtyCtrl.text.trim());

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('products').add({
        'storeId': storeId,
        'name': name,
        'description': desc,
        'price': price,
        'quantity': qty,
        'inStock': qty > 0,
        'imageUrl': null,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المنتج بنجاح ✅')),
      );

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إضافة المنتج. حاول مجددًا.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Add New Product',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: const [
          _StoreHeaderChipSmall(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product Image', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_outlined, size: 28, color: kHint),
                            SizedBox(height: 6),
                            Text('Tap to upload image', style: TextStyle(color: kHint)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text('Product Name', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _dec('Enter product name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم المنتج' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Product Description', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _dec('Add a short description'),
                  ),
                  const SizedBox(height: 14),

                  const Text('Price', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('0.00'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      final d = double.tryParse(s);
                      if (d == null || d < 0) return 'أدخل سعرًا صالحًا';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('Quantity', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(signed: false),
                    decoration: _dec('0'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      final i = int.tryParse(s);
                      if (i == null || i < 0) return 'أدخل كمية صالحة';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _addProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        disabledBackgroundColor: kPrimary.withOpacity(.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'Add Product',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // ✅ Bottom bar
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8),
            ],
          ),
          child: NavigationBar(
            selectedIndex: 1, // كما هو
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                label: 'Reports',
              ),
            ],
            onDestinationSelected: (i) async {
              if (i == 0) {
                // Home → Dashboard
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                      (_) => false,
                );
              } else if (i == 1) {
                // ✅ Inbox → Customer Messages
                final sid =
                    widget.storeId ?? FirebaseAuth.instance.currentUser?.uid;
                if (sid != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerMessagesIndexPage(storeId: sid),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن فتح الرسائل الآن.')),
                  );
                }
              } else if (i == 2) {
                // ✅ Reports → ReportsPage
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream:
      FirebaseFirestore.instance.collection('shops').doc(uid).snapshots(),
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

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
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
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
