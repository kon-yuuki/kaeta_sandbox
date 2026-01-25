import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../providers/history_provider.dart";
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

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'よく買うもの',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final combined = historyItems[index];
                    final master = combined.masterItem;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: Row(
                        children: [
                          // 1. 名前
                          Expanded(
                            child: Text(
                              "${master.name} (${combined.history.purchaseCount}回)",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          // 2. 画像（URLがある場合のみ）
                          if (master.imageUrl != null && master.imageUrl!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  master.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // 3. 再追加ボタン
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () {
                          ref.read(homeViewModelProvider).addFromHistory(master);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${master.name} を追加しました'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}