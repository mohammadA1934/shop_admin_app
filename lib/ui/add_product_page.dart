import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key, this.storeId});
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
  File? _pickedImage;
  String? _uploadedImageUrl;

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

  /// 📸 اختيار صورة من المعرض
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  /// ☁️ رفع الصورة إلى Supabase
  Future<String?> _uploadImageToSupabase(File file) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final path = 'products/$fileName';

      await supabase.storage.from('product-images').upload(path, file);
      final url = supabase.storage.from('product-images').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return null;
    }
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
      String? imageUrl = _uploadedImageUrl;

      // لو اختار صورة بس ما انرفعت بعد
      if (_pickedImage != null && imageUrl == null) {
        imageUrl = await _uploadImageToSupabase(_pickedImage!);
      }

      await FirebaseFirestore.instance.collection('products').add({
        'storeId': storeId,
        'name': name,
        'description': desc,
        'price': price,
        'quantity': qty,
        'inStock': qty > 0,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت إضافة المنتج بنجاح')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('🔥 Error adding product: $e');
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
        title: const Text('Add New Product', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
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
                    onTap: _pickImage,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(12),
                        image: _pickedImage != null
                            ? DecorationImage(
                          image: FileImage(_pickedImage!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _pickedImage == null
                          ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_outlined, size: 28, color: kHint),
                            SizedBox(height: 6),
                            Text('Tap to upload image', style: TextStyle(color: kHint)),
                          ],
                        ),
                      )
                          : null,
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
