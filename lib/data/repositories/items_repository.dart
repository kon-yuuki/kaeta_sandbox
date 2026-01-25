import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemsRepository {
  final MyDatabase db;
  ItemsRepository(this.db);

  // 名前からアイテムを探し、なければ作成してIDを返す (Get or Create)
  Future<String> getOrCreateItemId({
    required String name,
    required String category,
    required String? categoryId,
    required String userId,
    required String reading,
    String? familyId,
    String? imageUrl,
  }) async {
    // 1. 既存チェック（同じ家族内、または個人の同じ名前があるか）
    final query = db.select(db.items)..where((t) => t.name.equals(name));

    if (familyId != null && familyId.isNotEmpty) {
      query.where((t) => t.familyId.equals(familyId));
    } else {
      query.where((t) => t.userId.equals(userId) & t.familyId.isNull());
    }

    final existing = await query.getSingleOrNull();
    if (existing != null) return existing.id;

    // 2. なければ新規作成
    final id = const Uuid().v4();
    await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            id: Value(id),
            name: name,
            category: category,
            categoryId: Value(categoryId),
            reading: reading,
            userId: userId,
            familyId: Value(familyId),
            imageUrl: Value(imageUrl),
          ),
        );
    return id;
  }

  Future<String?> uploadItemImage(XFile imageFile) async {
    final path = '${const Uuid().v4()}.jpg';

    await Supabase.instance.client.storage
        .from('item_images')
        .upload(path, File(imageFile.path));

    final url = Supabase.instance.client.storage
        .from('item_images')
        .getPublicUrl(path);

    return url;
  }

  // 入力された読みがなから、既存のアイテム（マスタ）を検索する
Future<Item?> findItemByReading(String reading, String userId, String? familyId) async {
  if (reading.isEmpty) return null;

  final query = db.select(db.items)..where((t) => t.reading.equals(reading));

  // 家族または個人の範囲に限定
  if (familyId != null && familyId.isNotEmpty) {
    query.where((t) => t.familyId.equals(familyId));
  } else {
    query.where((t) => t.userId.equals(userId) & t.familyId.isNull());
  }

  // 最初に見つかった1件を返す
  return await query.getSingleOrNull();
}
}
