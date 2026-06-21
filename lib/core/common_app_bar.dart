import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../pages/login/view/login_screen.dart';
import '../data/providers/profiles_provider.dart';
import '../data/providers/families_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'widgets/app_page_header.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.title,
    this.isTransparent = false,
    this.showLogoutButton = true,
    this.alignTitleLeft = false,
    this.extraActions = const <Widget>[],
    this.toolbarHeight,
    this.bottom,
    this.showFamilyToggle = true,
  });

  final bool showBackButton;
  final Future<bool> Function()? onBackPressed;
  final String? title;
  final bool isTransparent;
  final bool showLogoutButton;
  final bool alignTitleLeft;
  final List<Widget> extraActions;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;
  final bool showFamilyToggle;

  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) +
        15 +
        (bottom?.preferredSize.height ?? 0),
  );

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
    final resolvedToolbarHeight = (toolbarHeight ?? kToolbarHeight) + 15;

    // 個人モード時の色
    final backgroundColor = isTransparent
        ? Colors.transparent
        : null;
    final foregroundColor = isPersonalMode
        ? appColors.textHigh
        : null;
    final resolvedTitle =
        title ??
        (isPersonalMode
            ? '$displayNameのリスト'
            : '${selectedFamilyName ?? '家族'}のリスト');
    final familyToggle = showFamilyToggle && hasFamily
        ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _FamilyModeToggle(
              isPersonalMode: isPersonalMode,
              onTap: () {
                if (isPersonalMode && families.isNotEmpty) {
                  ref
                      .read(profileRepositoryProvider)
                      .updateCurrentFamily(families.first.id);
                } else {
                  ref.read(profileRepositoryProvider).updateCurrentFamily(null);
                }
              },
            ),
          )
        : null;
    final trailingWidgets = [
      ...extraActions,
      if (familyToggle != null) familyToggle,
    ];
    final titleStyle =
        (showBackButton
                ? appTypography.titleSm16B160
                : (alignTitleLeft
                      ? appTypography.dsp22B140
                      : (Theme.of(context).appBarTheme.titleTextStyle ??
                            appTypography.dsp21B140)))
            .copyWith(color: foregroundColor ?? appColors.textHigh);

    return AppBar(
      toolbarHeight: resolvedToolbarHeight,
      bottom: bottom,
      backgroundColor: backgroundColor,
      surfaceTintColor: isTransparent ? Colors.transparent : null,
      elevation: isTransparent ? 0 : null,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      flexibleSpace: null,
      foregroundColor: foregroundColor,
      leading: showBackButton
          ? AppHeaderBackButton(
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
                      style: titleStyle,
                    ),
                  ),
                  if (trailingWidgets.isNotEmpty) const SizedBox(width: 8),
                  ...trailingWidgets.map(
                    (widget) =>
                        Align(alignment: Alignment.topCenter, child: widget),
                  ),
                ],
              ),
            )
          : Text(
              resolvedTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
      actions: alignTitleLeft ? const [] : trailingWidgets,
    );
  }
}

class _FamilyModeToggle extends StatefulWidget {
  const _FamilyModeToggle({required this.isPersonalMode, required this.onTap});

  final bool isPersonalMode;
  final VoidCallback onTap;

  @override
  State<_FamilyModeToggle> createState() => _FamilyModeToggleState();
}

class _FamilyModeToggleState extends State<_FamilyModeToggle> {
  late bool _isPersonalMode = widget.isPersonalMode;

  @override
  void didUpdateWidget(covariant _FamilyModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPersonalMode != oldWidget.isPersonalMode) {
      _isPersonalMode = widget.isPersonalMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPersonalMode = !_isPersonalMode;
        });
        widget.onTap();
      },
      child: Container(
        width: 96,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: appColors.surfacePrimary,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: _isPersonalMode
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    width: 44,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: appColors.surfaceHighOnInverse,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 10,
              child: SvgPicture.asset(
                'assets/icons/human.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  _isPersonalMode
                      ? appColors.accentPrimary
                      : appColors.surfaceMedium,
                  BlendMode.srcIn,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 10,
              child: SvgPicture.asset(
                'assets/icons/people.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  !_isPersonalMode
                      ? appColors.accentPrimary
                      : appColors.surfaceMedium,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
