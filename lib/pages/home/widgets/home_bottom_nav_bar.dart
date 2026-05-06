import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/providers/notifications_provider.dart';
import '../../setting/view/setting_screen.dart';
import '../../notifications/notifications_screen.dart';

class HomeBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final VoidCallback? onAddPressed;

  const HomeBottomNavBar({super.key, this.currentIndex = 0, this.onAddPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = AppColors.of(context);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    return BottomAppBar(
      color: appColors.backgroundBase,
      elevation: 0,
      padding: EdgeInsets.zero,
      height: 90,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: appColors.borderDivider, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavItem(
                context,
                iconAsset: 'assets/icons/bell.svg',
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
    final appColors = AppColors.of(context);
    return Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 80,
          height: 46,
          child: Material(
            color: appColors.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            elevation: onAddPressed == null ? 0 : 3,
            shadowColor: Colors.black26,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onAddPressed,
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
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required bool isSelected,
    VoidCallback? onTap,
    String? iconAsset,
    String? avatarUrl,
    String? avatarPreset,
    bool showBadge = false,
  }) {
    final appColors = AppColors.of(context);
    final color = isSelected
        ? appColors.accentPrimary
        : appColors.surfaceMedium;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildNavIcon(
                  color: color,
                  iconAsset: iconAsset,
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
                        color: appColors.alert,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appColors.backgroundBase,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required Color color,
    String? iconAsset,
    String? avatarUrl,
    String? avatarPreset,
  }) {
    final hasAvatarUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasAvatarPreset = avatarPreset != null && avatarPreset.isNotEmpty;
    if (!hasAvatarUrl && !hasAvatarPreset) {
      if (iconAsset == null) {
        return Icon(Icons.person, color: color, size: 32);
      }
      return SvgPicture.asset(
        iconAsset,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    final ImageProvider avatarImage;
    if (hasAvatarUrl) {
      avatarImage = NetworkImage(avatarUrl);
    } else {
      avatarImage = AssetImage(avatarPreset!);
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: avatarImage, fit: BoxFit.cover),
      ),
    );
  }
}
