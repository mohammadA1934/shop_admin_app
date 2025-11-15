import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart'; // 💡 لإتاحة kDebugMode

import 'dashboard_page.dart';
import 'shop_profile_page.dart';
import 'reports_page.dart' as rp;

/// ألوان عامة
const _kPrimary = Color(0xFF2ECC95);
const _bubbleMe = Color(0xFFE6F8F1);

// =======================================================================
// 💡 الدالة المصححة التي تقطع الإيميل قبل علامة @
// =======================================================================
String _cleanUserName(String rawName) {
  if (rawName.isEmpty) return 'Customer';

  final name = rawName.trim();

  // 1. التحقق من وجود @
  if (name.contains('@')) {
    // 2. اقتطاع الجزء الأول
    final atIndex = name.indexOf('@');
    final extractedName = name.substring(0, atIndex);

    // 3. التحقق مما إذا كان الجزء المقتطع فارغاً
    if (extractedName.isNotEmpty) {
      return extractedName;
    }
  }

  // 4. إذا لم يكن إيميلاً، نرجع الاسم كما هو
  return name;
}
// =======================================================================

// =======================================================================
// 🎯 دالة جلب الاسم والصورة المحدثة من مجموعة USERS
// =======================================================================
Future<Map<String, String>> _fetchCustomerData(String uid, String fallbackName) async {

  String name = _cleanUserName(fallbackName);
  String avatar = ''; // قيمة مبدئية فارغة للصورة

  // إذا لم يكن لدينا UID، نستخدم الاسم المستعار كحل سريع
  if (uid.isEmpty) return {'name': name, 'avatar': avatar};

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users') // المجموعة التي تحتوي على بيانات المستخدم
        .doc(uid)
        .get(const GetOptions(source: Source.serverAndCache));

    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>?;

      // 1. تحديد الاسم (الأولوية: name, displayName, email)
      final nameOrEmail = data?['name'] ?? data?['displayName'] ?? data?['email'];

      // 2. تحديد رابط الصورة (الأولوية: photoUrl, avatarUrl)
      final avatarUrl = data?['photoUrl'] ?? data?['avatarUrl'] ?? '';

      if (nameOrEmail != null && nameOrEmail.toString().isNotEmpty) {
        final nameString = nameOrEmail.toString();
        // قص الإيميل إذا وجد
        name = nameString.contains('@') ? nameString.split('@').first : nameString;
      }

      // جلب رابط الصورة إذا وجد
      if (avatarUrl.isNotEmpty) {
        avatar = avatarUrl.toString();
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Error fetching user profile for $uid: $e');
  }

  return {'name': name, 'avatar': avatar};
}
// =======================================================================


/// محول آمن لأي قيمة إلى int (يدعم int/bool/num/String)
int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is bool) return v ? 1 : 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// صفحة قائمة المحادثات (Inbox)
class CustomerMessagesIndexPage extends StatelessWidget {
  const CustomerMessagesIndexPage({super.key, required this.storeId});
  final String storeId;

  void _onBottomTap(BuildContext context, int i) {
    if (i == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        // ✅ تم إزالة const
        MaterialPageRoute(builder: (_) => DashboardPage()),
            (_) => false,
      );
    } else if (i == 2) {
      Navigator.of(context).push(
        // ✅ تم إزالة const
        MaterialPageRoute(builder: (_) => rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final convosQuery = FirebaseFirestore.instance
        .collection('conversations')
        .where('storeId', isEqualTo: storeId)
        .orderBy('lastMessageAt', descending: true);

    final convos = convosQuery.snapshots(includeMetadataChanges: true);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inbox'),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: convos,
        builder: (context, s) {
          if (s.hasError) {
            return _ErrorCard(
              title: 'تشخيص محتمل:',
              lines: [
                'حدث خطأ أثناء جلب المحادثات.',
                s.error.toString(),
                'إن كانت الرسالة تطلب Index، أنشئ فهرسًا مركبًا على مجموعة conversations بالحقول:',
                'storeId (Ascending) + lastMessageAt (Descending)',
              ],
            );
          }

          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = s.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد محادثات بعد.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;

              // 🎯 1. نحدد الـ UID والاسم المستعار (حسب ما ظهر في Firebase)
              // تم تعديل ترتيب البحث ليناسب 'customerUid' بالتهجئة الصحيحة.
              final customerUid = (data['customerUid'] ?? data['customerUID'] ?? data['userId'] ?? data['customerId'] ?? '') as String;
              final rawName = (data['userName'] ?? data['customerName'] ?? 'Customer') as String; // نأخذ الاسم المستعار
              final avatar = (data['userAvatar'] ?? '') as String; // الصورة القديمة المخزنة في المحادثة

              final lastText = (data['lastMessageText'] ?? data['lastText'] ?? '') as String;
              final lastTs = ((data['lastMessageAt'] ?? data['lastTimestamp']) as Timestamp?)?.toDate();
              final unread = _asInt(data['unreadForStore']);

              // 💡 استخدام FutureBuilder لجلب الاسم والصورة المحدثة من وثيقة المستخدم (USERS)
              return FutureBuilder<Map<String, String>>(
                future: _fetchCustomerData(customerUid, rawName), // ⬅️ استدعاء الدالة الجديدة
                builder: (context, snapshot) {
                  // الاسم المحدث (أو الاسم المستعار إذا فشل الجلب)
                  final name = snapshot.data?['name'] ?? _cleanUserName(rawName);
                  // الصورة المحدثة (أو الصورة القديمة المخزنة في المحادثة إذا فشل الجلب)
                  final updatedAvatar = snapshot.data?['avatar'] ?? avatar;

                  // 🚨 سطر التشخيص (يمكن حذفه بعد التأكد)
                  if (kDebugMode) debugPrint('Conversation ${d.id}: UID=$customerUid, FetchedName=$name, FetchedAvatar=$updatedAvatar');

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: unread > 0
                            ? const Color(0xFFFEE700)
                            : Colors.transparent,
                      ),
                    ),
                    tileColor: Colors.white,
                    leading: Badge.count(
                      isLabelVisible: unread > 0,
                      count: unread,
                      backgroundColor: const Color(0xFFFEE700),
                      textColor: Colors.black,
                      child: CircleAvatar(
                        backgroundImage:
                        // 💡 استخدام الصورة المحدثة
                        updatedAvatar.isNotEmpty ? NetworkImage(updatedAvatar) : null,
                        child: updatedAvatar.isEmpty ? const Icon(Icons.person) : null,
                      ),
                    ),
                    title: Text(
                      name, // ⬅️ الآن يتم عرض الاسم المقطوع
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      lastText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _timeAgo(lastTs),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    onTap: () {
                      // نرسل الاسم والصورة المحدثة إلى صفحة الدردشة
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerChatPage(
                            storeId: storeId,
                            conversationId: d.id,
                            userName: name,
                            userAvatar: updatedAvatar, // ⬅️ إرسال الصورة المحدثة
                          ),
                        ),
                      );
                    },
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)
            ],
          ),
          child: NavigationBar(
            selectedIndex: 1,
            onDestinationSelected: (i) => _onBottomTap(context, i),
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F7F8),
    );
  }
}

/// صفحة الدردشة
class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({
    super.key,
    required this.storeId,
    required this.conversationId,
    required this.userName, // ✅ هذا الاسم هو الآن الاسم المعالج (بدون @)
    required this.userAvatar, // ✅ هذه الصورة هي الصورة المحدثة
  });

  final String storeId;
  final String conversationId;
  final String userName;
  final String userAvatar;

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final _txt = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ✅ عند فتح المحادثة صفّر عداد المتجر
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'unreadForStore': 0});
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _txt.text.trim();
    if (text.isEmpty) return;

    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    final msgsRef = convRef.collection('msgs');

    // ✅ أضف الرسالة بالحقول المعتمدة في القواعد
    await msgsRef.add({
      'sender': 'store',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ حدّث ملخص المحادثة لظهور الرسالة للطرفين
    await convRef.update({
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForStore': 0,
      'unreadForCustomer': FieldValue.increment(1),
    });

    _txt.clear();
  }

  void _onBottomTap(int i) {
    if (i == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        // ✅ تم إزالة const
        MaterialPageRoute(builder: (_) => DashboardPage()),
            (_) => false,
      );
    } else if (i == 2) {
      Navigator.of(context).push(
        // ✅ تم إزالة const
        MaterialPageRoute(builder: (_) => rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('msgs')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white, // إضافة خلفية بيضاء
              backgroundImage: widget.userAvatar.isNotEmpty
                  ? NetworkImage(widget.userAvatar)
                  : null,
              child: widget.userAvatar.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            // ✅ يتم عرض الاسم المعالج (بدون @) هنا
            Text(widget.userName, style: const TextStyle(fontSize: 16)),
          ],
        ),
        centerTitle: true,
        actions: [
          _StoreHeaderChipSmall(storeId: widget.storeId),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: msgs,
              builder: (context, s) {
                if (s.hasError) {
                  return _ErrorCard(
                    title: 'تشخيص محتمل:',
                    lines: [
                      'تعذر تحميل الرسائل.',
                      s.error.toString(),
                    ],
                  );
                }
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = s.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('ابدأ المحادثة'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    // توافقية مع الحقول القديمة (from)
                    final from = (m['sender'] ?? m['from'] ?? 'user') as String;
                    final text = (m['text'] ?? '') as String;
                    final isMe = from == 'store';
                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? _bubbleMe : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _txt,
            onSend: _send,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)
            ],
          ),
          child: NavigationBar(
            selectedIndex: 1,
            onDestinationSelected: _onBottomTap,
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F7F8),
    );
  }
}

/// ✅ تعريف الـ widget الذي كان مفقود
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        color: const Color(0xFFF5F7F8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSend,
              style: IconButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة أخطاء/تشخيص
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 6),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $l',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// شارة شعار + اسم المتجر (نفس الموجودة عندك)
class _StoreHeaderChipSmall extends StatelessWidget {
  const _StoreHeaderChipSmall({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StreamBuilder<DocumentSnapshot>(
      stream:
      FirebaseFirestore.instance.collection('shops').doc(storeId).snapshots(),
      builder: (context, snap) {
        String name = 'Store';
        String? logo;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          name = (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name']
              : 'Store';
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
              backgroundImage:
              (logo != null && logo!.isNotEmpty) ? NetworkImage(logo!) : null,
              child: (logo == null || logo!.isEmpty)
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
                style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 6.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              // ✅ تم إزالة const
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ShopProfilePage()));
            },
            child: chip,
          ),
        );
      },
    );
  }
}

/// أداة مساعدة لعرض الوقت بشكل مختصر
String _timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}