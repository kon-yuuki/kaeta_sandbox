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
    AppNotification notification, {
    required String? myUserId,
  }) {
    if (notification.type != NotificationType.shoppingComplete) return false;
    if (notification.familyId == null || notification.familyId!.isEmpty) {
      return false;
    }
    if (notification.eventId == null || notification.eventId!.isEmpty) {
      return false;
    }
    final actorId = notification.actorUserId ?? notification.userId;
    if (myUserId == null || myUserId.isEmpty) return false;
    if (actorId == myUserId) return false;
    return true;
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
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(repo.setNotificationReaction(
                                notificationId: notification.id,
                                reactionEmoji: selected ? null : emoji,
                              ));
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

  Future<void> _openReactionMembersSheet({
    required BuildContext context,
    required List<AppNotificationReaction> eventReactions,
    required String initialEmoji,
    required Map<String, _NotificationAvatarData> avatarByUserId,
    required Map<String, String> nameByUserId,
  }) async {
    final appColors = AppColors.of(context);
    final reactionSummary = <String, int>{};
    for (final reaction in eventReactions) {
      reactionSummary[reaction.emoji] = (reactionSummary[reaction.emoji] ?? 0) + 1;
    }
    if (reactionSummary.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        var selectedEmoji =
            reactionSummary.containsKey(initialEmoji)
                ? initialEmoji
                : reactionSummary.keys.first;

        return Align(
          alignment: Alignment.bottomCenter,
          child: StatefulBuilder(
              builder: (context, setModalState) {
                final sheetWidth = MediaQuery.of(sheetContext).size.width;
                final tabHorizontalInset = sheetWidth * 0.1;
                final filtered = eventReactions
                    .where((r) => r.emoji == selectedEmoji)
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                return Container(
                  height: MediaQuery.of(sheetContext).size.height * 0.62,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: appColors.borderMedium,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.chevron_left),
                            splashRadius: 18,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'リアクション',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: appColors.borderDivider),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(
                        tabHorizontalInset,
                        10,
                        16,
                        0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: reactionSummary.entries.map((entry) {
                          final selected = entry.key == selectedEmoji;
                          return Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedEmoji = entry.key;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${entry.key} ${entry.value}',
                                    style: TextStyle(
                                      fontSize: 24 / 2,
                                      color: appColors.textHigh,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeOut,
                                    width: 58,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? appColors.accentPrimary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(
                      width: sheetWidth * 0.8,
                      child: Divider(height: 1, color: appColors.borderLow),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final reaction = filtered[index];
                          final name = nameByUserId[reaction.userId] ?? 'メンバー';
                          return Row(
                            children: [
                              _NotificationUserAvatar(
                                avatar: avatarByUserId[reaction.userId],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: appColors.textHigh,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  ),
                );
              },
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
    final nameByUserId = <String, String>{};
    for (final member in familyMembers) {
      avatarByUserId[member.userId] = _NotificationAvatarData(
        avatarUrl: member.avatarUrl,
        avatarPreset: member.avatarPreset,
      );
      nameByUserId[member.userId] = member.displayName;
    }
    if (myProfile != null) {
      avatarByUserId[myProfile.id] = _NotificationAvatarData(
        avatarUrl: myProfile.avatarUrl,
        avatarPreset: myProfile.avatarPreset,
      );
      nameByUserId[myProfile.id] =
          (myProfile.displayName?.trim().isNotEmpty ?? false)
              ? myProfile.displayName!.trim()
              : 'あなた';
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
                        final canReact = _canReactToNotification(
                          notification,
                          myUserId: myUserId,
                        );
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
                                        GestureDetector(
                                          onTap: () => _openReactionMembersSheet(
                                            context: context,
                                            eventReactions: eventReactions,
                                            initialEmoji: entry.key,
                                            avatarByUserId: avatarByUserId,
                                            nameByUserId: nameByUserId,
                                          ),
                                          child: Container(
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
