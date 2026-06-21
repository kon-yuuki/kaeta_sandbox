import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/providers/category_provider.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/repositories/category_repository.dart';
import '../providers/home_provider.dart';
import '../todo_add_page.dart';
import '../view/todo_edit_page.dart';
import 'category_name_editor_sheet.dart';

class TodoItemList extends ConsumerStatefulWidget {
  const TodoItemList({
    super.key,
    this.blockInteractions = false,
    this.onBlockedTap,
  });

  final bool blockInteractions;
  final VoidCallback? onBlockedTap;

  @override
  ConsumerState<TodoItemList> createState() => _TodoItemListState();
}

class _TodoItemListState extends ConsumerState<TodoItemList> {
  static const Duration _completeAnimationDelay = Duration(milliseconds: 280);
  final Set<String> _pendingCompleteIds = <String>{};

  static const int _maxCategoryNameLength = 10;

  static const List<String> _quantityUnits = ['g', 'mg', 'ml', 'kg', 'L'];

  String? _buildQuantityLabel(String? text, int? unit) {
    if (text == null || text.isEmpty) return null;
    if (unit == null || unit < 0 || unit >= _quantityUnits.length) return text;
    return '$text${_quantityUnits[unit]}';
  }

  String? _buildBudgetLabel(int? min, int? max, int? type) {
    const upperNoneThreshold = 2050;
    if (max == null || max <= 0) return null;
    final unit = type == 1 ? '100g' : '1つ';
    final minAmount = min ?? 0;
    if (max >= upperNoneThreshold) {
      return minAmount <= 0 ? null : '$minAmount円以上／$unit';
    }
    if (minAmount <= 0) {
      return '$max円以下／$unit';
    }
    if (minAmount >= max) {
      return '$minAmount円以上／$unit';
    }
    return '$minAmount〜$max円／$unit';
  }

  String _priorityLabel(int priority) {
    if (priority == 1) return '必ず条件を守る';
    return '目安でOK';
  }

  Color _priorityBackground(AppColors appColors, int priority) {
    if (priority == 1) return appColors.accentPrimaryLight;
    return appColors.surfaceTertiary;
  }

  Widget _buildCategoryEditModalHeader({
    required BuildContext context,
    required VoidCallback onBack,
    Widget? trailing,
  }) {
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                'カテゴリを編集',
                textAlign: TextAlign.center,
                style: appTypography.std16B150.copyWith(
                  color: appColors.textHigh,
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        Divider(height: 1, color: appColors.borderLow),
      ],
    );
  }

  Future<void> _showCategoryEditModal({
    required String categoryId,
    required String categoryName,
  }) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    final newName = await showCategoryNameEditorSheet(
      context: context,
      title: 'カテゴリを編集',
      initialName: categoryName,
      hintText: 'カテゴリ名を入力',
      maxLength: _maxCategoryNameLength,
    );
    if (!mounted || newName == null || newName == categoryName.trim()) return;
    try {
      await ref
          .read(categoryRepositoryProvider)
          .updateCategoryName(id: categoryId, newName: newName);
      if (!mounted) return;
      showTopSnackBar(
        context,
        'カテゴリ名を「$newName」に変更しました',
        familyId: familyId,
        actionLabel: '元に戻す',
        onAction: (snackBarContext) {
          ref
              .read(categoryRepositoryProvider)
              .updateCategoryName(id: categoryId, newName: categoryName)
              .then((_) {
                if (!mounted) return;
                showTopSnackBar(context, 'カテゴリ名を元に戻しました', familyId: familyId);
              });
        },
      );
    } on DuplicateCategoryNameException {
      if (!mounted) return;
      showTopSnackBar(context, '同じ名前のカテゴリは変更できません', familyId: familyId);
    }
  }

  Future<void> _handleCompleteTap(dynamic todo) async {
    if (widget.blockInteractions) {
      widget.onBlockedTap?.call();
      return;
    }

    final todoId = todo.id as String;
    if (_pendingCompleteIds.contains(todoId)) {
      return;
    }

    setState(() {
      _pendingCompleteIds.add(todoId);
    });

    await Future.delayed(_completeAnimationDelay);
    final result = await ref.read(homeViewModelProvider).completeTodo(todo);
    if (!mounted) return;

    setState(() {
      _pendingCompleteIds.remove(todoId);
    });

    showTopSnackBar(context, result.message, saveToHistory: false);

    if (!result.allCompleted) return;

    final completedByCurrentUser =
        Supabase.instance.client.auth.currentUser?.id != null;
    // このダイアログは Todo の作成者ではなく、
    // 最後の完了操作を行ったユーザー基準で出し分ける。
    _showAllCompletedDialog(
      context,
      completedMyOwnItem: completedByCurrentUser,
    );
  }

  String _emptyStateGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 10) {
      return 'おはようございます\n買うものはありますか？';
    }
    if (hour >= 10 && hour < 17) {
      return 'お疲れさまです\nちょっとした伝言は「ひとこと」で共有できます';
    }
    return 'こんばんは\n履歴からもすぐに追加ができます';
  }

  void _showAllCompletedDialog(
    BuildContext context, {
    required bool completedMyOwnItem,
  }) {
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    final lottieAsset = completedMyOwnItem
        ? 'assets/animations/complete_shopping_cat.json'
        : 'assets/animations/complete_shopping.json';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/icons/cross.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        appColors.surfaceMedium,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 210,
                  child: Lottie.asset(
                    lottieAsset,
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'お買い物お疲れでした！',
                textAlign: TextAlign.center,
                style: appTypography.std16B150.copyWith(
                  color: appColors.textHigh,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '内容は履歴に保存されています\n次回リスト作成時に活用してくださいね',
                textAlign: TextAlign.center,
                style: appTypography.std14R160.copyWith(
                  color: appColors.textHigh,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'OK',
                  style: appTypography.std14B160.copyWith(
                    color: appColors.textHighOnInverse,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    final categoryNameStyle = appTypography.std18Sb160.copyWith(
      color: appColors.textMedium,
    );
    final itemNameStyle = appTypography.jaOnl16M130.copyWith(
      color: appColors.textHigh,
    );
    final quantityCountStyle = appTypography.egOnl16M160.copyWith(
      color: appColors.textHigh,
    );
    final optionInfoStyle = appTypography.jaOnl12M120.copyWith(
      color: appColors.textLow,
    );
    TextStyle priorityChipStyle(int priority) =>
        appTypography.std11B140.copyWith(
          color: priority == 1
              ? appColors.textAccentPrimary
              : appColors.textMedium,
        );
    final todoListAsync = ref.watch(todoListProvider);
    final groupTodo = ref.watch(groupedTodoListProvider);

    return todoListAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 56),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/home/stay_cat.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                Text(
                  'アイテムはありません',
                  textAlign: TextAlign.center,
                  style: appTypography.std18R160.copyWith(
                    color: appColors.textHigh,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _emptyStateGreeting(),
                  textAlign: TextAlign.center,
                  style: appTypography.std14R160.copyWith(
                    color: appColors.textMedium,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: groupTodo.entries.map((entry) {
            final categoryName = entry.key;
            final todoItems = entry.value;
            final priorities = [
              1,
              0,
            ].where((p) => todoItems.any((e) => e.todo.priority == p)).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 16.0,
              ),
              child: Card(
                color: appColors.surfaceSecondary,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final categoryId = todoItems.isNotEmpty
                              ? todoItems.first.todo.categoryId
                              : null;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: SizedBox(
                              height: 36,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 40),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            categoryName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: categoryNameStyle,
                                          ),
                                        ),
                                        if (categoryName != '指定なし' &&
                                            categoryId != null)
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            icon: SvgPicture.asset(
                                              'assets/icons/pen.svg',
                                              width: 24,
                                              height: 24,
                                              colorFilter: ColorFilter.mode(
                                                appColors.surfaceLow,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                            tooltip: 'カテゴリを編集',
                                            onPressed: () {
                                              if (widget.blockInteractions) {
                                                widget.onBlockedTap?.call();
                                                return;
                                              }
                                              _showCategoryEditModal(
                                                categoryId: categoryId,
                                                categoryName: categoryName,
                                              );
                                            },
                                          )
                                        else
                                          const SizedBox(width: 28, height: 28),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 2,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      icon: SvgPicture.asset(
                                        'assets/icons/plus.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: ColorFilter.mode(
                                          appColors.surfaceMedium,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      tooltip: 'カテゴリに追加',
                                      onPressed: () {
                                        if (widget.blockInteractions) {
                                          widget.onBlockedTap?.call();
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TodoAddPage(
                                              initialCategoryName: categoryName,
                                              initialCategoryId:
                                                  todoItems.isNotEmpty
                                                  ? todoItems
                                                        .first
                                                        .todo
                                                        .categoryId
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      ...priorities.map((priority) {
                        final groupedItems = todoItems
                            .where((e) => e.todo.priority == priority)
                            .toList();
                        final isLastPriorityGroup = priority == priorities.last;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: isLastPriorityGroup ? 0 : 10,
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 30),
                                      ...List.generate(groupedItems.length, (
                                        index,
                                      ) {
                                        final combined = groupedItems[index];
                                        final quantityLabel =
                                            _buildQuantityLabel(
                                              combined.todo.quantityText,
                                              combined.todo.quantityUnit,
                                            );
                                        final budgetLabel = _buildBudgetLabel(
                                          combined.todo.budgetMinAmount,
                                          combined.todo.budgetMaxAmount,
                                          combined.todo.budgetType,
                                        );
                                        final metaLines = <String>[
                                          if (quantityLabel != null &&
                                              quantityLabel.isNotEmpty)
                                            quantityLabel,
                                          if (budgetLabel != null &&
                                              budgetLabel.isNotEmpty)
                                            budgetLabel,
                                        ];

                                        return _SwipeDeleteContainer(
                                          enabled: !widget.blockInteractions,
                                          colors: appColors,
                                          onDelete: () async {
                                            final deletedTodo = combined.todo;
                                            final deletedMaster =
                                                combined.masterItem;
                                            await ref
                                                .read(homeViewModelProvider)
                                                .deleteTodo(deletedTodo);
                                            if (!context.mounted) return;
                                            showTopSnackBar(
                                              context,
                                              '「${deletedMaster.name}」を削除しました',
                                              familyId: ref.read(
                                                selectedFamilyIdProvider,
                                              ),
                                              saveToHistory: false,
                                              actionLabel: '元に戻す',
                                              onAction: (snackBarContext) {
                                                ref
                                                    .read(homeViewModelProvider)
                                                    .addTodo(
                                                      text: deletedMaster.name,
                                                      category:
                                                          deletedTodo.category,
                                                      categoryId: deletedTodo
                                                          .categoryId,
                                                      reading:
                                                          deletedMaster
                                                              .reading
                                                              .isNotEmpty
                                                          ? deletedMaster
                                                                .reading
                                                          : deletedTodo.name,
                                                      priority:
                                                          deletedTodo.priority,
                                                      budgetMinAmount:
                                                          deletedTodo
                                                              .budgetMinAmount,
                                                      budgetMaxAmount:
                                                          deletedTodo
                                                              .budgetMaxAmount,
                                                      budgetType: deletedTodo
                                                          .budgetType,
                                                      quantityText: deletedTodo
                                                          .quantityText,
                                                      quantityUnit: deletedTodo
                                                          .quantityUnit,
                                                      quantityCount: deletedTodo
                                                          .quantityCount,
                                                    )
                                                    .then((result) {
                                                      if (result != null) {
                                                        return;
                                                      }
                                                      if (!snackBarContext
                                                          .mounted) {
                                                        return;
                                                      }
                                                      showTopSnackBar(
                                                        snackBarContext,
                                                        '元に戻せませんでした',
                                                        familyId: ref.read(
                                                          selectedFamilyIdProvider,
                                                        ),
                                                        saveToHistory: false,
                                                      );
                                                    });
                                              },
                                            );
                                          },
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border(
                                                bottom:
                                                    index ==
                                                        groupedItems.length - 1
                                                    ? BorderSide.none
                                                    : BorderSide(
                                                        color: appColors
                                                            .borderDivider,
                                                        width: 1,
                                                      ),
                                              ),
                                            ),
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      12,
                                                      0,
                                                      20,
                                                    ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: GestureDetector(
                                                        behavior:
                                                            HitTestBehavior
                                                                .opaque,
                                                        onTap: () {
                                                          if (widget
                                                              .blockInteractions) {
                                                            widget.onBlockedTap
                                                                ?.call();
                                                            return;
                                                          }
                                                          debugPrint(
                                                            'Open TodoEditPage(from list): todoId=${combined.todo.id} itemId=${combined.todo.itemId} imageUrl=${combined.masterItem.imageUrl}',
                                                          );
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TodoEditPage(
                                                                    item: combined
                                                                        .todo,
                                                                    imageUrl: combined
                                                                        .masterItem
                                                                        .imageUrl,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          combined
                                                                              .masterItem
                                                                              .name,
                                                                          style:
                                                                              itemNameStyle,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                      if (combined.todo.quantityCount !=
                                                                              null &&
                                                                          combined.todo.quantityCount! >
                                                                              0)
                                                                        Text(
                                                                          ' ×${combined.todo.quantityCount}',
                                                                          style:
                                                                              quantityCountStyle,
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  if (metaLines
                                                                      .isNotEmpty) ...[
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        if (quantityLabel !=
                                                                                null &&
                                                                            quantityLabel.isNotEmpty)
                                                                          Row(
                                                                            children: [
                                                                              SvgPicture.asset(
                                                                                'assets/icons/bag.svg',
                                                                                width: 16,
                                                                                height: 16,
                                                                                colorFilter: ColorFilter.mode(
                                                                                  appColors.surfaceLow,
                                                                                  BlendMode.srcIn,
                                                                                ),
                                                                              ),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  quantityLabel,
                                                                                  style: optionInfoStyle,
                                                                                  maxLines: 1,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        if (budgetLabel !=
                                                                                null &&
                                                                            budgetLabel.isNotEmpty)
                                                                          if (quantityLabel !=
                                                                                  null &&
                                                                              quantityLabel.isNotEmpty)
                                                                            const SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                        if (budgetLabel !=
                                                                                null &&
                                                                            budgetLabel.isNotEmpty)
                                                                          Text(
                                                                            budgetLabel,
                                                                            style:
                                                                                optionInfoStyle,
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            if (combined
                                                                        .masterItem
                                                                        .imageUrl !=
                                                                    null &&
                                                                combined
                                                                    .masterItem
                                                                    .imageUrl!
                                                                    .isNotEmpty)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 10,
                                                                      top: 2,
                                                                    ),
                                                                child: ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                  child: Image.network(
                                                                    combined
                                                                        .masterItem
                                                                        .imageUrl!,
                                                                    width: 44,
                                                                    height: 44,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    errorBuilder:
                                                                        (
                                                                          _,
                                                                          __,
                                                                          ___,
                                                                        ) =>
                                                                            const SizedBox.shrink(),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      onTap: () =>
                                                          _handleCompleteTap(
                                                            combined.todo,
                                                          ),
                                                      child: SizedBox(
                                                        width:
                                                            (combined
                                                                        .masterItem
                                                                        .imageUrl !=
                                                                    null &&
                                                                combined
                                                                    .masterItem
                                                                    .imageUrl!
                                                                    .isNotEmpty)
                                                            ? 68
                                                            : 44,
                                                        child: Padding(
                                                          padding: EdgeInsets.only(
                                                            left:
                                                                combined.masterItem.imageUrl !=
                                                                        null &&
                                                                    combined
                                                                        .masterItem
                                                                        .imageUrl!
                                                                        .isNotEmpty
                                                                ? 24
                                                                : 0,
                                                            right: 16,
                                                          ),
                                                          child: Align(
                                                            alignment: Alignment
                                                                .topLeft,
                                                            child: AppCheckCircle(
                                                              selected:
                                                                  combined
                                                                      .todo
                                                                      .isCompleted ||
                                                                  _pendingCompleteIds
                                                                      .contains(
                                                                        combined
                                                                            .todo
                                                                            .id,
                                                                      ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                child: Container(
                                  height: 30,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _priorityBackground(
                                      appColors,
                                      priority,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (priority == 1) ...[
                                        SvgPicture.asset(
                                          'assets/icons/shield-check.svg',
                                          width: 16,
                                          height: 16,
                                          colorFilter: ColorFilter.mode(
                                            appColors.accentPrimaryDark,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        _priorityLabel(priority),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: priorityChipStyle(priority),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('読み込みエラー: $err')),
    );
  }
}

class _SwipeDeleteContainer extends StatefulWidget {
  const _SwipeDeleteContainer({
    required this.child,
    required this.onDelete,
    required this.colors,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function() onDelete;
  final AppColors colors;
  final bool enabled;

  @override
  State<_SwipeDeleteContainer> createState() => _SwipeDeleteContainerState();
}

class _SwipeDeleteContainerState extends State<_SwipeDeleteContainer> {
  static const double _actionWidth = 74;
  double _offsetX = 0;

  bool get _isOpen => _offsetX <= -(_actionWidth / 2);

  void _close() {
    if (_offsetX == 0) return;
    setState(() => _offsetX = 0);
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isOpen ? _close : null,
        onHorizontalDragUpdate: !widget.enabled
            ? null
            : (details) {
                final next = (_offsetX + details.delta.dx).clamp(
                  -_actionWidth,
                  0.0,
                );
                if (next == _offsetX) return;
                setState(() => _offsetX = next);
              },
        onHorizontalDragEnd: !widget.enabled
            ? null
            : (_) {
                final shouldOpen = _offsetX.abs() > _actionWidth * 0.4;
                setState(() {
                  _offsetX = shouldOpen ? -_actionWidth : 0;
                });
              },
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _actionWidth,
                  height: double.infinity,
                  child: FilledButton(
                    onPressed: !widget.enabled
                        ? null
                        : () async {
                            await widget.onDelete();
                            if (!mounted) return;
                            _close();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.colors.alert,
                      foregroundColor: widget.colors.textHighOnInverse,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '削除',
                      style: typography.jaOnl14B100.copyWith(
                        color: widget.colors.textHighOnInverse,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_offsetX, 0, 0),
              child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
