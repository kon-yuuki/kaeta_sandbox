import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String categoryUnspecifiedOrderId = '__default__';

class CategoryOrderScope {
  const CategoryOrderScope({
    required this.userId,
    required this.familyId,
  });

  final String userId;
  final String? familyId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryOrderScope &&
        other.userId == userId &&
        other.familyId == familyId;
  }

  @override
  int get hashCode => Object.hash(userId, familyId);
}

String _categoryOrderStorageKey({
  required String userId,
  required String? familyId,
}) {
  final normalizedFamilyId =
      (familyId != null && familyId.trim().isNotEmpty) ? familyId.trim() : 'personal';
  return 'category_order:$userId:$normalizedFamilyId';
}

Future<List<String>> loadCategoryOrder({
  required String userId,
  required String? familyId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(
        _categoryOrderStorageKey(userId: userId, familyId: familyId),
      ) ??
      const <String>[];
}

Future<void> saveCategoryOrder({
  required String userId,
  required String? familyId,
  required List<String> orderIds,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    _categoryOrderStorageKey(userId: userId, familyId: familyId),
    orderIds,
  );
}

final categoryOrderProvider =
    FutureProvider.family<List<String>, CategoryOrderScope>((ref, scope) async {
  return loadCategoryOrder(userId: scope.userId, familyId: scope.familyId);
});

