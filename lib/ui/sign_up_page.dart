import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⬅️ بعد التعديل: سننقلك مباشرةً إلى لوحة التحكم
import 'dashboard_page.dart';

class AdminSignUpPage extends StatefulWidget {
  const AdminSignUpPage({super.key});

  @override
  State<AdminSignUpPage> createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends State<AdminSignUpPage> {
  // ألوان موحّدة
  static const kPrimary = Color(0xFF34D399);
  static const kBorder = Color(0xFFE5E7EB);
  static const kHint = Color(0xFF9AA0A6);
  static const kText = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _storeNameCtrl = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();

  bool _obsc1 = true;
  bool _obsc2 = true;
  bool _loading = false;

  // ✅ سيتم تحميل التصنيفات من Firestore (يضيفها الـ Super Admin)
  String? _selectedCat;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

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

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'هذا البريد مستخدم مسبقًا.';
      case 'invalid-email':
        return 'صيغة البريد غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (الحد الأدنى 6 أحرف).';
      case 'operation-not-allowed':
        return 'تم تعطيل الإيميل/باسورد في Firebase.';
      case 'network-request-failed':
        return 'مشكلة بالشبكة. تحقق من الإنترنت.';
      default:
        return 'فشل التسجيل: ${e.code}';
    }
  }

  Future<void> _createStore() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final name  = _storeNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    final phone = _phoneCtrl.text.trim();
    final cat   = _selectedCat!;

    try {
      // 1) إنشاء حساب Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      final uid = cred.user!.uid;

      // (اختياري) تعيين اسم العرض
      await cred.user!.updateDisplayName(name);

      // 2) تخزين معلومات المتجر في Firestore
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('shops').doc(uid).set({
        'ownerUid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'category': cat,
        'createdAt': now,
        'status': 'active',
        'logoUrl': null,
      });

      if (!mounted) return;

      // ✅ بعد النجاح: انتقل مباشرةً إلى لوحة التحكم وامسح سجل التنقّل
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      // إذا فشل حفظ المتجر بعد إنشاء المستخدم، حاول حذف المستخدم لتجنب حسابات يتيمة
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mapAuthError(e))));
    } catch (_) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع أثناء إنشاء المتجر.')),
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
        title: const Text('Create a store'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Name
                  const Text('Store Name', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _storeNameCtrl,
                    decoration: _dec(hint: 'Store Name', icon: Icons.store_outlined),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم المتجر' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const Text('Email', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: _dec(hint: 'Email', icon: Icons.email_outlined),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      final ok = RegExp(
                        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                      ).hasMatch(email);
                      if (!ok) return 'صيغة البريد غير صحيحة';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  const Text('Password', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obsc1,
                    decoration: _dec(
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _obsc1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                        ),
                        onPressed: () => setState(() => _obsc1 = !_obsc1),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                      if (v.length < 6) return 'الحد الأدنى 6 أحرف';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Confirm Password
                  const Text('Confirm Password', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obsc2,
                    decoration: _dec(
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _obsc2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                        ),
                        onPressed: () => setState(() => _obsc2 = !_obsc2),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل التأكيد';
                      if (v != _passCtrl.text) return 'كلمتا المرور غير متطابقتين';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  const Text('Phone number', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec(
                      hint: 'Phone number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) {
                      final x = v?.trim() ?? '';
                      if (x.isEmpty) return null; // اختياري
                      final ok = RegExp(r'^[0-9+\-\s()]{6,}$').hasMatch(x);
                      if (!ok) return 'رقم غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Category (من Firestore)
                  const Text('Store category', style: TextStyle(color: kText)),
                  const SizedBox(height: 6),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('categories')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snap) {
                      final disabled = snap.connectionState == ConnectionState.waiting || snap.hasError;
                      final docs = snap.data?.docs ?? const [];

                      // إن وُجدت قيمة محفوظة ولم تعد ضمن القائمة (تم حذفها مثلاً) فنلغي الاختيار
                      if (docs.indexWhere((d) => (d['name'] ?? '') == _selectedCat) == -1) {
                        // لا نستدعي setState هنا، فقط نتركها كما هي حتى يختار المستخدم
                      }

                      final items = docs
                          .map((d) => (d['name'] ?? '').toString())
                          .where((name) => name.isNotEmpty)
                          .map((name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ))
                          .toList();

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCat,
                        decoration: _dec(
                          hint: disabled ? 'Loading categories...' : 'Select a category',
                        ),
                        items: items,
                        onChanged: disabled ? null : (v) => setState(() => _selectedCat = v),
                        validator: (v) => v == null ? 'اختر تصنيف المتجر' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createStore,
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
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'create Store',
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
      ),
    );
  }
}
