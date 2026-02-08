import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../../../data/providers/category_provider.dart";
import '../../../data/providers/profiles_provider.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_list_item.dart';
import '../../../core/widgets/app_text_field.dart';

class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({
    super.key,
    this.showHeader = true,
    this.fullHeight = false,
    this.initialCategoryName,
    this.initialCategoryId,
  });

  final bool showHeader;
  final bool fullHeight;
  final String? initialCategoryName;
  final String? initialCategoryId;

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  static const int _maxCategoryLength = 10;
  final addCategoryController = TextEditingController();
  final inlineEditController = TextEditingController();
  String? editingCategoryId;
  bool _didResolveInitialCategory = false;

  @override
  void dispose() {
    addCategoryController.dispose();
    inlineEditController.dispose();
    super.dispose();
  }

  void _startInlineEdit(String categoryId, String name) {
    setState(() {
      editingCategoryId = categoryId;
      inlineEditController.text = name;
    });
  }

  void _cancelInlineEdit() {
    setState(() {
      editingCategoryId = null;
      inlineEditController.clear();
    });
  }

  String? _getLengthAlert(String value) {
    if (value.length > _maxCategoryLength) {
      return 'カテゴリ名は$_maxCategoryLength文字以内で入力してください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final categoryAsync = ref.watch(categoryListProvider);

    return SizedBox(
      height: widget.fullHeight
          ? double.infinity
          : MediaQuery.of(context).size.height * 0.9,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.showHeader) ...[
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
            ],
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: addCategoryController,
                    maxLength: _maxCategoryLength,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    onChanged: (_) => setState(() {}),
                    label: '新しいカテゴリ名を入力',
                    counterText:
                        '${addCategoryController.text.length}/$_maxCategoryLength',
                    errorText: _getLengthAlert(addCategoryController.text),
                  ),
                ),
                IconButton(
                  onPressed:
                      addCategoryController.text.trim().isEmpty ||
                              _getLengthAlert(addCategoryController.text) != null
                          ? null
                          : () async {
                    final name = addCategoryController.text.trim();
                    if (name.isEmpty) return;

                    await ref
                        .read(categoryRepositoryProvider)
                        .addCategory(
                          name: name,
                          userId: myProfile?.id ?? "",
                          familyId: myProfile?.currentFamilyId,
                        );

                    addCategoryController.clear();
                    if (mounted) {
                      setState(() {});
                      showTopSnackBar(
                        context,
                        'カテゴリ「$name」を追加しました',
                        familyId: myProfile?.currentFamilyId,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
              ],
            ),
            categoryAsync.when(
              data: (list) {
                if (!_didResolveInitialCategory && editingCategoryId == null) {
                  final initialId = widget.initialCategoryId?.trim();
                  final initialName = widget.initialCategoryName?.trim();
                  if (initialId != null && initialId.isNotEmpty) {
                    final matched = list.where((c) => c.id == initialId);
                    if (matched.isNotEmpty) {
                      editingCategoryId = matched.first.id;
                      inlineEditController.text = matched.first.name;
                      _didResolveInitialCategory = true;
                    } else if (list.isNotEmpty) {
                      _didResolveInitialCategory = true;
                    }
                  } else if (initialName == null || initialName.isEmpty || initialName == '指定なし') {
                    _didResolveInitialCategory = true;
                  } else {
                    final matched = list.where((c) => c.name.trim() == initialName);
                    if (matched.isNotEmpty) {
                      editingCategoryId = matched.first.id;
                      inlineEditController.text = matched.first.name;
                      _didResolveInitialCategory = true;
                    } else if (list.isNotEmpty) {
                      // 一覧取得後に一致が無いことが確定したら解決済みにする
                      _didResolveInitialCategory = true;
                    }
                  }
                }
                return Column(
                children: list
                    .map(
                      (cat) {
                        final isEditing = editingCategoryId == cat.id;
                        return AppListItem(
                          title: isEditing
                              ? AppTextField(
                                  controller: inlineEditController,
                                  autofocus: true,
                                  maxLength: _maxCategoryLength,
                                  maxLengthEnforcement:
                                      MaxLengthEnforcement.none,
                                  onChanged: (_) => setState(() {}),
                                  heightType:
                                      AppTextFieldHeight.h56SingleLineEdit,
                                  counterText:
                                      '${inlineEditController.text.length}/$_maxCategoryLength',
                                  errorText:
                                      _getLengthAlert(inlineEditController.text),
                                )
                              : Text(cat.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isEditing)
                                AppButton(
                                  variant: AppButtonVariant.text,
                                  onPressed:
                                      inlineEditController.text
                                                  .trim()
                                                  .isEmpty ||
                                              _getLengthAlert(
                                                    inlineEditController.text,
                                                  ) !=
                                                  null
                                          ? null
                                          : () async {
                                              final newName =
                                                  inlineEditController.text
                                                      .trim();
                                              if (newName.isEmpty) return;
                                              if (newName == cat.name.trim()) {
                                                _cancelInlineEdit();
                                                return;
                                              }
                                              await ref
                                                  .read(
                                                    categoryRepositoryProvider,
                                                  )
                                                  .updateCategoryName(
                                                    id: cat.id,
                                                    newName: newName,
                                                  );
                                              if (!mounted) return;
                                              showTopSnackBar(
                                                context,
                                                'カテゴリ名を「$newName」に変更しました',
                                                familyId:
                                                    myProfile?.currentFamilyId,
                                              );
                                              _cancelInlineEdit();
                                            },
                                  child: const Text('完了'),
                                )
                              else ...[
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _startInlineEdit(cat.id, cat.name),
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
                                          AppButton(
                                            variant: AppButtonVariant.text,
                                            onPressed: () => Navigator.pop(
                                              context,
                                              false,
                                            ),
                                            child: const Text('キャンセル'),
                                          ),
                                          AppButton(
                                            variant: AppButtonVariant.text,
                                            onPressed: () => Navigator.pop(
                                              context,
                                              true,
                                            ),
                                            child: const Text(
                                              '削除',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deletedName = cat.name;
                                      await ref
                                          .read(categoryRepositoryProvider)
                                          .deleteCategory(cat.id);
                                      if (mounted) {
                                        showTopSnackBar(
                                          context,
                                          'カテゴリ「$deletedName」を削除しました',
                                          familyId: myProfile?.currentFamilyId,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    )
                    .toList(),
              );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('エラー: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
