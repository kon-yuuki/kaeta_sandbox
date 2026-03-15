import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/home_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/model/database.dart';
import '../../core/common_app_bar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_plus_button.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_alert_dialog.dart';
import "widgets/todo_add_sheet.dart";
import 'widgets/todo_list_view.dart';
import 'widgets/home_bottom_nav_bar.dart';
import 'widgets/board_card.dart';
import 'widgets/today_completed_section.dart';
import '../history/history_screen.dart';
import 'view/category_edit_page.dart';
import 'todo_add_page.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  static const List<String> _reactionEmojis = [
    '👍',
    '👏',
    '🙏',
    '💪',
    '✨',
    '⭐',
    '🎉',
    '🎊',
    '✅',
    '❌',
    '❤️',
    '💚',
    '💛',
    '💙',
    '🧡',
    '💜',
    '💯',
    '😊',
    '☺️',
    '😄',
    '😆',
    '😂',
    '🤣',
    '😍',
    '🥰',
    '😘',
    '😋',
    '😎',
    '🤔',
    '😮',
    '😢',
    '😭',
    '😡',
    '🥺',
    '🙌',
    '👌',
    '✌️',
    '🤝',
    '🫶',
    '🙆‍♀️',
    '🙆‍♂️',
    '🙆',
    '🙇‍♀️',
    '🙇‍♂️',
    '🙇',
    '💑',
  ];
  int selectedPriorityForNew = 0;
  static const double _addPanelHeight = 360;
  static const double _pinnedBoardAreaHeight = 86;
  late final TextEditingController _addNameController;
  late final FocusNode _addNameFocusNode;
  bool _isAddPanelVisible = false;
  bool _focusRequestedByTap = false;
  bool _keepAddSheetHeightForConfirm = false;
  double _lastKeyboardInset = 0;
  bool _didShowReadyDialog = false;
  bool _isShowingTeamCompleteDialog = false;
  bool _isHeaderVisible = true;

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

  String _formatNotificationDateTime(DateTime dt) {
    final local = dt.toLocal();
    final yy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$yy/$mm/$dd $hh:$min';
  }

  Widget _buildMemberAvatar({
    required String? avatarUrl,
    required String? avatarPreset,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;
    if (hasUrl) {
      return CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatarUrl));
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFF3D77A),
      child: Icon(Icons.person, size: 16, color: Colors.white),
    );
  }

  Future<void> _openReactionPicker({
    required BuildContext context,
    required AppNotification notification,
    String? currentReaction,
  }) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final appColors = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        final sheetHeight = screenHeight * 0.56;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: appColors.borderMedium,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'リアクション',
                      style: TextStyle(
                        color: appColors.textLow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              childAspectRatio: 1,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                        itemCount: _reactionEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _reactionEmojis[index];
                          final selected = currentReaction == emoji;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await repo.setNotificationReaction(
                                notificationId: notification.id,
                                reactionEmoji: selected ? null : emoji,
                              );
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? appColors.accentPrimaryLight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 31),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTeamCompletedDialog(
    AppNotification notification, {
    required String actorName,
    String? actorAvatarUrl,
    String? actorAvatarPreset,
  }) async {
    if (!mounted || _isShowingTeamCompleteDialog) return;
    _isShowingTeamCompleteDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                      color: const Color(0xFF687A95),
                      splashRadius: 20,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 170,
                      child: Lottie.asset(
                        'assets/animations/complete_shopping.json',
                        fit: BoxFit.cover,
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'アイテムがすべて購入されました！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A46),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMemberAvatar(
                          avatarUrl: actorAvatarUrl,
                          avatarPreset: actorAvatarPreset,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      actorName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E3A46),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatNotificationDateTime(
                                      notification.createdAt,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7C95),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.message,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF2E3A46),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final familyId = ref.watch(selectedFamilyIdProvider);
                      final reactions = ref.watch(
                        notificationReactionsProvider,
                      ).valueOrNull ??
                          const <AppNotificationReaction>[];
                      final eventId = notification.eventId;
                      final myUserId = Supabase.instance.client.auth.currentUser?.id;

                      final eventReactions = eventId == null
                          ? const <AppNotificationReaction>[]
                          : reactions
                              .where((reaction) => reaction.eventId == eventId)
                              .toList();

                      String? myReaction;
                      if (myUserId != null) {
                        for (final reaction in eventReactions) {
                          if (reaction.userId == myUserId) {
                            myReaction = reaction.emoji;
                            break;
                          }
                        }
                      }

                      final reactionSummary = <String, int>{};
                      for (final reaction in eventReactions) {
                        reactionSummary[reaction.emoji] =
                            (reactionSummary[reaction.emoji] ?? 0) + 1;
                      }
                      final reactionEntries = reactionSummary.entries.toList()
                        ..sort((a, b) {
                          final aMine = a.key == myReaction ? 1 : 0;
                          final bMine = b.key == myReaction ? 1 : 0;
                          if (aMine != bMine) return bMine - aMine;
                          return b.value - a.value;
                        });

                      final canReact =
                          familyId != null &&
                          familyId.isNotEmpty &&
                          eventId != null &&
                          eventId.isNotEmpty;

                      if (!canReact) {
                        return OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.add_reaction_outlined, size: 20),
                          label: const Text('リアクションを追加'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF425269),
                            side: const BorderSide(color: Color(0xFFD5DEE8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in reactionEntries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: entry.key == myReaction
                                    ? const Color(0xFFE8FBF5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: entry.key == myReaction
                                      ? const Color(0xFF2ECCA1)
                                      : const Color(0xFFD5DEE8),
                                ),
                              ),
                              child: Text(
                                '${entry.key} ${entry.value}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: entry.key == myReaction
                                      ? const Color(0xFF10A37F)
                                      : const Color(0xFF425269),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _openReactionPicker(
                              context: dialogContext,
                              notification: notification,
                              currentReaction: myReaction,
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F8FB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD5DEE8),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_reaction_outlined,
                                color: Color(0xFF425269),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                      child: const Text('+  履歴をみる'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      '閉じる',
                      style: TextStyle(color: Color(0xFF425269)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _isShowingTeamCompleteDialog = false;
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
    final hasBudget = ref.read(addSheetDraftBudgetMaxAmountProvider) > 0;
    final hasQuantityText = ref.read(addSheetDraftQuantityTextProvider) != null;
    return hasName ||
        hasPriority ||
        hasCategoryId ||
        hasBudget ||
        hasQuantityText;
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
    final shouldDiscard = await showAppConfirmDialog(
      context: context,
      title: '入力を破棄しますか？',
      message: '入力中の内容は削除されます。',
      confirmLabel: 'OK',
      cancelLabel: 'キャンセル',
      danger: true,
    );

    if (!mounted) return;
    setState(() => _keepAddSheetHeightForConfirm = false);

    if (shouldDiscard) {
      _clearAddDraft();
      _closeAddPanel();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is! UserScrollNotification) return false;

    if (notification.direction == ScrollDirection.reverse && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (notification.direction == ScrollDirection.forward &&
        !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AppNotification>>>(appNotificationsProvider, (
      _,
      next,
    ) async {
      final notifications = next.valueOrNull;
      if (notifications == null || notifications.isEmpty) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final currentFamilyId = ref.read(selectedFamilyIdProvider);
      if (currentFamilyId == null || currentFamilyId.isEmpty) return;

      AppNotification? target;
      for (final n in notifications) {
        if (n.type == NotificationType.shoppingAllCompleted &&
            n.isRead == false &&
            n.familyId == currentFamilyId &&
            (n.actorUserId != null && n.actorUserId != userId) &&
            (n.eventId?.isNotEmpty ?? false)) {
          target = n;
          break;
        }
      }
      if (target == null) return;

      final prefs = await SharedPreferences.getInstance();
      final shownKey = 'team_complete_modal_shown_${userId}_${target.eventId!}';
      if (prefs.getBool(shownKey) == true) return;
      if (!mounted) return;
      final actorUserId = target.actorUserId ?? target.userId;
      final members = await ref.read(familyMembersProvider.future);
      final actor = members.where((m) => m.userId == actorUserId).firstOrNull;
      if (!mounted) return;

      await prefs.setBool(shownKey, true);
      await ref
          .read(notificationsRepositoryProvider)
          .markEventAsRead(target.eventId!);
      await _showTeamCompletedDialog(
        target,
        actorName: actor?.displayName ?? 'メンバー',
        actorAvatarUrl: actor?.avatarUrl,
        actorAvatarPreset: actor?.avatarPreset,
      );
    });

    final appColors = AppColors.of(context);
    final showAddPanel = _isAddPanelVisible;
    final todoListAsync = ref.watch(todoListProvider);
    final hasTodoItems = (todoListAsync.valueOrNull?.isNotEmpty ?? false);
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    final isPersonalMode = selectedFamilyId == null;
    final mediaTopPadding = MediaQuery.of(context).padding.top;
    final fixedToolbarHeight = kToolbarHeight;
    final fixedBoardHeight = selectedFamilyId != null
        ? _pinnedBoardAreaHeight
        : 0.0;
    final fixedHeaderTotalHeight =
        mediaTopPadding + fixedToolbarHeight + fixedBoardHeight;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardInset > 0 && keyboardInset > _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
    }
    final reserveAddPanelHeight = showAddPanel && !_addNameFocusNode.hasFocus;
    final showBottomNav = !showAddPanel && _isHeaderVisible;
    final showFloatingAddButton = !showAddPanel && !_isHeaderVisible;
    return PopScope(
      canPop: !showAddPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showAddPanel) {
          _attemptCloseAddPanel();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: false,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        appBar: null,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (showAddPanel) {
                  await _attemptCloseAddPanel();
                }
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: Container(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    physics: (!hasTodoItems && !showAddPanel)
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: EdgeInsets.only(
                      top: fixedHeaderTotalHeight,
                      bottom: reserveAddPanelHeight ? _addPanelHeight : 0,
                    ),
                    child: Column(
                      children: [
                        // 今日買ったアイテム以降（白領域）
                        Container(
                          margin: EdgeInsets.only(top: isPersonalMode ? 0 : 8),
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
                                            _addNameFocusNode.canRequestFocus =
                                                true;
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
                                        onPressed: () async {
                                          if (showAddPanel) {
                                            await _attemptCloseAddPanel();
                                            if (_isAddPanelVisible) return;
                                          }
                                          if (!context.mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CategoryEditPage(),
                                            ),
                                          );
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
                                              builder: (context) =>
                                                  const HistoryScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.history,
                                          size: 18,
                                        ),
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
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: appColors.borderMedium,
                                            ),
                                          ),
                                          foregroundColor: appColors.textHigh,
                                          backgroundColor:
                                              appColors.surfaceHighOnInverse,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
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
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: 0, end: _isHeaderVisible ? 0 : 1),
                builder: (context, t, child) {
                  return Transform.translate(
                    offset: Offset(0, -10 * t),
                    child: Opacity(opacity: 1 - t, child: child),
                  );
                },
                child: SizedBox(
                  height: fixedHeaderTotalHeight,
                  child: Column(
                    children: [
                      SizedBox(
                        height: mediaTopPadding + kToolbarHeight,
                        child: const CommonAppBar(
                          isTransparent: true,
                          showLogoutButton: false,
                          alignTitleLeft: true,
                        ),
                      ),
                      if (selectedFamilyId != null)
                        Container(
                          color: appColors.backgroundGray,
                          child: const BoardCard(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: IgnorePointer(
                ignoring: !showFloatingAddButton,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  tween: Tween<double>(
                    begin: showFloatingAddButton ? 0 : 1,
                    end: showFloatingAddButton ? 1 : 0,
                  ),
                  builder: (context, t, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - t) * 10),
                      child: Opacity(opacity: t, child: child),
                    );
                  },
                  child: AppPlusButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodoAddPage(),
                        ),
                      );
                    },
                    size: AppPlusButtonSize.lg,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          opacity: showBottomNav ? 1 : 0,
          child: IgnorePointer(
            ignoring: !showBottomNav,
            child: HomeBottomNavBar(
              onAddPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TodoAddPage()),
                );
              },
            ),
          ),
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
