import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_plus_button.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/providers/families_provider.dart';
import '../providers/home_provider.dart';
import '../todo_add_page.dart';
import '../view/todo_edit_page.dart';
import '../view/category_edit_page.dart';

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

  static const List<String> _quantityUnits = ['g', 'mg', 'ml'];

  String? _buildQuantityLabel(String? text, int? unit) {
    if (text == null || text.isEmpty) return null;
    if (unit == null || unit < 0 || unit >= _quantityUnits.length) return text;
    return '$text${_quantityUnits[unit]}';
  }

  String? _buildBudgetLabel(int? min, int? max, int? type) {
    if (max == null || max <= 0) return null;
    final base = '¥$max/${type == 1 ? '100g' : '1つ'}';
    if (min != null && min > 0) {
      return '¥$min〜${base.substring(1)}';
    }
    return base;
  }

  String _priorityLabel(int priority) {
    if (priority == 1) return '必ず条件を守る';
    return '目安でOK';
  }

  Color _priorityBackground(AppColors appColors, int priority) {
    if (priority == 1) return appColors.accentPrimaryLight;
    return appColors.surfaceTertiary;
  }

  Color _priorityTextColor(AppColors appColors, int priority) {
    if (priority == 1) return appColors.textAccentPrimary;
    return appColors.textMedium;
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

  void _showAllCompletedDialog(BuildContext context) {
    final appColors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                  color: appColors.textLow,
                  splashRadius: 20,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/home/complete_cat.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'お買い物お疲れでした！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E3A46),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '内容は履歴に保存されています\n次回リスト作成時に活用してくださいね',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4A5562),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3A46),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
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
                  width: 170,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                const Text(
                  'アイテムはありません',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36 / 2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3A46),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _emptyStateGreeting(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28 / 2,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A6E89),
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (categoryName != '指定なし')
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        icon: const Icon(Icons.edit, size: 20),
                                        tooltip: 'カテゴリを編集',
                                        onPressed: () {
                                          if (widget.blockInteractions) {
                                            widget.onBlockedTap?.call();
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CategoryEditPage(
                                                    initialCategoryName:
                                                        categoryName,
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
                                      )
                                    else
                                      const SizedBox(width: 28, height: 28),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 2,
                                child: AppPlusButton(
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
                                              ? todoItems.first.todo.categoryId
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  size: AppPlusButtonSize.sm,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...[
                        1,
                        0,
                      ].where((p) => todoItems.any((e) => e.todo.priority == p)).map((
                        priority,
                      ) {
                        final groupedItems = todoItems
                            .where((e) => e.todo.priority == priority)
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    children: List.generate(groupedItems.length, (
                                      index,
                                    ) {
                                      final combined = groupedItems[index];
                                      final quantityLabel = _buildQuantityLabel(
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
                                            actionLabel: '元に戻す',
                                            onAction: (snackBarContext) {
                                              ref
                                                  .read(homeViewModelProvider)
                                                  .addTodo(
                                                    text: deletedMaster.name,
                                                    category:
                                                        deletedTodo.category,
                                                    categoryId:
                                                        deletedTodo.categoryId,
                                                    reading:
                                                        deletedMaster
                                                            .reading
                                                            .isNotEmpty
                                                        ? deletedMaster.reading
                                                        : deletedTodo.name,
                                                    priority:
                                                        deletedTodo.priority,
                                                    budgetMinAmount: deletedTodo
                                                        .budgetMinAmount,
                                                    budgetMaxAmount: deletedTodo
                                                        .budgetMaxAmount,
                                                    budgetType:
                                                        deletedTodo.budgetType,
                                                    quantityText: deletedTodo
                                                        .quantityText,
                                                    quantityUnit: deletedTodo
                                                        .quantityUnit,
                                                    quantityCount: deletedTodo
                                                        .quantityCount,
                                                  )
                                                  .then((result) {
                                                    if (result != null) return;
                                                    if (!snackBarContext
                                                        .mounted)
                                                      return;
                                                    showTopSnackBar(
                                                      snackBarContext,
                                                      '元に戻せませんでした',
                                                      familyId: ref.read(
                                                        selectedFamilyIdProvider,
                                                      ),
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
                                                          .surfacePrimary,
                                                      width: 1,
                                                    ),
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding: EdgeInsets.fromLTRB(
                                              16,
                                              index == 0 ? 26 : 12,
                                              16,
                                              8,
                                            ),
                                            title: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (combined
                                                                      .todo
                                                                      .quantityCount !=
                                                                  null &&
                                                              combined
                                                                      .todo
                                                                      .quantityCount! >
                                                                  0)
                                                            Text(
                                                              ' x${combined.todo.quantityCount}',
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      if (metaLines
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          metaLines.join('\n'),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: AppCheckCircle(
                                              selected:
                                                  combined.todo.isCompleted ||
                                                  _pendingCompleteIds.contains(
                                                    combined.todo.id,
                                                  ),
                                              onTap: () async {
                                                if (widget.blockInteractions) {
                                                  widget.onBlockedTap?.call();
                                                  return;
                                                }
                                                final todoId = combined.todo.id;
                                                if (_pendingCompleteIds
                                                    .contains(todoId)) {
                                                  return;
                                                }
                                                setState(() {
                                                  _pendingCompleteIds.add(
                                                    todoId,
                                                  );
                                                });
                                                await Future.delayed(
                                                  _completeAnimationDelay,
                                                );
                                                final result = await ref
                                                    .read(homeViewModelProvider)
                                                    .completeTodo(
                                                      combined.todo,
                                                    );
                                                if (!mounted) return;
                                                setState(() {
                                                  _pendingCompleteIds.remove(
                                                    todoId,
                                                  );
                                                });
                                                if (context.mounted) {
                                                  showTopSnackBar(
                                                    context,
                                                    result.message,
                                                    saveToHistory: false,
                                                  );
                                                  if (result.allCompleted) {
                                                    _showAllCompletedDialog(
                                                      context,
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                            onTap: () {
                                              if (widget.blockInteractions) {
                                                widget.onBlockedTap?.call();
                                                return;
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      TodoEditPage(
                                                        item: combined.todo,
                                                        imageUrl: combined
                                                            .masterItem
                                                            .imageUrl,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 160,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
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
                                    child: Text(
                                      _priorityLabel(priority),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _priorityTextColor(
                                          appColors,
                                          priority,
                                        ),
                                      ),
                                    ),
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
  static const double _actionWidth = 108;
  double _offsetX = 0;

  bool get _isOpen => _offsetX <= -(_actionWidth / 2);

  void _close() {
    if (_offsetX == 0) return;
    setState(() => _offsetX = 0);
  }

  @override
  Widget build(BuildContext context) {
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
                      backgroundColor: widget.colors.accentPrimary,
                      foregroundColor: widget.colors.textHighOnInverse,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '削除',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
