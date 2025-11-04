import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// صفحة تغيير كلمة السر اللي أنشأناها سابقًا
import 'change_password_page.dart';

class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  // ألوان موحّدة
  static const kPrimary = Color(0xFF34D399);
  static const kBorder = Color(0xFFE5E7EB);
  static const kHint = Color(0xFF9AA0A6);
  static const kText = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();     // للعرض فقط (readOnly)
  final _emailCtrl = TextEditingController();    // readOnly
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = false;
  bool _loadedOnce = false; // لتعبئة الحقول مرة واحدة من الداتا

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

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  InputDecoration _dec({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon != null ? Icon(icon, color: kHint) : null,
      suffixIcon: suffix,
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(_uid).set({
        // الاسم والإيميل يقرأان من التسجيل، ما نعدّل عليهم هنا
        'description': _descCtrl.text.trim(),
        'hours': _hoursCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث البيانات بنجاح ✅')),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الحفظ. حاول مجددًا.')),
      );
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new, color: kText),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Shop Profile',
          style: TextStyle(
            color: kPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: shopDocStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = (snap.data?.data() ?? {}) as Map<String, dynamic>;

            // مرّة واحدة فقط نعبيّ الكنترولرز من الداتا
            if (!_loadedOnce) {
              _nameCtrl.text = (data['name'] as String?) ?? '';
              _emailCtrl.text = (data['email'] as String?) ?? (FirebaseAuth.instance.currentUser?.email ?? '');
              _descCtrl.text = (data['description'] as String?) ?? '';
              _hoursCtrl.text = (data['hours'] as String?) ?? '';
              _phoneCtrl.text = (data['phone'] as String?) ?? '';
              _addressCtrl.text = (data['address'] as String?) ?? '';
              _loadedOnce = true;
            }

            final logo = (data['logoUrl'] as String?) ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo + edit (لاحقًا نضيف رفع صورة – الآن للعرض فقط)
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: kPrimary.withOpacity(.15),
                              backgroundImage:
                              logo.isNotEmpty ? NetworkImage(logo) : null,
                              child: logo.isEmpty
                                  ? const Icon(Icons.store, color: kPrimary, size: 32)
                                  : null,
                            ),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تغيير الشعار سيتم لاحقًا')),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.edit, size: 18, color: kPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Store Name (read-only)
                      const Text('Store Name', style: TextStyle(color: kText)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        readOnly: true,
                        decoration: _dec(
                          hint: 'Store Name',
                          icon: Icons.store_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email (read-only) + change password link
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Email', style: TextStyle(color: kText)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Change Password',
                              style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _emailCtrl,
                        readOnly: true,
                        decoration: _dec(
                          hint: 'Email',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Short Description
                      const Text('Short Description', style: TextStyle(color: kText)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: _dec(hint: 'Write a short description...', icon: Icons.notes_outlined),
                      ),
                      const SizedBox(height: 14),

                      // Working Hours
                      const Text('Working Hours', style: TextStyle(color: kText)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _hoursCtrl,
                        decoration: _dec(hint: 'e.g. 9 AM - 9 PM', icon: Icons.calendar_today_outlined),
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      const Text('Phone Number', style: TextStyle(color: kText)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(hint: '+962 ...', icon: Icons.phone_outlined),
                        validator: (v) {
                          final x = v?.trim() ?? '';
                          if (x.isEmpty) return null; // اختياري
                          final ok = RegExp(r'^[0-9+\-\s()]{6,}$').hasMatch(x);
                          if (!ok) return 'رقم غير صالح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Address
                      const Text('Address', style: TextStyle(color: kText)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 3,
                        decoration: _dec(hint: 'Address / Location', icon: Icons.location_on_outlined),
                      ),
                      const SizedBox(height: 22),

                      // Update button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            disabledBackgroundColor: kPrimary.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                            'Update Information',
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
            );
          },
        ),
      ),
    );
  }
}
