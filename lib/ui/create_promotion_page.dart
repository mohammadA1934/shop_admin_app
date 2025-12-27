import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


// Note: Ensure these imports match your project structure
import 'dashboard_page.dart';
import 'customer_messages_pages.dart';
import 'reports_page.dart' as rp;

/// ---------------------------------------------------------------------------
/// PROMOTION MANAGEMENT SYSTEM - COMPLETE MODULE
/// ---------------------------------------------------------------------------

class SelectProductForPromotionPage extends StatefulWidget {
  const SelectProductForPromotionPage({super.key, required this.storeId});
  final String storeId;

  @override
  State<SelectProductForPromotionPage> createState() => _SelectProductForPromotionPageState();
}

class _SelectProductForPromotionPageState extends State<SelectProductForPromotionPage> {
  static const Color kPrimary = Color(0xFF2ECC95);
  static const Color kBackground = Color(0xFFF8FAFC);
  String _searchQuery = "";

  void _onBottomTap(int i) {
    if (i == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 1) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CustomerMessagesIndexPage(storeId: widget.storeId)));
    } else if (i == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const rp.ReportsPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('storeId', isEqualTo: widget.storeId)
        .snapshots();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productsStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimary));
                }

                var docs = snap.data?.docs ?? [];

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final name = d['name'].toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;
                    return _buildProductTile(d.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Select Product',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      centerTitle: true,
      actions: [
        _StoreHeaderChipSmall(storeId: widget.storeId),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: kBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(String id, Map<String, dynamic> data) {
    final String name = data['name'] ?? 'Unknown';
    final double price = (data['price'] ?? 0.0).toDouble();
    final String img = data['imageUrl'] ?? '';
    final bool hasPromo = data['hasDiscount'] ?? false;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePromotionPage(
            storeId: widget.storeId,
            productId: id,
            productName: name,
            productImageUrl: img,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img.isNotEmpty
                    ? Image.network(img, width: 70, height: 70, fit: BoxFit.cover)
                    : Container(width: 70, height: 70, color: kBackground, child: const Icon(Icons.image, color: Colors.grey)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('$price JD', style: TextStyle(color: hasPromo ? Colors.grey : kPrimary, fontWeight: FontWeight.w600)),
                    if (hasPromo)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Active Promo', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No products found', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_filled, 'Home', 0),
            _navItem(Icons.chat_bubble_outline, 'Inbox', 1),
            _navItem(Icons.analytics_outlined, 'Reports', 2),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () => _onBottomTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: index == 0 ? kPrimary : Colors.grey),
          Text(label, style: TextStyle(color: index == 0 ? kPrimary : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// CREATE PROMOTION PAGE - SMART MANAGEMENT
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
  static const Color kPrimary = Color(0xFF2ECC95);
  final _formKey = GlobalKey<FormState>();
  final _percentCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isProcessing = false;
  String _formatDateManual(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }
  @override
  void dispose() {
    _percentCtrl.dispose();
    super.dispose();
  }

  /// ✅ Logic: Reset Price to Original
  Future<void> _handleRemovePromotion() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('products').doc(widget.productId);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final double originalPrice = (data['oldPrice'] ?? data['price']).toDouble();

        await docRef.update({
          'price': originalPrice,
          'hasDiscount': false,
          'discountPercent': 0,
          'discountExpiry': null,
          'discountStart': null,
          'oldPrice': originalPrice,
        });

        if (mounted) {
          _showToast('Promotion cleared successfully', Colors.green);
        }
      }
    } catch (e) {
      _showToast('Error: Failed to clear promotion', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// ✅ Smart UI Monitor: Checks for expiry in real-time
  Widget _buildSmartPromotionMonitor() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('products').doc(widget.productId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();

        final data = snap.data!.data() as Map<String, dynamic>;
        final bool active = data['hasDiscount'] ?? false;
        final Timestamp? expiry = data['discountExpiry'] as Timestamp?;

        // AUTO-RESET LOGIC
        if (active && expiry != null) {
          if (DateTime.now().isAfter(expiry.toDate())) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _handleRemovePromotion());
            return _buildAlertBox('Promotion Expired. Reverting price...', Colors.orange);
          }
        }

        if (!active) {
          return _buildAlertBox('No active promotion for this product.', Colors.blue);
        }

        return _buildActivePromoCard(data, expiry);
      },
    );
  }

  Widget _buildAlertBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActivePromoCard(Map<String, dynamic> data, Timestamp? expiry) {
    final double percent = (data['discountPercent'] ?? 0).toDouble();
    final double oldPrice = (data['oldPrice'] ?? 0).toDouble();
    final double newPrice = (data['price'] ?? 0).toDouble();
    final String dateStr = expiry != null ? _formatDateManual(expiry.toDate()) : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Promotion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(8)),
                child: Text('$percent% OFF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              _priceCol('Old Price', '$oldPrice JD', isStriked: true),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              _priceCol('New Price', '$newPrice JD', isBold: true),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expires On', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              TextButton.icon(
                onPressed: _handleRemovePromotion,
                icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                label: const Text('Cancel Promotion', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _priceCol(String label, String price, {bool isStriked = false, bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isStriked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            price,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
              decoration: isStriked ? TextDecoration.lineThrough : null,
              color: isStriked ? Colors.red.shade300 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPromotion() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startDate == null || _endDate == null) {
      _showToast('Please select start and end dates', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final double discountPercent = double.parse(_percentCtrl.text.trim());
      final productRef = FirebaseFirestore.instance.collection('products').doc(widget.productId);

      final snap = await productRef.get();
      final data = snap.data()!;

      // Calculate based on Original Price
      final double currentPrice = (data['price'] ?? 0).toDouble();
      final double savedOriginal = (data['oldPrice'] ?? currentPrice).toDouble();
      final bool alreadyDiscounted = data['hasDiscount'] ?? false;

      final double basePrice = alreadyDiscounted ? savedOriginal : currentPrice;
      final double calculatedNewPrice = basePrice - (basePrice * (discountPercent / 100));

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Product
      batch.update(productRef, {
        'price': calculatedNewPrice,
        'oldPrice': basePrice,
        'hasDiscount': true,
        'discountPercent': discountPercent,
        'discountStart': Timestamp.fromDate(_startDate!),
        'discountExpiry': Timestamp.fromDate(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)),
      });

      // 2. Log to Promotions Collection
      final promoId = FirebaseFirestore.instance.collection('promotions').doc().id;
      batch.set(FirebaseFirestore.instance.collection('promotions').doc(promoId), {
        'storeId': widget.storeId,
        'productId': widget.productId,
        'productName': widget.productName,
        'percent': discountPercent,
        'newPrice': calculatedNewPrice,
        'endAt': Timestamp.fromDate(_endDate!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showToast('System Error: Try again later', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Promotion Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleProductHeader(),
              const SizedBox(height: 24),
              _buildSmartPromotionMonitor(),

              const Text('Discount Percentage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _percentCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('e.g. 15', Icons.percent),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 24),
              const Text('Promotion Validity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _datePickerTile('Start Date', _startDate, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _datePickerTile('End Date', _endDate, false)),
                ],
              ),

              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleProductHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(widget.productImageUrl, width: 60, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        ],
      ),
    );
  }

  Widget _datePickerTile(String label, DateTime? value, bool isStart) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => isStart ? _startDate = d : _endDate = d);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value == null ? 'Select Date' : _formatDateManual(value),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _submitPromotion,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('ACTIVATE PROMOTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    );
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

/// ---------------------------------------------------------------------------
/// STORE HEADER CHIP COMPONENT
/// ---------------------------------------------------------------------------

class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(storeId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final name = snap.data!['name'] ?? 'Store';
        final logo = snap.data!['logoUrl'] ?? '';

        return Chip(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade200),
          avatar: logo.isNotEmpty
              ? CircleAvatar(backgroundImage: NetworkImage(logo))
              : const Icon(Icons.store, size: 16),
          label: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}