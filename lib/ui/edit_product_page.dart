import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'dashboard_page.dart';
import 'shop_profile_page.dart';

// ✅ إضافات للتنقل من الـ bottom bar
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp;

class EditProductPage extends StatefulWidget {
  const EditProductPage({
    super.key,
    required this.storeId,
    required this.productId,
    required this.initialData,
  });

  final String storeId;
  final String productId;
  final Map<String, dynamic> initialData;

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  static const kPrimary = Color(0xFF2ECC95);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  String? _currentImageUrl;
  File? _newImageFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    final num? priceNum = d['price'] is num
        ? d['price'] as num
        : num.tryParse('${d['price'] ?? ''}');

    final num qtyNum = (d['quantity'] ?? d['qty'] ?? 0) as num;

    _nameCtrl = TextEditingController(text: (d['name'] ?? d['title'] ?? '').toString());
    _descCtrl = TextEditingController(text: (d['description'] ?? '').toString());
    _priceCtrl = TextEditingController(text: (priceNum ?? 0).toString());
    _qtyCtrl = TextEditingController(text: qtyNum.toString());
    _currentImageUrl = (d['imageUrl'] ?? d['image'] ?? '') as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    hintText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kPrimary, width: 1.4),
    ),
  );

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (x != null) {
        setState(() => _newImageFile = File(x.path));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر اختيار الصورة')));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    final update = <String, dynamic>{
      'name': name,
      'description': desc,
      'price': price,
      'quantity': qty,
    };

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update(update);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر الحفظ، حاول لاحقًا')));
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
      // Inbox → صفحة المحادثات
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerMessagesIndexPage(storeId: widget.storeId),
        ),
      );
    } else if (i == 2) {
      // Reports → صفحة التقارير
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgPreview = _newImageFile != null
        ? Image.file(_newImageFile!, height: 140, fit: BoxFit.cover)
        : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
        ? Image.network(_currentImageUrl!, height: 140, fit: BoxFit.cover)
        : Container(
      height: 140,
      color: const Color(0xFFF1F5F9),
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: const [
          _StoreHeaderChipSmall(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Name', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _dec('Product Name'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 16),

                const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: _dec('Description'),
                ),
                const SizedBox(height: 16),

                const Text('Price', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Price'),
                  validator: (v) =>
                  (double.tryParse(v?.trim() ?? '') == null) ? 'أدخل سعرًا صحيحًا' : null,
                ),
                const SizedBox(height: 16),

                const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Quantity'),
                  validator: (v) =>
                  (int.tryParse(v?.trim() ?? '') == null) ? 'أدخل رقمًا صحيحًا' : null,
                ),
                const SizedBox(height: 16),

                const Text('Product Image', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: imgPreview),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('Upload New Image'),
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      disabledBackgroundColor: kPrimary.withOpacity(.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Save Changes',
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

      // ✅ شريط سفلي (تم تعديل التنقل فقط)
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
    );
  }
}

class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: primary.withOpacity(.15),
                child: Icon(Icons.store, color: primary, size: 16),
              ),
              const SizedBox(height: 2),
              const SizedBox(
                width: 80,
                child: Text(
                  'Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
