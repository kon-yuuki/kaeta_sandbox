import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_list_item.dart';
import '../../data/model/database.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const List<_ReactionCategory> _reactionCategories = [
    _ReactionCategory(
      icon: Icons.sentiment_satisfied_alt,
      label: 'よく使う',
      emojis: ['👍', '👏', '🙏', '❤️', '🎉', '🔥', '✅', '💯'],
    ),
    _ReactionCategory(
      icon: Icons.favorite_border,
      label: '気持ち',
      emojis: ['😊', '😍', '🥰', '😌', '😭', '😅', '😮', '😢'],
    ),
    _ReactionCategory(
      icon: Icons.celebration_outlined,
      label: 'お祝い',
      emojis: ['🎊', '🎈', '🙌', '✨', '🥳', '🍻', '🍾', '🎁'],
    ),
    _ReactionCategory(
      icon: Icons.more_horiz,
      label: 'その他',
      emojis: ['🤝', '🫶', '👀', '🤔', '👌', '🙇', '💪', '🛒'],
    ),
  ];

  bool get _isNotificationTab => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    // 画面を開いたらすべて既読にする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final familyId = ref.read(selectedFamilyIdProvider);
      ref.read(notificationsRepositoryProvider).markAllAsRead(familyId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  String _getTypeLabel(int type) {
    switch (type) {
      case NotificationType.shoppingComplete:
        return '買い物完了';
      default:
        return '';
    }
  }

  bool _canReactToNotification(
    AppNotification notification,
  ) {
    if (notification.type != NotificationType.shoppingComplete) return false;
    if (notification.familyId == null || notification.familyId!.isEmpty) {
      return false;
    }
    return notification.eventId != null && notification.eventId!.isNotEmpty;
  }

  Future<void> _openReactionPicker({
    required BuildContext context,
    required AppNotification notification,
    String? currentReaction,
  }) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final appColors = AppColors.of(context);
    var selectedCategory = 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        final sheetHeight = screenHeight * 0.62;
        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: StatefulBuilder(
              builder: (context, setModalState) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'スタンプを選ぶ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: appColors.surfaceHighOnInverse,
                        border: Border(
                          top: BorderSide(color: appColors.borderDivider),
                          bottom: BorderSide(color: appColors.borderDivider),
                        ),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _reactionCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (context, index) {
                          final category = _reactionCategories[index];
                          final selected = selectedCategory == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: IconButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedCategory = index;
                                });
                              },
                              icon: Icon(
                                category.icon,
                                color: selected
                                    ? appColors.bluePrimary
                                    : appColors.textLow,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: selected
                                    ? appColors.accentPrimaryLight
                                    : Colors.transparent,
                                side: BorderSide(
                                  color: selected
                                      ? appColors.borderAccentPrimary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount:
                            _reactionCategories[selectedCategory].emojis.length,
                        itemBuilder: (context, index) {
                          final emoji =
                              _reactionCategories[selectedCategory].emojis[index];
                          final selected = currentReaction == emoji;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(repo.setNotificationReaction(
                                notificationId: notification.id,
                                reactionEmoji: emoji,
                              ));
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? appColors.accentPrimaryLight
                                    : appColors.surfaceHighOnInverse,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? appColors.accentPrimary
                                      : appColors.borderDivider,
                                ),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (currentReaction != null && currentReaction.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(repo.setNotificationReaction(
                            notificationId: notification.id,
                            reactionEmoji: null,
                          ));
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('スタンプを外す'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String label,
    required AppColors colors,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: colors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            '$labelはありません',
            style: TextStyle(
              fontSize: 24 / 2,
              color: colors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final notificationsAsync = ref.watch(appNotificationsProvider);
    final reactionsAsync = ref.watch(notificationReactionsProvider);
    final familyMembers = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final myUserId = myProfile?.id;
    final reactions = reactionsAsync.valueOrNull ?? const <AppNotificationReaction>[];
    final reactionsByEventId = <String, List<AppNotificationReaction>>{};
    for (final reaction in reactions) {
      reactionsByEventId.putIfAbsent(reaction.eventId, () => []).add(reaction);
    }
    final avatarByUserId = <String, _NotificationAvatarData>{};
    for (final member in familyMembers) {
      avatarByUserId[member.userId] = _NotificationAvatarData(
        avatarUrl: member.avatarUrl,
        avatarPreset: member.avatarPreset,
      );
    }
    if (myProfile != null) {
      avatarByUserId[myProfile.id] = _NotificationAvatarData(
        avatarUrl: myProfile.avatarUrl,
        avatarPreset: myProfile.avatarPreset,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (_isNotificationTab)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('すべて削除'),
                      content: const Text('すべての通知を削除しますか？'),
                      actions: [
                        AppButton(
                          variant: AppButtonVariant.text,
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('キャンセル'),
                        ),
                        AppButton(
                          onPressed: () {
                            final familyId = ref.read(selectedFamilyIdProvider);
                            ref
                                .read(notificationsRepositoryProvider)
                                .clearAllNotifications(familyId);
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('削除'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('すべて削除'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              labelColor: appColors.accentPrimaryDark,
              unselectedLabelColor: appColors.textMedium,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              indicatorColor: appColors.accentPrimary,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: appColors.borderLow,
              tabs: const [
                Tab(height: 64, text: '通知'),
                Tab(height: 64, text: 'お知らせ'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                notificationsAsync.when(
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return _buildEmptyState(label: '通知', colors: appColors);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        final typeLabel = _getTypeLabel(notification.type);
                        final canReact = _canReactToNotification(notification);
                        final eventId = notification.eventId;
                        final eventReactions = eventId == null
                            ? const <AppNotificationReaction>[]
                            : (reactionsByEventId[eventId] ?? const <AppNotificationReaction>[]);
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

                        return Dismissible(
                          key: Key(notification.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: appColors.alert,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(notificationsRepositoryProvider)
                                .deleteNotification(notification.id);
                          },
                          child: AppListItem(
                            showDivider: true,
                            leading: _NotificationUserAvatar(
                              avatar: avatarByUserId[
                                notification.actorUserId ?? notification.userId
                              ],
                            ),
                            title: Text(
                              notification.message,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatDateTime(notification.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: appColors.textLow,
                                      ),
                                    ),
                                    if (typeLabel.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: appColors.accentPrimaryLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          typeLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: appColors.textAccentPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (canReact) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final entry in reactionEntries)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: entry.key == myReaction
                                                ? appColors.accentPrimaryLight
                                                : appColors.surfaceLow,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: entry.key == myReaction
                                                  ? appColors.accentPrimary
                                                  : appColors.borderLow,
                                            ),
                                          ),
                                          child: Text(
                                            '${entry.key} ${entry.value}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: entry.key == myReaction
                                                  ? appColors.textAccentPrimary
                                                  : appColors.textMedium,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      GestureDetector(
                                        onTap: () => _openReactionPicker(
                                          context: context,
                                          notification: notification,
                                          currentReaction: myReaction,
                                        ),
                                        child: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: appColors.surfaceHighOnInverse,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: appColors.borderDivider,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_reaction_outlined,
                                            color: appColors.textMedium,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('エラー: $e')),
                ),
                _buildEmptyState(label: 'お知らせ', colors: appColors),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationAvatarData {
  const _NotificationAvatarData({
    required this.avatarUrl,
    required this.avatarPreset,
  });

  final String? avatarUrl;
  final String? avatarPreset;
}

class _NotificationUserAvatar extends StatelessWidget {
  const _NotificationUserAvatar({required this.avatar});

  final _NotificationAvatarData? avatar;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final avatarUrl = avatar?.avatarUrl;
    final avatarPreset = avatar?.avatarPreset;
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;

    if (hasUrl) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors.accentPrimaryLight,
      child: Icon(
        Icons.person,
        color: colors.accentPrimaryDark,
      ),
    );
  }
}

class _ReactionCategory {
  const _ReactionCategory({
    required this.icon,
    required this.label,
    required this.emojis,
  });

  final IconData icon;
  final String label;
  final List<String> emojis;
}
