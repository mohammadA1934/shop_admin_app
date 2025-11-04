import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'shop_profile_page.dart';
import 'reports_page.dart' as rp; // ⬅️ لفتح صفحة التقارير

/// ألوان عامة
const _kPrimary = Color(0xFF2ECC95);
const _bubbleMe = Color(0xFFE6F8F1);

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
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final convosQuery = FirebaseFirestore.instance
        .collection('conversations')
        .where('storeId', isEqualTo: storeId)
    // ✅ استخدم الحقول المتوافقة مع القواعد
        .orderBy('lastMessageAt', descending: true);

    // نسمع مع metadata لنتجنب فترات “الفراغ” المؤقتة
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
          // 👇 عرض أي أخطاء (مثل نقص index أو صلاحيات)
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
              final name = (data['userName'] ?? 'Customer') as String;
              final avatar = (data['userAvatar'] ?? '') as String;
              // توافقية: دعم حقول قديمة إن وُجدت
              final lastText =
              (data['lastMessageText'] ?? data['lastText'] ?? '') as String;
              final lastTs =
              ((data['lastMessageAt'] ?? data['lastTimestamp']) as Timestamp?)
                  ?.toDate();
              // ✅ التحويل الآمن بدل cast مباشر لـ int
              final unread = _asInt(data['unreadForStore']);

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundImage:
                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  lastText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeAgo(lastTs),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerChatPage(
                        storeId: storeId,
                        conversationId: d.id,
                        userName: name,
                        userAvatar: avatar,
                      ),
                    ),
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
    required this.userName,
    required this.userAvatar,
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
        MaterialPageRoute(builder: (_) => const DashboardPage()),
            (_) => false,
      );
    } else if (i == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const rp.ReportsPage()),
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
              backgroundImage: widget.userAvatar.isNotEmpty
                  ? NetworkImage(widget.userAvatar)
                  : null,
              child: widget.userAvatar.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
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
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ShopProfilePage()));
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
