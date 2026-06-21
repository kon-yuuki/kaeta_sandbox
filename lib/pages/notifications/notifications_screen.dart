import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/common_app_bar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_action_icons.dart';
import '../../core/widgets/app_bottom_sheet_header.dart';
import '../../data/model/database.dart';
import '../../data/providers/billing_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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

  @override
  void initState() {
    super.initState();
    // 画面を開いたらすべて既読にする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final familyId = ref.read(selectedFamilyIdProvider);
      ref.read(notificationsRepositoryProvider).markAllAsRead(familyId);
    });
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
      return '${dt.year}/${dt.month}/${dt.day}';
    }
  }

  String _notificationTitle(AppNotification notification) {
    final title = notification.title?.trim();
    if (title != null && title.isNotEmpty) {
      if (notification.type == NotificationType.shoppingAllCompleted &&
          !title.endsWith('🎉')) {
        return '$title🎉';
      }
      return title;
    }
    if (notification.type == NotificationType.shoppingAllCompleted &&
        !notification.message.endsWith('🎉')) {
      return '${notification.message}🎉';
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

  bool _canReactToNotification(
    AppNotification notification, {
    required String? myUserId,
  }) {
    final isShoppingNotification =
        notification.type == NotificationType.shoppingComplete ||
        notification.type == NotificationType.shoppingAllCompleted;
    if (!isShoppingNotification) return false;
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

  Future<String?> _openReactionPicker({
    required BuildContext context,
    required AppNotification notification,
    String? currentReaction,
  }) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    return showModalBottomSheet<String?>(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(25, 10, 25, 16),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: appColors.borderMedium,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: appColors.borderLow),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 14),
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
                              final nextReaction = selected ? null : emoji;
                              await repo.setNotificationReaction(
                                notificationId: notification.id,
                                reactionEmoji: nextReaction,
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext, nextReaction ?? '');
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

  Future<void> _openReactionMembersSheet({
    required BuildContext context,
    required AppNotification notification,
    required List<AppNotificationReaction> eventReactions,
    required String initialEmoji,
    required String? myReaction,
    required String? myUserId,
    required Map<String, _NotificationAvatarData> avatarByUserId,
    required Map<String, String> nameByUserId,
  }) async {
    final appColors = AppColors.of(context);
    if (eventReactions.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        var selectedEmoji = initialEmoji;
        var localMyReaction = myReaction;

        return Align(
          alignment: Alignment.bottomCenter,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final effectiveReactions = <AppNotificationReaction>[
                ...eventReactions,
              ];
              if (myUserId != null && myUserId.isNotEmpty) {
                effectiveReactions.removeWhere((r) => r.userId == myUserId);
                if (localMyReaction != null && localMyReaction!.isNotEmpty) {
                  final baseReaction = eventReactions.firstWhere(
                    (r) => r.eventId == notification.eventId,
                    orElse: () => AppNotificationReaction(
                      id: 'local-$myUserId-${notification.eventId ?? notification.id}',
                      eventId: notification.eventId ?? '',
                      familyId: notification.familyId ?? '',
                      userId: myUserId,
                      emoji: localMyReaction!,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  effectiveReactions.add(
                    baseReaction.copyWith(
                      userId: myUserId,
                      emoji: localMyReaction!,
                      updatedAt: DateTime.now(),
                    ),
                  );
                }
              }

              final reactionSummary = <String, int>{};
              for (final reaction in effectiveReactions) {
                reactionSummary[reaction.emoji] =
                    (reactionSummary[reaction.emoji] ?? 0) + 1;
              }
              if (reactionSummary.isEmpty) {
                return const SizedBox.shrink();
              }

              if (!reactionSummary.containsKey(selectedEmoji)) {
                selectedEmoji = reactionSummary.keys.first;
              }

              final filtered =
                  effectiveReactions
                      .where((r) => r.emoji == selectedEmoji)
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              final reactionTabs = reactionSummary.entries.toList()
                ..sort((a, b) {
                  final aSelected = a.key == selectedEmoji ? 1 : 0;
                  final bSelected = b.key == selectedEmoji ? 1 : 0;
                  if (aSelected != bSelected) return bSelected - aSelected;
                  return b.value - a.value;
                });

              return Container(
                height: MediaQuery.of(sheetContext).size.height * 0.62,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    AppBottomSheetHeader(
                      title: 'リアクション',
                      onBack: () => Navigator.of(sheetContext).pop(),
                      trailing: TextButton(
                        onPressed: () async {
                          final nextReaction = await _openReactionPicker(
                            context: sheetContext,
                            notification: notification,
                            currentReaction: localMyReaction,
                          );
                          if (nextReaction == null) return;
                          setModalState(() {
                            localMyReaction = nextReaction.isEmpty
                                ? null
                                : nextReaction;
                            if (localMyReaction != null) {
                              selectedEmoji = localMyReaction!;
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: appColors.textHigh,
                          textStyle: AppTypography.of(sheetContext)
                              .jaOnl14Sb100
                              .copyWith(color: appColors.textHigh),
                        ),
                        child: const Text('編集'),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 25,
                            right: 25,
                            bottom: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: appColors.borderLow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 25,
                            right: 25,
                            bottom: 0,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: reactionTabs.map((entry) {
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 58,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    entry.key,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: appColors.textHigh,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${entry.value}',
                                                    style: AppTypography.of(
                                                      sheetContext,
                                                    ).egOnl12M140.copyWith(
                                                      height: 1.2,
                                                      color: appColors.textHigh,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 58,
                                              height: 3,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  width: 58,
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? appColors.accentPrimary
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(25, 14, 25, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final reaction = filtered[index];
                          final name = nameByUserId[reaction.userId] ?? 'メンバー';
                          return Row(
                            children: [
                              _NotificationUserAvatar(
                                type: NotificationType.normal,
                                avatar: avatarByUserId[reaction.userId],
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTypography.of(
                                    context,
                                  ).jaOnl12B100.copyWith(
                                    color: appColors.textHigh,
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

  Widget _buildEmptyState({required String label, required AppColors colors}) {
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
    final appTypography = AppTypography.of(context);
    final notificationsAsync = ref.watch(appNotificationsProvider);
    final reactionsAsync = ref.watch(notificationReactionsProvider);
    final billingState = ref.watch(billingControllerProvider);
    final familyMembers =
        ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final myUserId = myProfile?.id;
    final reactions =
        reactionsAsync.valueOrNull ?? const <AppNotificationReaction>[];
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
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        showBackButton: true,
        showLogoutButton: false,
        showFamilyToggle: false,
        title: '通知一覧',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            width: double.infinity,
            height: 1,
            color: appColors.borderLow,
          ),
        ),
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(label: '通知', colors: appColors);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final canReact =
                  billingState.hasBasicOrAbove &&
                  _canReactToNotification(notification, myUserId: myUserId);
              final eventId = notification.eventId;
              final eventReactions = eventId == null
                  ? const <AppNotificationReaction>[]
                  : (reactionsByEventId[eventId] ??
                        const <AppNotificationReaction>[]);
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

              final notificationBody = _notificationBody(notification);

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: appColors.alert,
                  child: const AppActionIcon.trash(color: Colors.white),
                ),
                onDismissed: (_) {
                  ref
                      .read(notificationsRepositoryProvider)
                      .deleteNotification(notification.id);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: appColors.borderDivider, width: 1),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final centerMaxWidth = (constraints.maxWidth - 148).clamp(
                        120.0,
                        300.0,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NotificationUserAvatar(
                              type: notification.type,
                              avatar:
                                  avatarByUserId[notification.actorUserId ??
                                      notification.userId],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: centerMaxWidth,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _notificationTitle(notification),
                                      style: appTypography.std14B160.copyWith(
                                        color: appColors.textHigh,
                                      ),
                                    ),
                                    if (notificationBody != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        notificationBody,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: appTypography.std14R160,
                                      ),
                                    ],
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
                                                notification: notification,
                                                eventReactions: eventReactions,
                                                initialEmoji: entry.key,
                                                myReaction: myReaction,
                                                myUserId: myUserId,
                                                avatarByUserId: avatarByUserId,
                                                nameByUserId: nameByUserId,
                                              ),
                                              child: Container(
                                                width: 56,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: entry.key == myReaction
                                                      ? appColors.accentPrimaryLight
                                                      : appColors.surfaceTertiary,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: entry.key == myReaction
                                                      ? Border.all(
                                                          color: appColors.accentPrimary,
                                                        )
                                                      : null,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${entry.value}',
                                                      style: appTypography.egOnl12M140.copyWith(
                                                        color: entry.key == myReaction
                                                            ? appColors.textAccentPrimary
                                                            : appColors.textMedium,
                                                      ),
                                                    ),
                                                  ],
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
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: appColors.surfaceHighOnInverse,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: appColors.borderLow,
                                                ),
                                              ),
                                              child: Center(
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
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 72,
                              child: Text(
                                _formatDateTime(notification.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                textAlign: TextAlign.right,
                                style: appTypography.egOnl12M140.copyWith(
                                  height: 1.2,
                                  color: appColors.textLow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
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
  const _NotificationUserAvatar({
    required this.avatar,
    required this.type,
    this.size = 32,
  });

  final _NotificationAvatarData? avatar;
  final int type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = size / 2;
    final iconSize = size * 0.5625;
    if (type == NotificationType.reminder) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/icons/logo.svg'),
      );
    }
    final avatarUrl = avatar?.avatarUrl;
    final avatarPreset = avatar?.avatarPreset;
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;

    if (hasUrl) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(avatarUrl));
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.accentPrimaryLight,
      child: Icon(
        Icons.person,
        size: iconSize,
        color: colors.accentPrimaryDark,
      ),
    );
  }
}
