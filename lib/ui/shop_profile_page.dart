import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password_page.dart';

class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  static const kPrimary = Color(0xFF34D399);
  static const kBorder = Color(0xFFE5E7EB);
  static const kHint = Color(0xFF9AA0A6);
  static const kText = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = false;
  bool _loadedOnce = false;
  String? _logoUrl;

  final _picker = ImagePicker();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec({
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon != null ? Icon(icon, color: kHint) : null,
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
    );
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final fileName = 'shop_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // ارفع الصورة إلى supabase bucket اسمه "shop-logos"
      final supabase = Supabase.instance.client;
      await supabase.storage.from('shop-logos').upload(fileName, file);

      final publicUrl =
      supabase.storage.from('shop-logos').getPublicUrl(fileName);

      // احفظ الرابط في Firestore
      await FirebaseFirestore.instance.collection('shops').doc(_uid).set({
        'logoUrl': publicUrl,
      }, SetOptions(merge: true));

      setState(() => _logoUrl = publicUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم رفع الشعار بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء رفع الصورة: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(_uid).set({
        'description': _descCtrl.text.trim(),
        'hours': _hoursCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح ✅')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ. حاول مجددًا.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopDocStream =
    FirebaseFirestore.instance.collection('shops').doc(_uid).snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text('Shop Profile',
            style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: shopDocStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = (snap.data?.data() ?? {}) as Map<String, dynamic>;

            if (!_loadedOnce) {
              _nameCtrl.text = data['name'] ?? '';
              _emailCtrl.text = data['email'] ?? '';
              _descCtrl.text = data['description'] ?? '';
              _hoursCtrl.text = data['hours'] ?? '';
              _phoneCtrl.text = data['phone'] ?? '';
              _addressCtrl.text = data['address'] ?? '';
              _logoUrl = data['logoUrl'];
              _loadedOnce = true;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // شعار المتجر
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: kPrimary.withOpacity(.1),
                            backgroundImage: _logoUrl != null
                                ? NetworkImage(_logoUrl!)
                                : null,
                            child: _logoUrl == null
                                ? const Icon(Icons.store, color: kPrimary, size: 40)
                                : null,
                          ),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _pickAndUploadLogo,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child:
                                Icon(Icons.edit, size: 18, color: kPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _nameCtrl,
                      readOnly: true,
                      decoration: _dec(hint: 'Store Name', icon: Icons.store),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _emailCtrl,
                      readOnly: true,
                      decoration: _dec(hint: 'Email', icon: Icons.email),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration:
                      _dec(hint: 'Short Description', icon: Icons.notes),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _hoursCtrl,
                      decoration: _dec(
                          hint: 'Working Hours', icon: Icons.access_time),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _phoneCtrl,
                      decoration:
                      _dec(hint: 'Phone Number', icon: Icons.phone),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration:
                      _dec(hint: 'Address', icon: Icons.location_on),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Update Information',
                          style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
