import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaeta_sandbox/pages/invite/providers/invite_flow_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending invite id is persisted, restored, and cleared', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final persistence = container.read(inviteFlowPersistenceProvider);

    await persistence.setPendingInviteId('invite-123');
    expect(container.read(pendingInviteIdProvider), 'invite-123');

    final restoreContainer = ProviderContainer();
    addTearDown(restoreContainer.dispose);
    final restorePersistence = restoreContainer.read(inviteFlowPersistenceProvider);
    await restorePersistence.restorePendingInviteId();
    expect(restoreContainer.read(pendingInviteIdProvider), 'invite-123');

    await restorePersistence.clearPendingInviteId();
    expect(restoreContainer.read(pendingInviteIdProvider), isNull);

    final verifyContainer = ProviderContainer();
    addTearDown(verifyContainer.dispose);
    final verifyPersistence = verifyContainer.read(inviteFlowPersistenceProvider);
    await verifyPersistence.restorePendingInviteId();
    expect(verifyContainer.read(pendingInviteIdProvider), isNull);
  });
}
