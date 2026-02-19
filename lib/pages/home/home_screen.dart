import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/home_provider.dart';
import '../../data/model/database.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../core/common_app_bar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
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
  double _lastKeyboardInset = 0;
  bool _didShowReadyDialog = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowReadyDialogs();
    });
  }

  @override
  void dispose() {
    _addNameFocusNode.removeListener(_handleAddNameFocusChanged);
    _addNameFocusNode.dispose();
    _addNameController.dispose();
    super.dispose();
  }

  void _handleAddNameFocusChanged() {
    if (mounted) {
      setState(() {});
    }

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

  Future<void> _showReadyDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    color: const Color(0xFF5A6E89),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2ECCA1),
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 30,
                    color: Color(0xFF2ECCA1),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '準備が整いました!\n買い物リストを利用できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 31 / 2,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3B4A),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybeShowReadyDialogs() async {
    if (!mounted || _didShowReadyDialog) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    // オンボーディング完了直後の表示（最優先）
    final pendingKey = 'home_ready_modal_pending_${user.id}';
    final shouldShowFromOnboarding = prefs.getBool(pendingKey) ?? false;
    if (shouldShowFromOnboarding) {
      _didShowReadyDialog = true;
      await _showReadyDialog();
      await prefs.setBool(pendingKey, false);
      return;
    }

    // ゲスト初回表示
    if (user.isAnonymous != true) return;

    final shownKey = 'guest_ready_modal_shown_${user.id}';
    final alreadyShown = prefs.getBool(shownKey) ?? false;
    if (alreadyShown) return;

    _didShowReadyDialog = true;
    await _showReadyDialog();

    await prefs.setBool(shownKey, true);
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
    final hasBudget = ref.read(addSheetDraftBudgetMaxAmountProvider) > 0;
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
    ref.read(addSheetDraftBudgetMinAmountProvider.notifier).state = 0;
    ref.read(addSheetDraftBudgetMaxAmountProvider.notifier).state = 0;
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
          AppButton(
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          AppButton(
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
    final todoListAsync = ref.watch(todoListProvider);
    final hasTodoItems = (todoListAsync.valueOrNull?.isNotEmpty ?? false);
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    final isPersonalMode = selectedFamilyId == null;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardInset > 0 && keyboardInset > _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
    }
    final reserveAddPanelHeight = showAddPanel && !_addNameFocusNode.hasFocus;
    return PopScope(
      canPop: !showAddPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showAddPanel) {
          _attemptCloseAddPanel();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: const CommonAppBar(
          isTransparent: true,
          showLogoutButton: false,
          alignTitleLeft: true,
        ),
        body: Stack(
          children: [
            if (isPersonalMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/common/personal_header_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (showAddPanel) {
                  await _attemptCloseAddPanel();
                }
              },
              child: Container(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  physics: (!hasTodoItems && !showAddPanel)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight,
                    bottom: reserveAddPanelHeight ? _addPanelHeight : 0,
                  ),
                  child: Column(
                    children: [
                  // 1. 掲示板（上部グレー領域）- 個人用モードでは非表示
                  if (selectedFamilyId != null)
                    const BoardCard(),

                  // 2. 今日買ったアイテム以降（白領域）
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: appColors.surfaceHighOnInverse,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height,
                      ),
                      child: Column(
                        children: [
                          const TodayCompletedSection(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 10.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
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
                                    hintText: 'リストに追加',
                                    prefixIcon: const Icon(Icons.add),
                                    hideUnfocusedBorder: true,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final current = ref.read(todoSortOrderProvider);
                                    ref.read(todoSortOrderProvider.notifier).state =
                                        current == TodoSortOrder.createdAt
                                            ? TodoSortOrder.priority
                                            : TodoSortOrder.createdAt;
                                  },
                                  icon: Icon(
                                    Icons.swap_vert_rounded,
                                    color: appColors.textMedium,
                                  ),
                                  splashRadius: 20,
                                ),
                                const SizedBox(width: 6),
                                TextButton.icon(
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
                                  icon: const Icon(Icons.history, size: 18),
                                  label: const Text(
                                    '履歴',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(88, 42),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: appColors.borderMedium),
                                    ),
                                    foregroundColor: appColors.textHigh,
                                    backgroundColor: appColors.surfaceHighOnInverse,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TodoItemList(
                            blockInteractions: showAddPanel,
                            onBlockedTap: () async {
                              await _attemptCloseAddPanel();
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                  hideOptionsWhileTyping: _addNameFocusNode.hasFocus,
                  lastKeyboardInset: _lastKeyboardInset,
                  onSuggestionSelected: () {
                    if (_addNameFocusNode.hasFocus) {
                      _addNameFocusNode.unfocus();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
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
