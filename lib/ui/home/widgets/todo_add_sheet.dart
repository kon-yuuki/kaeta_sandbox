import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import './category_edit_sheet.dart';
import '../../../data/providers/category_provider.dart';

class TodoAddSheet extends ConsumerStatefulWidget {
  const TodoAddSheet({super.key});

  @override
  ConsumerState<TodoAddSheet> createState() => _TodoAddSheetState();
}

class _TodoAddSheetState extends ConsumerState<TodoAddSheet> {
  final TextEditingController editNameController = TextEditingController();
  int selectedPriority = 0;
  int selectedCategoryValue = 0;
  String category = "指定なし";
  String? selectedCategoryId;

  @override
  void dispose() {
    editNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // 💡 ヘッダー部分（戻るボタンとタイトル）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.chevron_left,
                  ), // 「戻る」なら Icons.chevron_left もあり
                ),
                const Text(
                  'アイテムを追加',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1), // 境界線
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: editNameController,
                    decoration: const InputDecoration(labelText: '買うものをを入力…'),
                    autofocus: true,
                  ),

                  const SizedBox(height: 20),

                  Text('条件の重要度', style: TextStyle(fontSize: 12)),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('普通')),
                      ButtonSegment(value: 1, label: Text('重要')),
                    ],
                    selected: {selectedPriority},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        selectedPriority = newSelection.first;
                      });
                    },
                  ),
                  Row(
                    children: [
                      Text('カテゴリ'),
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            isScrollControlled: true,
                            showDragHandle: true,
                            context: context,
                            builder: (context) => const CategoryEditSheet(),
                          );
                        },
                        icon: Icon(Icons.edit),
                      ),
                    ],
                  ),
                  categoryAsync.when(
                    data: (dbCategories) {
                      return SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dbCategories.length + 1,
                          itemBuilder: (BuildContext context, int index) {
                            return Padding(
                              padding: EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                label: Text(
                                  index == 0
                                      ? "指定なし"
                                      : dbCategories[index - 1].name,
                                ),
                                selected: selectedCategoryValue == index,
                                onSelected: (bool selected) {
                                  setState(() {
                                    selectedCategoryValue = index;
                                    category = index == 0
                                        ? "指定なし"
                                        : dbCategories[index - 1].name;
                                    selectedCategoryId = index == 0
                                        ? null
                                        : dbCategories[index - 1].id;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(homeViewModelProvider)
                          .addTodo(
                            text: editNameController.text,
                            category: category,
                            categoryId: selectedCategoryId,
                            selectedPriority: selectedPriority,
                          );
                      editNameController.clear();

                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('リストに追加する'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
