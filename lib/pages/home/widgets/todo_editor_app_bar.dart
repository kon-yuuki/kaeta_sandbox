import 'package:flutter/material.dart';

import '../../../core/common_app_bar.dart';
import '../../../core/theme/app_colors.dart';

class TodoEditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TodoEditorAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.showFamilyToggle = true,
  });

  final String title;
  final Future<bool> Function()? onBackPressed;
  final bool showFamilyToggle;

  @override
  Size get preferredSize {
    const baseAppBar = CommonAppBar(
      showBackButton: true,
      showLogoutButton: false,
    );
    return Size.fromHeight(baseAppBar.preferredSize.height + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return CommonAppBar(
      showBackButton: true,
      title: title,
      showLogoutButton: false,
      showFamilyToggle: showFamilyToggle,
      onBackPressed: onBackPressed ?? () async {
        await Navigator.maybePop(context);
        return false;
      },
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          width: double.infinity,
          height: 1,
          color: colors.borderLow,
        ),
      ),
    );
  }
}
