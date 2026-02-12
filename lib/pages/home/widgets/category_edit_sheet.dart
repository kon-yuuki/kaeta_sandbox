import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/category_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/category_repository.dart';

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
  static const String _newCategoryEditingKey = '__new_category__';
  final inlineEditController = TextEditingController();
  String? editingCategoryId;
  bool _didResolveInitialCategory = false;

  @override
  void dispose() {
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

  void _startAddCategoryEdit() {
    setState(() {
      editingCategoryId = _newCategoryEditingKey;
      inlineEditController.clear();
    });
  }

  void _resolveInitialCategory(List<Category> list) {
    if (_didResolveInitialCategory || editingCategoryId != null) return;

    final initialId = widget.initialCategoryId?.trim();
    final initialName = widget.initialCategoryName?.trim();
    if (initialId != null && initialId.isNotEmpty) {
      final matched = list.where((c) => c.id == initialId);
      if (matched.isNotEmpty) {
        editingCategoryId = matched.first.id;
        inlineEditController.text = matched.first.name;
      }
      _didResolveInitialCategory = true;
      return;
    }

    if (initialName == null || initialName.isEmpty || initialName == '指定なし') {
      _didResolveInitialCategory = true;
      return;
    }

    final matched = list.where((c) => c.name.trim() == initialName);
    if (matched.isNotEmpty) {
      editingCategoryId = matched.first.id;
      inlineEditController.text = matched.first.name;
    }
    _didResolveInitialCategory = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final myProfile = ref.watch(myProfileProvider).value;
    final categoryAsync = ref.watch(categoryListProvider);

    return Container(
      color: colors.backgroundGray,
      child: SafeArea(
        top: false,
        child: categoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('エラー: $err')),
          data: (list) {
            _resolveInitialCategory(list);

            final limit = CategoryRepository.freePlanCategoryLimit;
            final count = list.length;
            final progress = count == 0 ? 0.0 : (count / limit).clamp(0.0, 1.0);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'カテゴリ数',
                    style: TextStyle(
                      color: colors.textHigh,
                      fontSize: 30 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          count >= limit
                              ? 'カテゴリ数は上限です'
                              : 'あと${limit - count}件追加できます',
                          style: TextStyle(
                            color: colors.textLow,
                            fontSize: 22 / 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '$count/$limit',
                        style: TextStyle(
                          color: colors.textHigh,
                          fontSize: 34 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: colors.surfaceDisabled,
                      valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceHighOnInverse,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                          child: Row(
                            children: [
                              Text(
                                '最初に表示されるカテゴリ',
                                style: TextStyle(
                                  color: colors.textLow,
                                  fontSize: 22 / 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _defaultCategoryRow(colors),
                        const Divider(height: 1),
                        for (var i = 0; i < list.length; i++) ...[
                          _categoryRow(
                            context,
                            list[i],
                            myProfile?.currentFamilyId,
                            colors,
                            canDelete: list.length > 1,
                          ),
                          if (i < list.length - 1) const Divider(height: 1),
                        ],
                        if (count < limit) ...[
                          if (list.isNotEmpty) const Divider(height: 1),
                          if (editingCategoryId == _newCategoryEditingKey)
                            _newCategoryInputRow(
                              context,
                              colors,
                              userId: myProfile?.id ?? '',
                              familyId: myProfile?.currentFamilyId,
                            )
                          else
                            _addCategoryButtonRow(colors),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: null,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(56),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      child: const Text('保存する'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/edit_category/add_category-banner.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '月額500円 / オーナー1人の登録でみんなで使える',
                      style: TextStyle(
                        color: colors.textLow,
                        fontSize: 22 / 2,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _addCategoryButtonRow(
    AppColors colors,
  ) {
    return InkWell(
      onTap: _startAddCategoryEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 8, 18),
        child: Row(
          children: [
            Icon(Icons.add, color: colors.accentPrimary, size: 34),
            const SizedBox(width: 12),
            Text(
              'カテゴリを追加する',
              style: TextStyle(
                color: colors.textHigh,
                fontSize: 34 / 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newCategoryInputRow(
    BuildContext context,
    AppColors colors, {
    required String userId,
    required String? familyId,
  }) {
    final currentLength = inlineEditController.text.length;
    final isOverLimit = currentLength > _maxCategoryLength;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, color: colors.surfaceDisabled),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: inlineEditController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: colors.textHigh,
                fontSize: 34 / 2,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _cancelInlineEdit,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colors.surfaceMedium,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: colors.textHighOnInverse,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentLength/$_maxCategoryLength',
                style: TextStyle(
                  color: isOverLimit ? colors.textAlert : colors.textLow,
                  fontSize: 28 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: inlineEditController.text.trim().isEmpty || isOverLimit
                      ? null
                      : () async {
                          final newName = inlineEditController.text.trim();
                          if (newName.isEmpty) return;
                          try {
                            await ref.read(categoryRepositoryProvider).addCategory(
                                  name: newName,
                                  userId: userId,
                                  familyId: familyId,
                                );
                            if (!context.mounted) return;
                            showTopSnackBar(
                              context,
                              'カテゴリ「$newName」を追加しました',
                              familyId: familyId,
                            );
                            _cancelInlineEdit();
                          } on CategoryLimitExceededException catch (e) {
                            if (!context.mounted) return;
                            showTopSnackBar(
                              context,
                              '無料プランはカテゴリ${e.limit}件までです',
                              familyId: familyId,
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accentPrimary,
                    foregroundColor: colors.textHighOnInverse,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text(
                    '完了',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _defaultCategoryRow(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, color: colors.surfaceDisabled),
          const SizedBox(width: 4),
          Text(
            '指定なし',
            style: TextStyle(
              color: colors.textHigh,
              fontSize: 34 / 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(
    BuildContext context,
    Category cat,
    String? familyId,
    AppColors colors, {
    required bool canDelete,
  }
  ) {
    final isEditing = editingCategoryId == cat.id;
    final currentLength = inlineEditController.text.length;
    final isOverLimit = currentLength > _maxCategoryLength;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        isEditing ? 0 : 6,
        isEditing ? 0 : 8,
        isEditing ? 0 : 6,
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, color: colors.surfaceDisabled),
          const SizedBox(width: 4),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: inlineEditController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: colors.textHigh,
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                  )
                : Text(
                    cat.name,
                    style: TextStyle(
                      color: colors.textHigh,
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          if (isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _cancelInlineEdit,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.surfaceMedium,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colors.textHighOnInverse,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentLength/$_maxCategoryLength',
                  style: TextStyle(
                    color: isOverLimit ? colors.textAlert : colors.textLow,
                    fontSize: 28 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: inlineEditController.text.trim().isEmpty || isOverLimit
                        ? null
                        : () async {
                            final newName = inlineEditController.text.trim();
                            if (newName.isEmpty) return;
                            if (newName == cat.name.trim()) {
                              _cancelInlineEdit();
                              return;
                            }
                            await ref
                                .read(categoryRepositoryProvider)
                                .updateCategoryName(id: cat.id, newName: newName);
                            if (!context.mounted) return;
                            showTopSnackBar(
                              context,
                              'カテゴリ名を「$newName」に変更しました',
                              familyId: familyId,
                            );
                            _cancelInlineEdit();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentPrimary,
                      foregroundColor: colors.textHighOnInverse,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: colors.textLow),
              onPressed: () => _startInlineEdit(cat.id, cat.name),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: canDelete ? colors.textAlert : colors.surfaceDisabled,
              ),
              onPressed: canDelete
                  ? () async {
                      final confirm = await _showDeleteConfirmDialog(
                        context,
                        categoryName: cat.name,
                      );

                      if (confirm == true) {
                        final deletedName = cat.name;
                        await ref
                            .read(categoryRepositoryProvider)
                            .deleteCategory(cat.id);
                        if (!context.mounted) return;
                        showTopSnackBar(
                          context,
                          'カテゴリ「$deletedName」を削除しました',
                          familyId: familyId,
                        );
                      }
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(
    BuildContext context, {
    required String categoryName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = AppColors.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            decoration: BoxDecoration(
              color: colors.surfaceHighOnInverse,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.textAlert, width: 2),
                  ),
                  child: Icon(
                    Icons.priority_high_rounded,
                    color: colors.textAlert,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'カテゴリの削除は\n履歴にも反映されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '削除したカテゴリのアイテムは\n「指定なし」に移動します\n他のカテゴリに移動させる場合は\n履歴から編集してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '削除するカテゴリ',
                  style: TextStyle(
                    color: colors.textAlert,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.backgroundGray,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      color: colors.textLow,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: colors.backgroundGray,
                      foregroundColor: colors.textAlert,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '削除する',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(
                      color: colors.textHigh,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

}
