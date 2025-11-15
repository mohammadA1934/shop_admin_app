import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'shop_profile_page.dart'; // لـ _StoreHeaderChipSmall (نفترض وجودها)

/// ---------------------------------------------------------------------------
/// 1) صفحة عرض الكوبونات (CouponsListPage)
/// ---------------------------------------------------------------------------
class CouponsListPage extends StatelessWidget {
  final String storeId;
  const CouponsListPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    // ✅ الاستعلام المُعدَّل: تم حذف .orderBy() لتجنب خطأ Firebase Index
    final couponsStream = FirebaseFirestore.instance
        .collection('coupons')
        .where('storeId', isEqualTo: storeId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        // ✅ النص المُعدَّل: أصبح "Coupon Management"
        title: const Text('Coupon Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2ECC95)),
            tooltip: 'Create New Coupon',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateCouponPage(storeId: storeId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: couponsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          final coupons = snapshot.data?.docs ?? [];
          if (coupons.isEmpty) {
            return const Center(child: Text('No coupons created yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final data = coupons[index].data() as Map<String, dynamic>;
              // 🛑 تمرير couponId إلى _CouponTile
              return _CouponTile(data: data, couponId: coupons[index].id);
            },
          );
        },
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String couponId;
  const _CouponTile({required this.data, required this.couponId});

  // ✅ دالة تنسيق التاريخ اليدوية لحل مشكلة intl
  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // 🛑 دالة حذف الكوبون
  Future<void> _deleteCoupon(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('coupons').doc(couponId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coupon ${data['code']} deleted successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete coupon: $e')),
        );
      }
    }
  }

  // 🛑 دالة عرض نافذة التأكيد
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the coupon "${data['code'] ?? 'N/A'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteCoupon(context); // Perform deletion
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final String code = data['code'] ?? 'N/A';
    // 🛑 التعديل هنا: القراءة من 'discount' بدلاً من 'value'
    // يتم استخدام .toDouble() لضمان أن القيمة رقمية
    final double value = data['discount']?.toDouble() ?? 0.0;
    final String type = data['type'] ?? 'percentage';
    final Timestamp? endTs = data['endAt'] as Timestamp?;
    final Timestamp? startTs = data['startAt'] as Timestamp?;
    final DateTime now = DateTime.now();

    final isExpired = endTs != null && now.isAfter(endTs.toDate());
    final isPending = startTs != null && now.isBefore(startTs.toDate());

    String statusText;
    Color statusColor;

    if (isExpired) {
      statusText = 'Expired 🛑';
      statusColor = Colors.red.shade100;
    }
    else if (isPending) {
      statusText = 'Pending ⏳';
      statusColor = Colors.orange.shade100;
    }
    else {
      statusText = 'Active ✅';
      statusColor = const Color(0xFFCFF8E2);
    }

    String valueDisplay = type == 'percentage' ? '$value %' : '${value.toStringAsFixed(2)} JD';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
          child: Text(statusText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        title: Text(
          code,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2ECC95)),
        ),
        subtitle: Text(
          'Discount: $valueDisplay\nExpires: ${_formatDate(endTs)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        // 🛑 إضافة سلة الحذف
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: () => _showDeleteConfirmationDialog(context),
        ),
        onTap: () {
          // يمكن إضافة صفحة لتعديل الكوبون هنا
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2) صفحة إنشاء كوبون جديد (CreateCouponPage)
/// (لم يتم تعديلها بناءً على الطلب)
/// ---------------------------------------------------------------------------

class CreateCouponPage extends StatefulWidget {
  final String storeId;
  const CreateCouponPage({super.key, required this.storeId});

  @override
  State<CreateCouponPage> createState() => _CreateCouponPageState();
}

class _CreateCouponPageState extends State<CreateCouponPage> {
  static const kPrimary = Color(0xFF2ECC95);

  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  String _type = 'percentage';
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ⚠ يتم تعيين تاريخ البداية افتراضياً على اليوم، وهذا مهم ليعمل العداد مباشرة
    _start = DateTime.now();
    _end = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {IconData? icon, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
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

  Future<void> _saveCoupon() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final valueText = _valueCtrl.text.trim().replaceAll(',', '.');
    final code = _codeCtrl.text.trim();
    // 💡 نضمن أن القيمة رقمية قبل الإرسال
    final value = double.tryParse(valueText);

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid discount value')),
      );
      return;
    }

    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }
    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('coupons').add({
        'storeId': widget.storeId,
        'code': code.toUpperCase(),
        'discount': value, // ✅ التعديل الحاسم: تم تغيير المفتاح من 'value' إلى 'discount'
        'type': _type,
        'startAt': Timestamp.fromDate(
          DateTime(_start!.year, _start!.month, _start!.day, 0, 0, 0),
        ),
        'endAt': Timestamp.fromDate(
          DateTime(_end!.year, _end!.month, _end!.day, 23, 59, 59),
        ),
        'applyTo': 'all',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coupon created successfully!')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to save coupon')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save coupon, try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select Date';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Coupon')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coupon Code', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeCtrl,
                  decoration: _dec('e.g., SAVE10'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v!.trim().isEmpty ? 'Code is required' : null,
                ),
                const SizedBox(height: 18),

                const Text('Discount Value and Type', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _type,
                        decoration: _dec('Type'),
                        items: const [
                          DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (JD)')),
                        ],
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _valueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec(
                          'Discount Value',
                          suffixText: _type == 'percentage' ? '%' : 'JD',
                        ),
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Value is required';
                          if (double.tryParse(v.replaceAll(',', '.')) == null ||
                              double.tryParse(v.replaceAll(',', '.'))! <= 0) return 'Invalid value';
                          return null;
                        },
                      ),
                    ),
                  ],
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
                          child: Text(_formatDate(_start)),
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
                          child: Text(_formatDate(_end)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveCoupon,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Save and Create Coupon',
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
      backgroundColor: const Color(0xFFF5F7F8),
    );
  }
}