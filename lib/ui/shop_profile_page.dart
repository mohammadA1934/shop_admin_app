import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password_page.dart';
// 🛑 استيراد صفحة إعداد ساعات العمل الجديدة
import 'working_hours_settings_page.dart';

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
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // 🛑 متغير لحالة أوقات العمل ليعرض في الواجهة (للعرض فقط)
  String _workingHoursDisplay = 'Loading...';

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
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec({
    required String hint,
    IconData? icon,
    Widget? suffix,
    bool readOnly = false, // لتحديد نمط القراءة فقط
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon != null ? Icon(icon, color: kHint) : null,
      filled: true,
      // 🛑 تغيير اللون إذا كان readOnly
      fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
      suffixIcon: suffix, // إضافة الأيقونة المساعدة هنا (مثل أيقونة التعديل)
    );
  }

  Future<void> _pickAndUploadLogo() async {
    // ... (هذه الدالة تبقى كما هي إذا كنت تريد إبقاء وظيفة رفع الصور)
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

  // 🛑 دالة مساعدة لتنسيق العرض الحالي لأوقات العمل
  String _getWorkingHoursDisplay(Map<String, dynamic>? workingHours) {
    if (workingHours == null || workingHours.isEmpty) {
      return 'Not set. Tap to configure.';
    }
    final mon = workingHours['Mon'] as Map<String, dynamic>?;
    final sun = workingHours['Sun'] as Map<String, dynamic>?;

    if (mon != null && sun != null) {
      if (mon['start'] == sun['start'] && mon['end'] == sun['end']) {
        return 'Daily: ${mon['start']} - ${mon['end']} (tap to edit)';
      }
      return 'Hours configured. Tap to view/edit.';
    }
    return 'Hours configured. Tap to view/edit.';
  }


  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    // 💡 جلب اسم المتجر الجديد
    final name = _nameCtrl.text.trim();

    try {
      await FirebaseFirestore.instance.collection('shops').doc(_uid).set({
        // 💡 تحديث اسم المتجر في Firestore
        'name': name,
        'description': _descCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح ✅')));
      Navigator.of(context).maybePop();
    } catch (_) {
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
        top: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: shopDocStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = (snap.data?.data() ?? {}) as Map<String, dynamic>;

            final workingHours = data['workingHours'] as Map<String, dynamic>?;
            _workingHoursDisplay = _getWorkingHoursDisplay(workingHours);

            if (!_loadedOnce) {
              _nameCtrl.text = (data['name'] as String?) ?? '';
              _emailCtrl.text = (data['email'] as String?) ?? (FirebaseAuth.instance.currentUser?.email ?? '');
              _descCtrl.text = (data['description'] as String?) ?? '';
              _phoneCtrl.text = (data['phone'] as String?) ?? '';
              _addressCtrl.text = (data['address'] as String?) ?? '';
              _logoUrl = data['logoUrl'];
              _loadedOnce = true;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                    // Store Name (الآن قابل للتعديل)
                    const Text('Store Name', style: TextStyle(color: kText)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      // 💡 تم حذف readOnly: true لتمكين التعديل
                      decoration: _dec(
                        hint: 'Store Name',
                        icon: Icons.store_outlined,
                        // 💡 تم حذف readOnly: true من هنا ليعرض نمط الإدخال العادي
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Email (Read-only) + change password link
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
                      readOnly: true, // ⬅️ الإيميل يبقى للقراءة فقط
                      decoration: _dec(
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        readOnly: true, // نمط القراءة فقط
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Short Description
                    const Text('Description', style: TextStyle(color: kText)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration:
                      _dec(hint: 'Short Description', icon: Icons.notes),
                    ),
                    const SizedBox(height: 14),

                    // Working Hours (الآن هو زر/مؤشر بدل حقل نص)
                    const Text('Working Hours', style: TextStyle(color: kText)),
                    const SizedBox(height: 6),

                    InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkingHoursSettingsPage(storeId: _uid),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _dec(
                          hint: 'Set Hours',
                          icon: Icons.calendar_today_outlined,
                          suffix: const Icon(Icons.edit, color: kPrimary, size: 20),
                        ),
                        child: Text(
                          _workingHoursDisplay,
                          style: TextStyle(
                            color: workingHours == null ? kHint : kText,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text('Phone Number', style: TextStyle(color: kText)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration:
                      _dec(hint: 'Phone Number', icon: Icons.phone),
                    ),
                    const SizedBox(height: 14),

                    // Address
                    const Text('Address', style: TextStyle(color: kText)),
                    const SizedBox(height: 6),
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