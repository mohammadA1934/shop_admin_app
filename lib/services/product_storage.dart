// lib/services/product_storage.dart
import 'dart:io' show File;        // لمنصات الموبايل/الديسكتوب
import 'dart:typed_data';          // للويب (رفع bytes)
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// اسم البكت في Supabase
const _bucket = 'product-images';

/// كلاس مساعد لإدارة صور المنتجات داخل:
/// product-images/<storeId>/products/<filename>
class ProductStorage {
  ProductStorage._();

  static final SupabaseClient _sb = Supabase.instance.client;

  /// يبني المسار القياسي داخل البكت
  static String _buildPath({
    required String storeId,
    required String fileName,
  }) =>
      '$storeId/products/$fileName';

  /// يُنشئ اسم ملف آمن بناءً على الامتداد
  static String _genFileName(String originalName) {
    final ext = p.extension(originalName).replaceFirst('.', '').toLowerCase();
    final safeExt = (ext.isEmpty) ? 'png' : ext;
    final id = _sb.auth.currentUser?.id ?? DateTime.now().millisecondsSinceEpoch;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'p_${id}_${ts}.$safeExt';  // <-- هنا المشكلة كانت id_ صارت id
  }


  /// رفع ملف (Android/iOS/Desktop)
  /// يعيد المسار داخل البكت (مثال: store123/products/...)
  static Future<String> uploadFile({
    required String storeId,
    required File file,
    String? overrideName,
  }) async {
    final name = overrideName ?? _genFileName(file.path);
    final path = _buildPath(storeId: storeId, fileName: name);

    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

    await _sb.storage.from(_bucket).upload(
      path,
      file,
      fileOptions: FileOptions(cacheControl: '3600', contentType: mime),
    );

    return path;
  }

  /// رفع Bytes (مفيد للويب)
  static Future<String> uploadBytes({
    required String storeId,
    required Uint8List bytes,
    required String originalName,
    String? overrideName,
  }) async {
    final name = overrideName ?? _genFileName(originalName);
    final path = _buildPath(storeId: storeId, fileName: name);

    final mime = lookupMimeType(originalName) ?? 'application/octet-stream';

    await _sb.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(cacheControl: '3600', contentType: mime),
    );

    return path;
  }

  /// حذف ملف بمساره داخل البكت
  static Future<void> deletePath(String pathInBucket) async {
    await _sb.storage.from(_bucket).remove([pathInBucket]);
  }

  /// رابط عام مباشر (يتطلب سياسة SELECT العامة)
  static String getPublicUrl(String pathInBucket) {
    return _sb.storage.from(_bucket).getPublicUrl(pathInBucket);
  }

  /// (اختياري) حذف كل الملفات داخل مجلد معيّن
  static Future<void> deleteAllInFolder({
    required String storeId,
    String folder = 'products',
  }) async {
    final prefix = '$storeId/$folder';
    final list = await _sb.storage.from(_bucket).list(path: prefix);
    if (list.isEmpty) return;
    final paths = list.map((f) => '$prefix/${f.name}').toList();
    await _sb.storage.from(_bucket).remove(paths);
  }
}
