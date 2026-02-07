import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../setting/view/setting_screen.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback? onAddPressed;

  const HomeBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
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
                Icons.home,
                'ホーム',
                isSelected: currentIndex == 0,
                onTap: currentIndex == 0
                    ? null
                    : () => Navigator.pop(context),
              ),
              // 中央のプラスボタン
              _buildAddButton(context),
              _buildNavItem(
                context,
                Icons.settings,
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
  }) {
    final appColors = AppColors.of(context);
    final color = isSelected ? appColors.accentPrimary : appColors.surfaceLow;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
