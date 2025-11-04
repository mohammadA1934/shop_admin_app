import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // نفس نظام الألوان المستخدم سابقًا
  static const kPrimary = Color(0xFF34D399);
  static const kBorder  = Color(0xFFE5E7EB);
  static const kHint    = Color(0xFF9AA0A6);
  static const kText    = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscOld = true;
  bool _obscNew = true;
  bool _obscConf = true;
  bool _loading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, color: kHint),
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

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة (الحد الأدنى 6 أحرف).';
      case 'invalid-credential':
      case 'wrong-password':
        return 'كلمة المرور الحالية غير صحيحة.';
      case 'requires-recent-login':
        return 'لأمان حسابك، سجّل الدخول مجددًا ثم حاول مرة أخرى.';
      case 'network-request-failed':
        return 'مشكلة في الشبكة. تحقق من الإنترنت.';
      default:
        return 'تعذّر تغيير كلمة المرور: ${e.code}';
    }
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على مستخدم مسجّل دخول.')),
      );
      return;
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تغيير كلمة السر لهذا النوع من الحسابات.')),
      );
      return;
    }

    setState(() => _loading = true);

    final oldPass = _oldCtrl.text;
    final newPass = _newCtrl.text;

    try {
      // إعادة التحقق باستخدام البريد/كلمة السر الحالية
      final cred = EmailAuthProvider.credential(email: email, password: oldPass);
      await user.reauthenticateWithCredential(cred);

      // تحديث كلمة المرور
      await user.updatePassword(newPass);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح ✅')),
      );
      Navigator.of(context).pop(); // ارجع للصفحة السابقة
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mapError(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع. حاول مجددًا.')),
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
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new),
          color: kText,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    // Old password
                    TextFormField(
                      controller: _oldCtrl,
                      obscureText: _obscOld,
                      decoration: _dec(
                        hint: 'Old Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _obscOld ? 'إظهار' : 'إخفاء',
                          icon: Icon(
                            _obscOld ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: kHint,
                          ),
                          onPressed: () => setState(() => _obscOld = !_obscOld),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'أدخل كلمة المرور الحالية' : null,
                    ),
                    const SizedBox(height: 14),

                    // New password
                    TextFormField(
                      controller: _newCtrl,
                      obscureText: _obscNew,
                      decoration: _dec(
                        hint: 'New Password',
                        icon: Icons.lock_reset_outlined,
                        suffix: IconButton(
                          tooltip: _obscNew ? 'إظهار' : 'إخفاء',
                          icon: Icon(
                            _obscNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: kHint,
                          ),
                          onPressed: () => setState(() => _obscNew = !_obscNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل كلمة المرور الجديدة';
                        if (v.length < 6) return 'الحد الأدنى 6 أحرف';
                        if (v == _oldCtrl.text) return 'اختر كلمة مرور مختلفة عن الحالية';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm new password
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscConf,
                      decoration: _dec(
                        hint: 'Confirm New Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _obscConf ? 'إظهار' : 'إخفاء',
                          icon: Icon(
                            _obscConf ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: kHint,
                          ),
                          onPressed: () => setState(() => _obscConf = !_obscConf),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل تأكيد كلمة المرور';
                        if (v != _newCtrl.text) return 'كلمتا المرور غير متطابقتين';
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_loading) _changePassword();
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _changePassword,
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
                          'Submit',
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
      ),
    );
  }
}
