import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 履歴(Item)とマスタ(MasterItem)の差異を吸収する、UI表示専用のモデル
class SearchSuggestion {
  final String name;
  final String reading;
  final String? imageUrl;
  final dynamic original;

  SearchSuggestion({
    required this.name,
    required this.reading,
    this.imageUrl,
    required this.original,
  });
}

class ItemsRepository {
  final MyDatabase db;
  ItemsRepository(this.db);
  static const int suggestionLimit = 10;

  // 💡 キューに溜めるためのキー名（クラスの変数として定義）
  static const String _pendingReadingsKey = 'pending_hiragana_update_ids';

  // 名前からアイテムを探し、なければ作成してIDを返す (Get or Create)
  Future<String> getOrCreateItemId({
    required String name,
    required String category,
    required String? categoryId,
    required String userId,
    required String reading,
    String? familyId,
    String? imageUrl,
    int? budgetMinAmount,
    int? budgetMaxAmount,
    int? budgetType,
    String? quantityText,
    int? quantityUnit,
    int? quantityCount,
  }) async {
    String finalReading = reading;

    // 1. 漢字を検知したら Yahoo API で変換
    if (RegExp(r'[一-龠]').hasMatch(finalReading)) {
      print('⚠️ 漢字を検知: Yahoo APIで変換します');
      finalReading = await _fetchHiraganaFromYahoo(name);
      print('✨ 変換結果: $finalReading');
    }

    // 2. 既存チェック
    final query = db.select(db.items)..where((t) => t.name.equals(name));
    if (familyId != null && familyId.isNotEmpty) {
      query.where((t) => t.familyId.equals(familyId));
    } else {
      query.where((t) => t.userId.equals(userId) & t.familyId.isNull());
    }

    final existing = await query.getSingleOrNull();

    String targetId; // 最後に返すIDを保持する変数

    if (existing != null) {
      targetId = existing.id;
      // 3. 既存データの浄化 + 予算/数量更新
      final updateCompanion = ItemsCompanion(
        reading: RegExp(r'[一-龠]').hasMatch(existing.reading)
            ? Value(finalReading)
            : const Value.absent(),
        imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
        budgetMinAmount: budgetMinAmount != null
            ? Value(budgetMinAmount)
            : const Value.absent(),
        budgetMaxAmount: budgetMaxAmount != null
            ? Value(budgetMaxAmount)
            : const Value.absent(),
        budgetType: budgetType != null
            ? Value(budgetType)
            : const Value.absent(),
        quantityText: quantityText != null
            ? Value(quantityText)
            : const Value.absent(),
        quantityUnit: quantityUnit != null
            ? Value(quantityUnit)
            : const Value.absent(),
        quantityCount: quantityCount != null
            ? Value(quantityCount)
            : const Value.absent(),
      );
      if (RegExp(r'[一-龠]').hasMatch(existing.reading) ||
          imageUrl != null ||
          budgetMaxAmount != null ||
          budgetMinAmount != null ||
          quantityText != null ||
          quantityCount != null) {
        await (db.update(
          db.items,
        )..where((t) => t.id.equals(existing.id))).write(updateCompanion);
        debugPrint(
          'Updated existing item. id=${existing.id} imageUrlUpdated=${imageUrl != null}',
        );
      }
    } else {
      // 4. 新規作成
      final newId = const Uuid().v4();
      targetId = newId;
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: Value(newId),
              name: name,
              category: category,
              categoryId: Value(categoryId),
              reading: finalReading,
              userId: userId,
              familyId: Value(familyId),
              imageUrl: Value(imageUrl),
              purchaseCount: const Value(0),
              budgetMinAmount: Value(budgetMinAmount),
              budgetMaxAmount: Value(budgetMaxAmount),
              budgetType: Value(budgetType),
              quantityText: Value(quantityText),
              quantityUnit: Value(quantityUnit),
              quantityCount: Value(quantityCount),
            ),
          );
    }

    // 💡 5. 最終チェック：オフライン等で漢字が残った場合はキューに保存
    if (RegExp(r'[一-龠]').hasMatch(finalReading)) {
      print('⚠️ オフライン等の理由で漢字が残りました。キューに保存します。');
      await _addToPendingQueue(targetId);
    }

    return targetId;
  }

  // --- Yahoo API 変換 ---
  Future<String> _fetchHiraganaFromYahoo(String text) async {
    const String clientId =
        'dmVyPTIwMjUwNyZpZD1MeUxoVEVpd0pwJmhhc2g9TnpNek4yWTJaVEE1TUdSak5XVmpNdw';
    final url = Uri.parse(
      'https://jlp.yahooapis.jp/FuriganaService/V2/furigana',
    );

    try {
      print('📡 Yahoo APIへ送信: $text');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Yahoo AppID: $clientId',
            },
            body: json.encode({
              "id": "1",
              "jsonrpc": "2.0",
              "method": "jlp.furiganaservice.furigana",
              "params": {"q": text, "grade": 1},
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final Map<String, dynamic>? result = data['result'];
        final List<dynamic>? wordList = result?['word'];

        if (wordList == null || wordList.isEmpty) return text;

        final String converted = wordList
            .map((word) {
              final String furigana = word['furigana']?.toString() ?? '';
              final String surface = word['surface']?.toString() ?? '';
              return furigana.isNotEmpty ? furigana : surface;
            })
            .join('');

        print('✨ API変換成功: $converted');
        return converted;
      }
    } catch (e) {
      print('📡 Yahoo API 通信例外: $e');
    }
    return text;
  }

  // --- キュー操作ロジック ---
  Future<void> _addToPendingQueue(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pendingIds =
        prefs.getStringList(_pendingReadingsKey) ?? [];

    if (!pendingIds.contains(itemId)) {
      pendingIds.add(itemId);
      await prefs.setStringList(_pendingReadingsKey, pendingIds);
      print('📌 未変換キューに追加完了: $itemId');
    }
  }

  // キューの掃除
  Future<void> processPendingReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pendingIds =
        prefs.getStringList(_pendingReadingsKey) ?? [];

    if (pendingIds.isEmpty) return;
    print('🧹 未変換キューの掃除を開始します... (${pendingIds.length}件)');

    final List<String> remainingIds = [];

    for (String id in pendingIds) {
      final item = await (db.select(
        db.items,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (item != null && RegExp(r'[一-龠]').hasMatch(item.reading)) {
        final newReading = await _fetchHiraganaFromYahoo(item.name);
        if (!RegExp(r'[一-龠]').hasMatch(newReading)) {
          await (db.update(db.items)..where((t) => t.id.equals(id))).write(
            ItemsCompanion(reading: Value(newReading)),
          );
          print('✅ アイテムID: $id をひらがな化しました');
        } else {
          remainingIds.add(id);
        }
      }
    }
    await prefs.setStringList(_pendingReadingsKey, remainingIds);
  }

  // --- その他の既存メソッド ---
  Future<String?> uploadItemImage(XFile imageFile) async {
    try {
      // WebP形式に圧縮変換（最大512px、品質80%）
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
            imageFile.path,
            minWidth: 512,
            minHeight: 512,
            quality: 80,
            format: CompressFormat.webp,
          );

      if (compressedBytes == null) {
        print('⚠️ 画像圧縮に失敗しました');
        return null;
      }

      final originalSize = await File(imageFile.path).length();
      print(
        '📷 画像圧縮: ${(originalSize / 1024).toStringAsFixed(1)}KB → ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB',
      );

      final path = '${const Uuid().v4()}.webp';
      await Supabase.instance.client.storage
          .from('item_images')
          .uploadBinary(
            path,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/webp'),
          );

      return Supabase.instance.client.storage
          .from('item_images')
          .getPublicUrl(path);
    } catch (e) {
      print('🚨 画像アップロードエラー: $e');
      return null;
    }
  }

  Future<Item?> findItemByReading(
    String reading,
    String userId,
    String? familyId,
  ) async {
    if (reading.isEmpty) return null;
    final query = db.select(db.items)..where((t) => t.reading.equals(reading));
    if (familyId != null && familyId.isNotEmpty) {
      query.where((t) => t.familyId.equals(familyId));
    } else {
      query.where((t) => t.userId.equals(userId) & t.familyId.isNull());
    }
    return await query.getSingleOrNull();
  }

  Future<List<SearchSuggestion>> searchItemsByReadingPrefix(
    String prefix,
    String userId,
    String? familyId,
  ) async {
    if (prefix.isEmpty) return [];
    final historyQuery = db.select(db.items)
      ..where((t) => t.reading.like('$prefix%'));
    if (familyId != null && familyId.isNotEmpty) {
      historyQuery.where((t) => t.familyId.equals(familyId));
    } else {
      historyQuery.where((t) => t.userId.equals(userId) & t.familyId.isNull());
    }
    final history =
        await (historyQuery
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.purchaseCount,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(suggestionLimit))
            .get();
    List<MasterItem> masters = [];
    if (history.length < suggestionLimit) {
      final needed = suggestionLimit - history.length;
      final existingNames = history.map((e) => e.name).toList();
      masters =
          await (db.select(db.masterItems)
                ..where(
                  (t) =>
                      t.reading.like('$prefix%') &
                      t.name.isNotIn(existingNames),
                )
                ..limit(needed))
              .get();
    }
    return [
      ...history.map(
        (e) => SearchSuggestion(
          name: e.name,
          reading: e.reading,
          imageUrl: e.imageUrl,
          original: e,
        ),
      ),
      ...masters.map(
        (e) => SearchSuggestion(
          name: e.name,
          reading: e.reading,
          imageUrl: null,
          original: e,
        ),
      ),
    ];
  }
}
