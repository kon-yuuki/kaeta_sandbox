import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_list_item.dart';
import "../providers/history_provider.dart";
import '../../../data/repositories/todo_repository.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/providers/families_provider.dart';

class TodoHistoryList extends ConsumerWidget {
  const TodoHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(todoRepositoryProvider);
    final myProfile = ref.watch(myProfileProvider).value;

    return StreamBuilder<List<PurchaseWithMaster>>(
      stream: repository.watchTopPurchaseHistory(myProfile?.currentFamilyId),
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

                    return AppListItem(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${master.name} (${combined.masterItem.purchaseCount}回)",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
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
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () {
                          ref.read(homeViewModelProvider).addFromHistory(master);
                          showTopSnackBar(
                            context,
                            '${master.name} を追加しました',
                            familyId: ref.read(selectedFamilyIdProvider),
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
