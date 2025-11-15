import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WorkingHoursSettingsPage extends StatefulWidget {
  final String storeId;
  const WorkingHoursSettingsPage({super.key, required this.storeId});

  @override
  State<WorkingHoursSettingsPage> createState() => _WorkingHoursSettingsPageState();
}

class _WorkingHoursSettingsPageState extends State<WorkingHoursSettingsPage> {
  static const kPrimary = Color(0xFF2ECC95);
  bool _isLoading = true;
  bool _isSaving = false;

  // 1=Mon, ..., 7=Sun (كما في DateFormat)، لكن هنا سنستخدم مفاتيح نصية
  final List<String> _days = ['Sun', 'Mon', 'Tue', 'Weh', 'Thu', 'Fri', 'Sat'];

  // هيكل البيانات: Map<Day, {start, end, status}>
  Map<String, Map<String, dynamic>> _hoursData = {};

  @override
  void initState() {
    super.initState();
    _initializeHours();
    _fetchWorkingHours();
  }

  // تهيئة البيانات الافتراضية لكل الأيام
  void _initializeHours() {
    for (var day in _days) {
      _hoursData[day] = {
        'start': '09:00',
        'end': '17:00',
        'status': 'open',
      };
    }
  }

  // جلب البيانات من Firebase
  Future<void> _fetchWorkingHours() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.storeId)
          .get();

      final data = doc.data();
      final firestoreHours = data?['workingHours'] as Map<String, dynamic>?;

      if (firestoreHours != null) {
        setState(() {
          // دمج البيانات المجلوبة مع الهيكل الافتراضي
          for (var day in _days) {
            final dayData = firestoreHours[day] as Map<String, dynamic>?;
            if (dayData != null) {
              _hoursData[day] = {
                'start': dayData['start'] ?? '09:00',
                'end': dayData['end'] ?? '17:00',
                'status': dayData['status'] ?? 'open',
              };
            }
          }
        });
      }
    } catch (e) {
      print('Error fetching working hours: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // حفظ البيانات إلى Firebase
  Future<void> _saveWorkingHours() async {
    if (!_validateHours()) return;
    setState(() => _isSaving = true);

    // تجهيز البيانات للحفظ (للتأكد من أننا نحفظ فقط البيانات المطلوبة)
    final Map<String, Map<String, String>> dataToSave = {};
    _hoursData.forEach((day, data) {
      dataToSave[day] = {
        'start': data['start'] as String,
        'end': data['end'] as String,
        'status': data['status'] as String,
      };
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.storeId)
          .set({'workingHours': dataToSave}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Working hours updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save hours: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // التحقق من أن وقت النهاية بعد وقت البداية إذا كان المتجر مفتوحاً
  bool _validateHours() {
    for (var day in _days) {
      final data = _hoursData[day]!;
      if (data['status'] == 'open') {
        final start = data['start'] as String;
        final end = data['end'] as String;

        // التحقق البسيط: "17:00" > "09:00"
        if (start.compareTo(end) >= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: End time must be after start time for $day.')),
          );
          return false;
        }
      }
    }
    return true;
  }

  // دالة لاختيار الوقت (ساعة ودقيقة)
  Future<void> _pickTime(String day, bool isStart) async {
    final initialTime = TimeOfDay.fromDateTime(
      DateTime.parse('2023-01-01T${isStart ? _hoursData[day]!['start'] : _hoursData[day]!['end']}'),
    );

    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          _hoursData[day]!['start'] = timeString;
        } else {
          _hoursData[day]!['end'] = timeString;
        }
      });
    }
  }

  // دالة لنسخ أوقات يوم معين إلى كل الأيام المفتوحة
  void _copyToAll(String sourceDay) {
    setState(() {
      final sourceData = _hoursData[sourceDay]!;
      for (var day in _days) {
        // ننسخ فقط إذا كان المتجر مفتوحًا في اليوم المصدر
        if (sourceData['status'] == 'open') {
          _hoursData[day]!['start'] = sourceData['start'];
          _hoursData[day]!['end'] = sourceData['end'];
          _hoursData[day]!['status'] = sourceData['status'];
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hours copied to all open days.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Working Hours Setup'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _days.length,
              itemBuilder: (context, index) {
                final day = _days[index];
                final data = _hoursData[day]!;
                final isOpen = data['status'] == 'open';

                return _DayHourRow(
                  day: day,
                  data: data,
                  isOpen: isOpen,
                  onToggle: (v) {
                    setState(() {
                      data['status'] = v ? 'open' : 'closed';
                    });
                  },
                  onPickStart: () => _pickTime(day, true),
                  onPickEnd: () => _pickTime(day, false),
                  onCopy: () => _copyToAll(day),
                );
              },
            ),
          ),
          // زر الحفظ
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWorkingHours,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Save Working Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Widget مساعد لعرض إعدادات اليوم الواحد
// -----------------------------------------------------------
class _DayHourRow extends StatelessWidget {
  final String day;
  final Map<String, dynamic> data;
  final bool isOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onCopy;

  const _DayHourRow({
    required this.day,
    required this.data,
    required this.isOpen,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onCopy,
  });

  static const kPrimary = Color(0xFF2ECC95);
  static const kBorder = Color(0xFFE5E7EB);

  // دالة لعرض مربع الوقت
  Widget _timeBox(BuildContext context, String time, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        children: [
          Row(
            children: [
              // اسم اليوم
              SizedBox(
                width: 70,
                child: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              // زر تبديل الفتح/الإغلاق
              Switch(
                value: isOpen,
                onChanged: onToggle,
                activeColor: kPrimary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // حقول الوقت
          Row(
            children: [
              // زر النسخ (مخفي إذا كان مغلقاً)
              if(isOpen)
                IconButton(
                  icon: const Icon(Icons.content_copy_rounded, color: Colors.blueGrey, size: 20),
                  tooltip: 'Copy to all open days',
                  onPressed: onCopy,
                ),
              const SizedBox(width: 8),

              // وقت البداية
              _timeBox(context, data['start']!, onPickStart),

              const SizedBox(width: 10),

              const Text('to', style: TextStyle(color: Colors.grey)),

              const SizedBox(width: 10),

              // وقت النهاية
              _timeBox(context, data['end']!, onPickEnd),
            ],
          ),

          if (!isOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Store is closed all day on $day.',
                style: TextStyle(color: Colors.red.shade400, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}