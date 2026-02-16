import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pendingInviteIdProvider = StateProvider<String?>((ref) => null);

final inviteFlowPersistenceProvider = Provider<InviteFlowPersistence>((ref) {
  return InviteFlowPersistence(ref);
});

class InviteFlowPersistence {
  InviteFlowPersistence(this._ref);

  static const _pendingInviteIdKey = 'pending_invite_id';
  final Ref _ref;

  Future<void> restorePendingInviteId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingInviteIdKey);
    if (value == null || value.isEmpty) return;
    _ref.read(pendingInviteIdProvider.notifier).state = value;
  }

  Future<void> setPendingInviteId(String inviteId) async {
    _ref.read(pendingInviteIdProvider.notifier).state = inviteId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteIdKey, inviteId);
  }

  Future<void> clearPendingInviteId() async {
    _ref.read(pendingInviteIdProvider.notifier).state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteIdKey);
  }
}
