import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/home_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../core/common_app_bar.dart';
import '../../core/theme/app_colors.dart';
import "widgets/todo_add_sheet.dart";
import 'widgets/todo_list_view.dart';
import 'widgets/home_bottom_nav_bar.dart';
import 'widgets/board_card.dart';
import 'widgets/today_completed_section.dart';
import '../history/history_screen.dart';
import 'todo_add_page.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  int selectedPriorityForNew = 0;
  static const double _addPanelHeight = 360;
  late final TextEditingController _addNameController;
  late final FocusNode _addNameFocusNode;
  bool _isAddPanelVisible = false;
  bool _focusRequestedByTap = false;
  bool _keepAddSheetHeightForConfirm = false;

  Future<void> initializeData() async {
    await ref.read(homeViewModelProvider).initializeData();
  }

  @override
  void initState() {
    super.initState();
    _addNameController = TextEditingController();
    _addNameFocusNode = FocusNode();
    _addNameFocusNode.addListener(_handleAddNameFocusChanged);
    initializeData();
    ref.read(profileRepositoryProvider).ensureProfile();
  }

  @override
  void dispose() {
    _addNameFocusNode.removeListener(_handleAddNameFocusChanged);
    _addNameFocusNode.dispose();
    _addNameController.dispose();
    super.dispose();
  }

  void _handleAddNameFocusChanged() {
    // タップ由来でないフォーカスは打ち消す（画面復帰時の自動フォーカス対策）
    if (_addNameFocusNode.hasFocus && !_focusRequestedByTap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _addNameFocusNode.hasFocus) {
          _addNameFocusNode.unfocus();
        }
      });
      return;
    }

    if (_addNameFocusNode.hasFocus) {
      _focusRequestedByTap = false;
    }
  }

  void _openAddPanel() {
    if (_isAddPanelVisible) return;
    ref.read(addSheetDiscardOnCloseProvider.notifier).state = false;
    _isAddPanelVisible = true;
    setState(() {});
  }

  void _closeAddPanel() {
    _isAddPanelVisible = false;
    _focusRequestedByTap = false;
    if (_addNameFocusNode.hasFocus) {
      _addNameFocusNode.unfocus();
    }
    // 次の明示タップまで自動フォーカスを禁止する。
    _addNameFocusNode.canRequestFocus = false;
    setState(() {});
  }

  bool _hasAddDraft() {
    final hasName = _addNameController.text.trim().isNotEmpty;
    final hasPriority = ref.read(addSheetDraftPriorityProvider) != 0;
    final hasCategoryId = ref.read(addSheetDraftCategoryIdProvider) != null;
    final hasBudget = ref.read(addSheetDraftBudgetAmountProvider) > 0;
    final hasQuantityText = ref.read(addSheetDraftQuantityTextProvider) != null;
    return hasName || hasPriority || hasCategoryId || hasBudget || hasQuantityText;
  }

  void _clearAddDraft() {
    ref.read(addSheetDiscardOnCloseProvider.notifier).state = true;
    _addNameController.clear();
    ref.read(addSheetDraftNameProvider.notifier).state = '';
    ref.read(addSheetDraftPriorityProvider.notifier).state = 0;
    ref.read(addSheetDraftCategoryIdProvider.notifier).state = null;
    ref.read(addSheetDraftCategoryNameProvider.notifier).state = '指定なし';
    ref.read(addSheetDraftBudgetAmountProvider.notifier).state = 0;
    ref.read(addSheetDraftBudgetTypeProvider.notifier).state = 0;
    ref.read(addSheetDraftQuantityTextProvider.notifier).state = null;
    ref.read(addSheetDraftQuantityUnitProvider.notifier).state = null;
  }

  Future<void> _attemptCloseAddPanel() async {
    if (!_isAddPanelVisible) return;

    if (!_hasAddDraft()) {
      ref.read(addSheetDiscardOnCloseProvider.notifier).state = true;
      _closeAddPanel();
      return;
    }

    setState(() => _keepAddSheetHeightForConfirm = true);
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('入力を破棄しますか？'),
        content: const Text('入力中の内容は削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _keepAddSheetHeightForConfirm = false);

    if (shouldDiscard == true) {
      _clearAddDraft();
      _closeAddPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final showAddPanel = _isAddPanelVisible;
    return PopScope(
      canPop: !showAddPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showAddPanel) {
          _attemptCloseAddPanel();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: const CommonAppBar(),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (showAddPanel) {
              await _attemptCloseAddPanel();
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: showAddPanel ? _addPanelHeight : 0,
            ),
            child: Column(
              children: [
                // 1. 掲示板
                const BoardCard(),

                // 2. 今日買ったアイテム
                const TodayCompletedSection(),

                // 3. テキストフィールド + 履歴ボタン
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // テキストフィールド（ここで入力）
                      Expanded(
                        child: TextField(
                          controller: _addNameController,
                          focusNode: _addNameFocusNode,
                          onTap: () {
                            _addNameFocusNode.canRequestFocus = true;
                            _focusRequestedByTap = true;
                            if (!_addNameFocusNode.hasFocus) {
                              _addNameFocusNode.requestFocus();
                            }
                            _openAddPanel();
                          },
                          decoration: InputDecoration(
                            hintText: 'リストにアイテムを追加',
                            prefixIcon: const Icon(Icons.add),
                            filled: true,
                            fillColor: appColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appColors.surfacePrimary),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appColors.surfacePrimary),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appColors.surfaceMedium),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 履歴ボタン
                      IconButton(
                        onPressed: () async {
                          if (showAddPanel) {
                            await _attemptCloseAddPanel();
                            if (_isAddPanelVisible) return;
                          }
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        style: IconButton.styleFrom(
                          backgroundColor: appColors.surfaceSecondary,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. 買い物リスト
                const TodoItemList(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: showAddPanel
            ? null
            : HomeBottomNavBar(
                onAddPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TodoAddPage(),
                    ),
                  );
                },
              ),
        bottomSheet: showAddPanel
            ? Material(
                elevation: 12,
                color: appColors.surfaceHighOnInverse,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: TodoAddSheet(
                  nameController: _addNameController,
                  readOnlyNameField: true,
                  hideNameField: true,
                  showHeader: false,
                  height: _addPanelHeight,
                  onClose: _closeAddPanel,
                  includeKeyboardInsetInBody: false,
                  keepKeyboardSpace: _keepAddSheetHeightForConfirm,
                ),
              )
            : null,
      ),
    );
  }
}
