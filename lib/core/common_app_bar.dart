import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../pages/login/view/login_screen.dart';
import '../data/providers/profiles_provider.dart';
import '../data/providers/families_provider.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CommonAppBar({super.key});

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

    return AppBar(
      title: PopupMenuButton<String>(
        offset: const Offset(0, 40),
        onSelected: (value) {
          ref.read(profileRepositoryProvider).updateCurrentFamily(
            value == '' ? null : value,
          );
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem<String>(
              value: '',
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  Text('$displayNameのメモ'),
                  if (selectedFamilyId == null) ...[
                    const Spacer(),
                    const Icon(Icons.check, color: Colors.blue, size: 20),
                  ],
                ],
              ),
            ),
            ...families.map((f) => PopupMenuItem<String>(
              value: f.id,
              child: Row(
                children: [
                  const Icon(Icons.group, size: 20),
                  const SizedBox(width: 8),
                  Text(f.name),
                  if (f.id == selectedFamilyId) ...[
                    const Spacer(),
                    const Icon(Icons.check, color: Colors.blue, size: 20),
                  ],
                ],
              ),
            )),
          ];
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selectedFamilyName ?? '$displayNameのメモ',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).appBarTheme.titleTextStyle ??
                    Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      actions: [
        IconButton(
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
      ],
    );
  }
}
