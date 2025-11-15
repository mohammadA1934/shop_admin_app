import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'shop_profile_page.dart';
// ✅ إضافات للتنقل من الـ bottom bar
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp;

/// ---------------------------------------------------------------------------
/// 1) صفحة اختيار المنتج الذي سننشئ له خصم
/// ---------------------------------------------------------------------------
class SelectProductForPromotionPage extends StatelessWidget {
  const SelectProductForPromotionPage({super.key, required this.storeId});
  final String storeId;

  static const kPrimary = Color(0xFF2ECC95);

  void _onBottomTap(BuildContext context, int i) {
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
  }

  @override
  Widget build(BuildContext context) {
    final productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .orderBy('name')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Product'),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: productsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد منتجات في المتجر.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? 'Unnamed').toString();
              final price = (data['price'] ?? 0).toDouble();
              final img = (data['imageUrl'] ?? data['image'] ?? '') as String;

              return ListTile(
                contentPadding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.white,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: img.isNotEmpty
                      ? Image.network(img, width: 58, height: 58, fit: BoxFit.cover)
                      : Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${price.toStringAsFixed(2)} JD'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreatePromotionPage(
                        storeId: storeId,
                        productId: d.id,
                        productName: name,
                        productImageUrl: img,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
          ),
          child: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (i) => _onBottomTap(context, i),
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F7F8),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2) صفحة إنشاء الخصم (Percentage فقط) + تواريخ + كود خصم
/// ---------------------------------------------------------------------------
class CreatePromotionPage extends StatefulWidget {
  const CreatePromotionPage({
    super.key,
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
  });

  final String storeId;
  final String productId;
  final String productName;
  final String productImageUrl;

  @override
  State<CreatePromotionPage> createState() => _CreatePromotionPageState();
}

class _CreatePromotionPageState extends State<CreatePromotionPage> {
  static const kPrimary = Color(0xFF2ECC95);

  final _formKey = GlobalKey<FormState>();
  final _percentCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void dispose() {
    _percentCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
    );
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final base = _start ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _end ?? base,
      firstDate: base,
      lastDate: DateTime(base.year + 5),
    );
    if (d != null) setState(() => _end = d);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار تاريخ البداية والنهاية')),
      );
      return;
    }
    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد البداية')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً')),
      );
      return;
    }

    setState(() => _saving = true);

    final percentText = _percentCtrl.text.trim().replaceAll(',', '.');
    final percent = double.tryParse(percentText);
    if (percent == null || percent <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل نسبة خصم صحيحة')),
      );
      return;
    }
    final code = _codeCtrl.text.trim();

    final data = {
      'storeId': uid,
      'productId': widget.productId,
      'productName': widget.productName,
      'imageUrl': widget.productImageUrl,
      'percent': percent,
      'startAt': Timestamp.fromDate(
        DateTime(_start!.year, _start!.month, _start!.day, 0, 0, 0),
      ),
      'endAt': Timestamp.fromDate(
        DateTime(_end!.year, _end!.month, _end!.day, 23, 59, 59),
      ),
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('promotions').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الخصم بنجاح')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      debugPrint('PROMO_SAVE_FIREBASE_ERROR: ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذّر حفظ الخصم')),
      );
    } catch (e, st) {
      debugPrint('PROMO_SAVE_ERROR: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الخصم، حاول مجددًا')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ✅ تعديل التنقل في الـ bottom bar فقط
  void _onBottomTap(int i) {
    if (i == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerMessagesIndexPage(storeId: widget.storeId),
        ),
      );
    } else if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create New Promotion'),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: p.storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقة المنتج
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: p.productImageUrl.isNotEmpty
                            ? Image.network(
                          p.productImageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 70,
                          height: 70,
                          color: const Color(0xFFF1F5F9),
                          child:
                          const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Text('Percentage (%)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _percentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('e.g., 20'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    final x = double.tryParse(t.replaceAll(',', '.'));
                    if (x == null) return 'أدخل نسبة صحيحة';
                    if (x <= 0 || x > 90) return 'النسبة بين 1 و 90';
                    return null;
                  },
                ),

                const SizedBox(height: 18),
                const Text('Validity Period',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStart,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _dec('Start Date', icon: Icons.event),
                          child: Text(
                            _start == null
                                ? 'اختر التاريخ'
                                : '${_start!.year}-${_start!.month.toString().padLeft(2, '0')}-${_start!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEnd,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _dec('End Date', icon: Icons.event),
                          child: Text(
                            _end == null
                                ? 'اختر التاريخ'
                                : '${_end!.year}-${_end!.month.toString().padLeft(2, '0')}-${_end!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Text('Promotion Code (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _dec('Enter code here...'),
                ),

                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
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
                      'Save Promotion',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)],
          ),
          child: NavigationBar(
            selectedIndex: 0,
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
      backgroundColor: const Color(0xFFF5F7F8),
    );
  }
}

/// ---------------------------------------------------------------------------
/// شارة شعار + اسم المتجر — للركن العلوي الأيمن
/// ---------------------------------------------------------------------------
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
