import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../pages/login/view/login_screen.dart';
import '../data/providers/profiles_provider.dart';
import '../data/providers/families_provider.dart';
import 'theme/app_colors.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.title,
  });

  final bool showBackButton;
  final Future<bool> Function()? onBackPressed;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // displayName だけを select で監視（プロフィール全体の変更でリビルドしない）
    final displayName = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.displayName),
    ) ?? 'ゲスト';
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

    // 個人モード時の色
    final backgroundColor = isPersonalMode ? appColors.accentPrimaryDark : null;
    final foregroundColor = isPersonalMode ? appColors.textHighOnInverse : null;

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                final allowPop = await (onBackPressed?.call() ?? Future.value(true));
                if (!context.mounted || !allowPop) return;
                Navigator.of(context).pop();
              },
            )
          : IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                await db.disconnectAndClear();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              },
            ),
      automaticallyImplyLeading: false,
      title: Text(
        title ??
            (isPersonalMode
                ? '$displayNameのメモ'
                : (selectedFamilyName ?? '家族のメモ')),
        overflow: TextOverflow.ellipsis,
        style: (Theme.of(context).appBarTheme.titleTextStyle ??
            Theme.of(context).textTheme.titleLarge)?.copyWith(
          color: foregroundColor,
        ),
      ),
      actions: [
        if (hasFamily)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                if (isPersonalMode && families.isNotEmpty) {
                  // 家族モードに切り替え
                  ref.read(profileRepositoryProvider).updateCurrentFamily(
                    families.first.id,
                  );
                } else {
                  // 個人モードに切り替え
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
                    // スライドするサム（背景）
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
                    // 左アイコン（個人）
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
                    // 右アイコン（家族）
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
          ),
      ],
    );
  }
}
