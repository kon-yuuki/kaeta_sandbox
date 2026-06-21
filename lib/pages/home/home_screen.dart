import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/home_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/board_provider.dart';
import '../../data/providers/items_provider.dart';
import '../../data/providers/billing_provider.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/model/database.dart';
import '../../data/model/powersync_connector.dart';
import '../../core/common_app_bar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_alert_dialog.dart';
import "widgets/todo_add_sheet.dart";
import 'widgets/todo_list_view.dart';
import 'widgets/home_bottom_nav_bar.dart';
import 'widgets/board_card.dart';
import 'widgets/today_completed_section.dart';
import '../history/history_screen.dart';
import 'view/category_edit_page.dart';
import 'todo_add_page.dart';
import '../../main.dart' show db;

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  static const double _quickAddSectionHeight = 60;
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

  String _notificationTitle(AppNotification notification) {
    final title = notification.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return notification.message;
  }

  String? _notificationBody(AppNotification notification) {
    final body = notification.body?.trim();
    if (body == null || body.isEmpty) {
      return null;
    }
    return body;
  }

  String _teamCompletedSummary(AppNotification notification) {
    final body = _notificationBody(notification);
    if (body != null && body.isNotEmpty) {
      return body.replaceFirst('。アプリからスタンプを送れます', '');
    }
    return _notificationTitle(notification);
  }

  int selectedPriorityForNew = 0;
  static const double _addPanelHeight = 360;
  late final TextEditingController _addNameController;
  late final FocusNode _addNameFocusNode;
  bool _isAddPanelVisible = false;
  bool _focusRequestedByTap = false;
  bool _keepAddSheetHeightForConfirm = false;
  double _lastKeyboardInset = 0;
  bool _didShowReadyDialog = false;
  bool _isShowingTeamCompleteDialog = false;
  late final ScrollController _scrollController;
  double _headerHeight = kToolbarHeight;
  double _headerHiddenOffset = 0;
  double _lastScrollOffset = 0;
  bool _isRefreshingHome = false;

  Future<void> initializeData() async {
    await ref.read(homeViewModelProvider).initializeData();
  }

  Future<void> _refreshHome() async {
    if (_isRefreshingHome) return;

    if (mounted) {
      setState(() {
        _isRefreshingHome = true;
      });
    } else {
      _isRefreshingHome = true;
    }
    try {
      FocusScope.of(context).unfocus();

      await ref
          .read(notificationsRepositoryProvider)
          .flushQueuedNotifications();
      await ref.read(itemsRepositoryProvider).processPendingReadings();

      await db.disconnectAndClear();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await db.connect(connector: SupabaseConnector(Supabase.instance.client));

      ref.invalidate(myProfileProvider);
      ref.invalidate(joinedFamiliesProvider);
      ref.invalidate(familyMembersProvider);
      ref.invalidate(todoListProvider);
      ref.invalidate(groupedTodoListProvider);
      ref.invalidate(todayCompletedListProvider);
      ref.invalidate(appNotificationsProvider);
      ref.invalidate(notificationReactionsProvider);
      ref.invalidate(currentBoardProvider);
      ref.invalidate(boardUnreadProvider);
      ref.invalidate(billingControllerProvider);

      await Future<void>.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingHome = false;
        });
      } else {
        _isRefreshingHome = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _addNameController = TextEditingController();
    _addNameFocusNode = FocusNode();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _addNameFocusNode.addListener(_handleAddNameFocusChanged);
    initializeData();
    ref.read(profileRepositoryProvider).ensureProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowReadyDialogs();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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

  void _handleScroll() {
    if (!_scrollController.hasClients || _isAddPanelVisible) return;

    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;
    _lastScrollOffset = currentOffset;

    final maxHiddenOffset = math.max(1.0, _headerHeight);
    final nextHiddenOffset = currentOffset <= 0
        ? 0.0
        : (_headerHiddenOffset + delta).clamp(0.0, maxHiddenOffset);

    if ((nextHiddenOffset - _headerHiddenOffset).abs() < 0.5) return;
    setState(() {
      _headerHiddenOffset = nextHiddenOffset;
    });
  }

  Future<void> _showReadyDialog() async {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
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
                Image.asset(
                  'assets/icons/circle-check.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                Text(
                  '準備が整いました!\n買い物リストを利用できます',
                  textAlign: TextAlign.center,
                  style: typography.std16B150.copyWith(color: colors.textHigh),
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
    double radius = 14,
    double fallbackIconSize = 16,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;
    if (hasUrl) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(0xFFF3D77A),
      child: Icon(Icons.person, size: fallbackIconSize, color: Colors.white),
    );
  }

  Future<void> _openReactionPicker({
    required BuildContext context,
    required AppNotification notification,
    String? currentReaction,
  }) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCCCCC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: appColors.borderLow),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'リアクション',
                            style: appTypography.std11M160.copyWith(
                              color: appColors.textLow,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
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
                ],
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
          final appColors = AppColors.of(dialogContext);
          final appTypography = AppTypography.of(dialogContext);
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF687A95),
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
                      width: 297,
                      height: 192,
                      child: Lottie.asset(
                        'assets/animations/complete_shopping.json',
                        fit: BoxFit.cover,
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'アイテムがすべて購入されました！',
                    textAlign: TextAlign.center,
                    style: appTypography.std16B150.copyWith(
                      color: appColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          radius: 16,
                          fallbackIconSize: 18,
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
                                      style: appTypography.jaOnl12B100.copyWith(
                                        color: appColors.textHigh,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatNotificationDateTime(
                                      notification.createdAt,
                                    ),
                                    style: appTypography.jaOnl12M120.copyWith(
                                      color: appColors.textLow,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _teamCompletedSummary(notification),
                                style: appTypography.std14R160.copyWith(
                                  color: appColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final billingState = ref.watch(billingControllerProvider);
                      if (!billingState.hasBasicOrAbove) {
                        return const SizedBox(height: 16);
                      }
                      final familyId = ref.watch(selectedFamilyIdProvider);
                      final reactions =
                          ref
                              .watch(notificationReactionsProvider)
                              .valueOrNull ??
                          const <AppNotificationReaction>[];
                      final eventId = notification.eventId;
                      final myUserId =
                          Supabase.instance.client.auth.currentUser?.id;

                      final eventReactions = eventId == null
                          ? const <AppNotificationReaction>[]
                          : reactions
                                .where(
                                  (reaction) => reaction.eventId == eventId,
                                )
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
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                11,
                                24,
                                11,
                              ),
                              decoration: BoxDecoration(
                                color: appColors.surfaceTertiary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'いまの気持ちを伝えてみませんか？',
                                      textAlign: TextAlign.right,
                                      style: appTypography.std11M160.copyWith(
                                        color: appColors.textLow,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: appColors.borderLow,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      'assets/icons/smile-plus.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: ColorFilter.mode(
                                        appColors.surfaceMedium,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 34),
                          ],
                        );
                      }

                      final reactionAddButton = GestureDetector(
                        onTap: () => _openReactionPicker(
                          context: dialogContext,
                          notification: notification,
                          currentReaction: myReaction,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 11, 24, 11),
                          decoration: BoxDecoration(
                            color: appColors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'いまの気持ちを伝えてみませんか？',
                                  textAlign: TextAlign.right,
                                  style: appTypography.std11M160.copyWith(
                                    color: appColors.textLow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: appColors.borderLow,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'assets/icons/smile-plus.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    appColors.surfaceMedium,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      final reactionIconButton = GestureDetector(
                        onTap: () => _openReactionPicker(
                          context: dialogContext,
                          notification: notification,
                          currentReaction: myReaction,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appColors.borderLow),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/smile-plus.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              appColors.surfaceMedium,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      );

                      if (reactionEntries.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 18),
                            reactionAddButton,
                            const SizedBox(height: 34),
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in reactionEntries)
                                      Container(
                                        width: 56,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: entry.key == myReaction
                                              ? const Color(0xFFE8FBF5)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: entry.key == myReaction
                                                ? const Color(0xFF2ECCA1)
                                                : appColors.borderLow,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                height: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              entry.value.toString(),
                                              style: appTypography.jaOnl12M120
                                                  .copyWith(
                                                    color: appColors.textHigh,
                                                    fontFamily: 'Inter',
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              reactionIconButton,
                            ],
                          ),
                          const SizedBox(height: 34),
                        ],
                      );
                    },
                  ),
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
                      child: Text(
                        '履歴をみる',
                        style: appTypography.std14B160.copyWith(
                          color: appColors.textHighOnInverse,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        '閉じる',
                        style: appTypography.std14R160.copyWith(
                          color: appColors.textHigh,
                        ),
                      ),
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

  Widget _buildQuickAddRow(
    BuildContext context,
    AppColors appColors, {
    required bool showAddPanel,
  }) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
        child: ListenableBuilder(
          listenable: _addNameFocusNode,
          builder: (context, _) {
            return Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _addNameController,
                    focusNode: _addNameFocusNode,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodoAddPage(),
                        ),
                      );
                    },
                    hintText: 'リストに追加',
                    prefixIcon: SizedBox(
                      width: 24,
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.translate(
                          offset: const Offset(4, 0),
                          child: SvgPicture.asset(
                            'assets/icons/plus.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              appColors.surfaceLow,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    hideUnfocusedBorder: !showAddPanel,
                    keepActiveBorder: showAddPanel,
                    fillColor: Colors.transparent,
                    textColor: appColors.surfaceLow,
                    hintColor: appColors.textLow,
                    textStyle: AppTypography.of(
                      context,
                    ).std18R160.copyWith(color: appColors.textLow),
                  ),
                ),
                if (!showAddPanel) ...[
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
                          builder: (context) => const CategoryEditPage(),
                        ),
                      );
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/exchange.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        appColors.textMedium,
                        BlendMode.srcIn,
                      ),
                    ),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 77,
                    height: 42,
                    child: TextButton.icon(
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
                      icon: SvgPicture.asset(
                        'assets/icons/left-instance.svg',
                        width: 20,
                        height: 24,
                      ),
                      label: Text(
                        '履歴',
                        style: AppTypography.of(context).jaOnl14B100.copyWith(
                          color: appColors.textHighOnInverse,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(77, 42),
                        fixedSize: const Size(77, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: appColors.textHighOnInverse,
                        backgroundColor: appColors.surfaceHigh,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
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
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    final billingState = ref.watch(billingControllerProvider);
    final showBoardCard = selectedFamilyId != null && billingState.hasPremium;
    final mediaTopPadding = MediaQuery.of(context).padding.top;
    final displayName =
        ref.watch(
          myProfileProvider.select((p) => p.valueOrNull?.displayName),
        ) ??
        'ゲスト';
    final families = ref.watch(joinedFamiliesProvider).valueOrNull ?? [];
    final selectedFamilyName = selectedFamilyId == null
        ? null
        : families
              .where((family) => family.id == selectedFamilyId)
              .firstOrNull
              ?.name;
    final headerTitle = selectedFamilyId == null
        ? '$displayNameのリスト'
        : '${selectedFamilyName ?? '家族'}のリスト';
    final headerTitleStyle = AppTypography.of(
      context,
    ).dsp22B140.copyWith(color: appColors.textHigh);
    final headerTitleAvailableWidth =
        MediaQuery.sizeOf(context).width - 16 - 8 - 44 - 108;
    final titlePainter = TextPainter(
      text: TextSpan(text: headerTitle, style: headerTitleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: math.max(0, headerTitleAvailableWidth));
    final isHeaderTitleTwoLines = titlePainter.computeLineMetrics().length > 1;
    final appBarHeight = isHeaderTitleTwoLines
        ? const CommonAppBar().preferredSize.height
        : kToolbarHeight;
    final minFamilyHeaderHeight = mediaTopPadding + appBarHeight + 122;
    final fixedHeaderTotalHeight = showBoardCard
        ? math.max(_headerHeight, minFamilyHeaderHeight)
        : math.max(_headerHeight, mediaTopPadding + kToolbarHeight);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardInset > 0 && keyboardInset > _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
    }
    final reserveAddPanelHeight = showAddPanel && !_addNameFocusNode.hasFocus;
    final headerVisibility =
        1 -
        (_headerHiddenOffset / math.max(1.0, fixedHeaderTotalHeight)).clamp(
          0.0,
          1.0,
        );
    final quickAddTop = math.max(
      mediaTopPadding,
      fixedHeaderTotalHeight - _quickAddSectionHeight - _headerHiddenOffset,
    );
    final showBottomNav = !showAddPanel && headerVisibility > 0.5;
    final showFloatingAddButton = !showAddPanel && headerVisibility <= 0.5;
    return PopScope(
      canPop: !showAddPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showAddPanel) {
          _attemptCloseAddPanel();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: selectedFamilyId == null
                ? appColors.accentPrimaryLight
                : Colors.white,
            extendBodyBehindAppBar: false,
            extendBody: false,
            resizeToAvoidBottomInset: false,
            appBar: null,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: selectedFamilyId == null
                        ? appColors.accentPrimaryLight
                        : appColors.backgroundGray,
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
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: fixedHeaderTotalHeight,
                        bottom: reserveAddPanelHeight ? _addPanelHeight : 0,
                      ),
                      child: Column(
                        children: [
                          // 今日買ったアイテム以降（白領域）
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: appColors.surfaceHighOnInverse,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: MediaQuery.sizeOf(context).height,
                              ),
                              child: Column(
                                children: [
                                  const TodayCompletedSection(),
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, -_headerHiddenOffset),
                    child: Opacity(
                      opacity: headerVisibility,
                      alwaysIncludeSemantics: headerVisibility > 0,
                      child: _MeasuredSize(
                        onChanged: (size) {
                          final nextHeight = size.height;
                          if ((_headerHeight - nextHeight).abs() < 0.5) {
                            return;
                          }
                          if (!mounted) return;
                          setState(() {
                            _headerHeight = nextHeight;
                            _headerHiddenOffset = _headerHiddenOffset.clamp(
                              0.0,
                              math.max(1.0, nextHeight),
                            );
                          });
                        },
                        child: Container(
                          color: selectedFamilyId == null
                              ? appColors.accentPrimaryLight
                              : appColors.backgroundGray,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: mediaTopPadding + appBarHeight,
                                child: CommonAppBar(
                                  isTransparent: true,
                                  showLogoutButton: false,
                                  alignTitleLeft: true,
                                  toolbarHeight: appBarHeight,
                                  extraActions: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        right: 4,
                                      ),
                                      child: IconButton(
                                        tooltip: '更新',
                                        alignment: Alignment.topCenter,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 40,
                                          minHeight: 40,
                                        ),
                                        onPressed: _isRefreshingHome
                                            ? null
                                            : () {
                                                _refreshHome();
                                              },
                                        icon: _isRefreshingHome
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                    ),
                                              )
                                            : Image.asset(
                                                'assets/icons/rotate-cw.png',
                                                width: 24,
                                                height: 24,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showBoardCard) const BoardCard(),
                              IgnorePointer(
                                child: Opacity(
                                  opacity: 0,
                                  child: _buildQuickAddRow(
                                    context,
                                    appColors,
                                    showAddPanel: showAddPanel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showAddPanel)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: appColors.surfaceHighOnInverse,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Material(
                        elevation: 0,
                        color: Colors.transparent,
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
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: showBottomNav
                ? MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: 1,
                      child: HomeBottomNavBar(
                        onAddPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TodoAddPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : null,
          ),
          if ((quickAddTop - mediaTopPadding).abs() < 0.5)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: quickAddTop,
              child: Container(
                color: selectedFamilyId == null
                    ? appColors.accentPrimaryLight
                    : appColors.backgroundGray,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: quickAddTop,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: selectedFamilyId == null
                    ? appColors.accentPrimaryLight
                    : appColors.backgroundGray,
                child: _buildQuickAddRow(
                  context,
                  appColors,
                  showAddPanel: showAddPanel,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 44,
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
                child: SizedBox(
                  width: 80,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          offset: const Offset(2, 5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Material(
                      color: appColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TodoAddPage(),
                            ),
                          );
                        },
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/plus.svg',
                            width: 30,
                            height: 30,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasuredSize extends StatefulWidget {
  const _MeasuredSize({required this.onChanged, required this.child});

  final ValueChanged<Size> onChanged;
  final Widget child;

  @override
  State<_MeasuredSize> createState() => _MeasuredSizeState();
}

class _MeasuredSizeState extends State<_MeasuredSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final size = renderObject.size;
      if (_lastSize == size) return;
      _lastSize = size;
      widget.onChanged(size);
    });

    return widget.child;
  }
}
