import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../../../data/providers/category_provider.dart";
import '../../../data/providers/profiles_provider.dart';

class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({super.key});

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  final categoryNameController = TextEditingController();
  String? editingCategoryId;

  @override
  void dispose() {
    categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final categoryAsync = ref.watch(categoryListProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const Text(
                    'カテゴリを編集',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                if (editingCategoryId != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        categoryNameController.clear();
                        editingCategoryId = null; // 💡 これで追加モードに戻れる！
                      });
                    },
                  ),
                Expanded(
                  child: TextField(
                    controller: categoryNameController,
                    decoration: InputDecoration(
                      labelText: editingCategoryId == null
                          ? '新しいカテゴリ名を入力'
                          : 'カテゴリ名を編集',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final name = categoryNameController.text.trim();
                    if (name.isEmpty) return;

                    if (editingCategoryId == null) {
                      await ref
                          .read(categoryRepositoryProvider)
                          .addCategory(
                            name: name,
                            userId: myProfile?.id ?? "",
                            familyId: myProfile?.familyId,
                          );
                    } else {
                      await ref
                          .read(categoryRepositoryProvider)
                          .updateCategoryName(
                            id: editingCategoryId!,
                            newName: name,
                          );
                    }

                    categoryNameController.clear();
                    setState(() {
                      categoryNameController.clear();
                      editingCategoryId = null;
                    });
                  },
                  icon: Icon(
                    editingCategoryId == null
                        ? Icons.add_circle
                        : Icons.check_circle,
                    color: editingCategoryId == null
                        ? Colors.blue
                        : Colors.green,
                    size: 32,
                  ),
                ),
              ],
            ),
            categoryAsync.when(
              data: (list) => Column(
                children: list
                    .map(
                      (cat) => ListTile(
                        title: Text(cat.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                setState(() {
                                  categoryNameController.text = cat.name;
                                  editingCategoryId = cat.id;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('カテゴリの削除'),
                                    content: const Text(
                                      'このカテゴリを削除しますか？\n紐付いているアイテムは「指定なし」になります。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          context,
                                          false,
                                        ), // キャンセル
                                        child: const Text('キャンセル'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          context,
                                          true,
                                        ), // 削除実行
                                        child: const Text(
                                          '削除',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(categoryRepositoryProvider)
                                      .deleteCategory(cat.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('エラー: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
