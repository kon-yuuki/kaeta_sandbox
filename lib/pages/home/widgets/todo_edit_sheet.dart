import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import '../../../data/providers/category_provider.dart';

class TodoEditSheet extends ConsumerStatefulWidget {
  final TodoItem item;
  const TodoEditSheet({super.key, required this.item});

  @override
  ConsumerState<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends ConsumerState<TodoEditSheet> {
  late TextEditingController editNameController;
  late ScrollController scrollController;
  late int selectedPriority;
  int selectedCategoryValue = 0;
  String category = "指定なし";
  String? selectedCategoryId;
  bool _hasScrolled = false;
  final GlobalKey selectedCategoryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    editNameController = TextEditingController(text: widget.item.name);
    scrollController = ScrollController();
    selectedCategoryId = widget.item.categoryId;
    selectedPriority = widget.item.priority;
  }

  @override
  void dispose() {
    editNameController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(labelText: '名前を編集'),
              autofocus: true,
            ),

            const SizedBox(height: 20),

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
            const SizedBox(height: 16),
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
                if (selectedCategoryId == null) {
                    selectedCategoryValue = 0;
                    category = "指定なし";
                  } else {
                    final index = dbCategories.indexWhere((c) => c.id == selectedCategoryId);
                    selectedCategoryValue = index != -1 ? index + 1 : 0;
                    if (index != -1) {
                        category = dbCategories[index].name;
                      }
                  }

                  if (!_hasScrolled) {
                    _hasScrolled = true; 
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final chipContext = selectedCategoryKey.currentContext;
                      if (chipContext != null) {
                        Scrollable.ensureVisible(
                          chipContext,
                          alignment: 0.5, 
                          duration: const Duration(milliseconds: 300), 
                        );
}
                    });
                  }
                  
                return SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dbCategories.length + 1,
                    controller: scrollController,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: EdgeInsets.all(4.0),
                        child: ChoiceChip(
                          label: Text(
                            index == 0 ? "指定なし" : dbCategories[index - 1].name,
                          ),
                          selected: selectedCategoryValue == index,
                          onSelected: (bool selected,
                          ) {
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
                          key:index == selectedCategoryValue ? selectedCategoryKey : null,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(homeViewModelProvider)
                    .updateTodo(
                      widget.item,
                      category,
                      selectedCategoryId,
                      editNameController.text,
                      selectedPriority,
                    );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
