import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'global_provider.dart';
import 'families_provider.dart';
import '../model/database.dart';
import '../repositories/notifications_repository.dart';

part 'notifications_provider.g.dart';

@riverpod
NotificationsRepository notificationsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return NotificationsRepository(db);
}

@riverpod
Stream<List<AppNotification>> appNotifications(Ref ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  return repo.watchNotifications(familyId);
}

@riverpod
Stream<int> unreadNotificationCount(Ref ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  return repo.watchUnreadCount(familyId);
}

@riverpod
Stream<List<AppNotificationReaction>> notificationReactions(Ref ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  return repo.watchReactions(familyId);
}
