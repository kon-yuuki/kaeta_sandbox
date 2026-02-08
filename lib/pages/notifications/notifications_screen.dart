import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_list_item.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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

  IconData _getTypeIcon(int type) {
    switch (type) {
      case NotificationType.shoppingComplete:
        return Icons.shopping_cart_checkout;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final notificationsAsync = ref.watch(appNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
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
                          ref.read(notificationsRepositoryProvider).clearAllNotifications(familyId);
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
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: appColors.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '通知はありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: appColors.textMedium,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final typeLabel = _getTypeLabel(notification.type);

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
                  ref.read(notificationsRepositoryProvider).deleteNotification(notification.id);
                },
                child: AppListItem(
                  showDivider: true,
                  leading: CircleAvatar(
                    backgroundColor: notification.type ==
                            NotificationType.shoppingComplete
                        ? appColors.accentPrimaryLight
                        : appColors.surfaceSecondary,
                    child: Icon(
                      _getTypeIcon(notification.type),
                      color: notification.type ==
                              NotificationType.shoppingComplete
                          ? appColors.accentPrimaryDark
                          : appColors.textMedium,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.message,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Row(
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
