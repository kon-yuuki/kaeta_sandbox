import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/providers/notifications_provider.dart';
import '../../setting/view/setting_screen.dart';
import '../../notifications/notifications_screen.dart';

class HomeBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final VoidCallback? onAddPressed;

  const HomeBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = AppColors.of(context);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: appColors.surfaceHighOnInverse,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: appColors.surfacePrimary,
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: appColors.surfaceHighOnInverse,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                Icons.notifications_none,
                '通知',
                isSelected: currentIndex == 2,
                showBadge: unreadCount > 0,
                onTap: currentIndex == 2
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        ),
              ),
              // 中央のプラスボタン
              _buildAddButton(context),
              _buildNavItem(
                context,
                Icons.person,
                '設定',
                isSelected: currentIndex == 1,
                onTap: currentIndex == 1
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingPage(),
                          ),
                        ),
                avatarUrl: profile?.avatarUrl,
                avatarPreset: profile?.avatarPreset,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onAddPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label, {
    required bool isSelected,
    VoidCallback? onTap,
    String? avatarUrl,
    String? avatarPreset,
    bool showBadge = false,
  }) {
    final appColors = AppColors.of(context);
    final color = isSelected ? appColors.accentPrimary : appColors.surfaceLow;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildNavIcon(
                  color: color,
                  icon: icon,
                  avatarUrl: avatarUrl,
                  avatarPreset: avatarPreset,
                ),
                if (showBadge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: appColors.accentPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appColors.surfaceHighOnInverse,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required Color color,
    required IconData icon,
    String? avatarUrl,
    String? avatarPreset,
  }) {
    final hasAvatarUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasAvatarPreset = avatarPreset != null && avatarPreset.isNotEmpty;
    if (!hasAvatarUrl && !hasAvatarPreset) {
      return Icon(icon, color: color);
    }

    final ImageProvider avatarImage;
    if (hasAvatarUrl) {
      avatarImage = NetworkImage(avatarUrl);
    } else {
      avatarImage = AssetImage(avatarPreset!);
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
        image: DecorationImage(image: avatarImage, fit: BoxFit.cover),
      ),
    );
  }
}
