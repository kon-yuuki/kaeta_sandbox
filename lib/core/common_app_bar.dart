import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../pages/login/view/login_screen.dart';
import '../data/providers/profiles_provider.dart';
import '../data/providers/families_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  static const double _toolbarHeight = 76;

  const CommonAppBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.title,
    this.isTransparent = false,
    this.showLogoutButton = true,
    this.alignTitleLeft = false,
    this.extraActions = const <Widget>[],
  });

  final bool showBackButton;
  final Future<bool> Function()? onBackPressed;
  final String? title;
  final bool isTransparent;
  final bool showLogoutButton;
  final bool alignTitleLeft;
  final List<Widget> extraActions;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // displayName だけを select で監視（プロフィール全体の変更でリビルドしない）
    final displayName =
        ref.watch(
          myProfileProvider.select((p) => p.valueOrNull?.displayName),
        ) ??
        'ゲスト';
    final familiesAsync = ref.watch(joinedFamiliesProvider);
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);

    // 選択中の家族名を取得
    String? selectedFamilyName;
    final families = familiesAsync.valueOrNull ?? [];
    if (selectedFamilyId != null) {
      final match = families.where((f) => f.id == selectedFamilyId);
      if (match.isNotEmpty) selectedFamilyName = match.first.name;
    }

    // 家族が存在するかどうか
    final hasFamily = families.isNotEmpty;
    final isPersonalMode = selectedFamilyId == null;
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);

    // 個人モード時の色
    final backgroundColor = isTransparent
        ? appColors.backgroundGray
        : (isPersonalMode ? appColors.accentPrimaryDark : null);
    final foregroundColor = isPersonalMode
        ? (isTransparent ? appColors.textHigh : appColors.textHighOnInverse)
        : null;
    final resolvedTitle =
        title ??
        (isPersonalMode ? '$displayNameのリスト' : '${selectedFamilyName ?? '家族'}のリスト');
    final familyToggle = hasFamily
        ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                if (isPersonalMode && families.isNotEmpty) {
                  ref
                      .read(profileRepositoryProvider)
                      .updateCurrentFamily(families.first.id);
                } else {
                  ref.read(profileRepositoryProvider).updateCurrentFamily(null);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      left: isPersonalMode ? 2 : 32,
                      top: 2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: isPersonalMode
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Icon(
                        Icons.group,
                        size: 20,
                        color: !isPersonalMode
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;
    final trailingWidgets = [
      ...extraActions,
      if (familyToggle != null) familyToggle,
    ];

    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: backgroundColor,
      surfaceTintColor: isTransparent ? Colors.transparent : null,
      elevation: isTransparent ? 0 : null,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      flexibleSpace: (isTransparent && isPersonalMode)
          ? SizedBox.expand(
              child: Image.asset(
                'assets/images/common/personal_header_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            )
          : null,
      foregroundColor: foregroundColor,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                final allowPop =
                    await (onBackPressed?.call() ?? Future.value(true));
                if (!context.mounted || !allowPop) return;
                Navigator.of(context).pop();
              },
            )
          : (showLogoutButton
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      await db.disconnectAndClear();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      }
                    },
                  )
                : null),
      automaticallyImplyLeading: false,
      centerTitle: alignTitleLeft ? false : null,
      titleSpacing: alignTitleLeft ? 0 : null,
      title: alignTitleLeft
          ? Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      resolvedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (Theme.of(context).appBarTheme.titleTextStyle ??
                                  appTypography.dsp21B140)
                              .copyWith(color: foregroundColor),
                    ),
                  ),
                  if (trailingWidgets.isNotEmpty) const SizedBox(width: 8),
                  ...trailingWidgets.map(
                    (widget) => Align(
                      alignment: Alignment.topCenter,
                      child: widget,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              resolvedTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  (Theme.of(context).appBarTheme.titleTextStyle ??
                          appTypography.dsp21B140)
                      .copyWith(color: foregroundColor),
            ),
      actions: alignTitleLeft ? const [] : trailingWidgets,
    );
  }
}
