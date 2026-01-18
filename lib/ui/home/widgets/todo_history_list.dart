import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../providers/home_provider.dart";
import '../../../data/repositories/todo_repository.dart';
import '../../../data/providers/profiles_provider.dart';

class TodoHistoryList extends ConsumerWidget {
  const TodoHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(todoRepositoryProvider);
    final myProfile = ref.watch(myProfileProvider).value;

    return StreamBuilder<List<PurchaseWithMaster>>(
      stream: repository.watchTopPurchaseHistory(myProfile?.familyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final historyItems = snapshot.data!;
        if (historyItems.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            final combined = historyItems[index];
            final history = combined.history;
            final master = combined.masterItem;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ActionChip(
                label: Text("${master.name} (${history.purchaseCount})"),
                onPressed: () {
                  // 必要に応じて履歴タップ時の処理
                },
              ),
            );
          },
        );
      },
    );
  }
}
