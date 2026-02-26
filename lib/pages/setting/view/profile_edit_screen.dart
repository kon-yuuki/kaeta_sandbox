import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../main.dart';
import '../../start/view/start_screen.dart';

const List<String> _presetIcons = [
  'assets/icons/avatars/img_Men01.png',
  'assets/icons/avatars/img_Men02.png',
  'assets/icons/avatars/img_Men03.png',
  'assets/icons/avatars/img_Men04.png',
  'assets/icons/avatars/img_Men05.png',
  'assets/icons/avatars/img_Men06.png',
  'assets/icons/avatars/img_Women01.png',
  'assets/icons/avatars/img_Women02.png',
  'assets/icons/avatars/img_Women03.png',
  'assets/icons/avatars/img_Women04.png',
  'assets/icons/avatars/img_Women05.png',
  'assets/icons/avatars/img_Women06.png',
];

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CommonAppBar(showBackButton: true, title: 'プロフィール'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: ProfileEditSection(),
        ),
      ),
    );
  }
}

class ProfileEditSection extends ConsumerStatefulWidget {
  const ProfileEditSection({super.key});

  @override
  ConsumerState<ProfileEditSection> createState() => _ProfileEditSectionState();
}

class _ProfileEditSectionState extends ConsumerState<ProfileEditSection> {
  static const int _maxLength = 15;
  late final TextEditingController _nameController;
  String _seededName = '';
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _loginProviderLabel() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return 'ゲスト';

    final providers = _linkedProviders(user);
    if (providers.contains('google') && providers.contains('apple')) {
      return 'Google / Apple';
    }
    if (providers.contains('google')) return 'Google';
    if (providers.contains('apple')) return 'Apple';
    if (providers.contains('email')) return 'メール';
    return '連携済み';
  }

  String? _loginProviderLogoAsset() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final providers = _linkedProviders(user);
    if (providers.contains('google')) return 'assets/icons/img_GoogleLogo.png';
    if (providers.contains('apple')) return 'assets/icons/img_AppleLogo.png';
    return null;
  }

  Set<String> _linkedProviders(User user) {
    final providers = <String>{};
    final identities = user.identities ?? const <UserIdentity>[];
    for (final identity in identities) {
      providers.add(identity.provider.toLowerCase());
    }
    final appProvider = (user.appMetadata['provider'] as String?)?.toLowerCase();
    if (appProvider != null && appProvider.isNotEmpty) {
      providers.add(appProvider);
    }
    return providers;
  }

  UserIdentity? _findIdentityByProvider(User? user, String provider) {
    if (user == null) return null;
    final identities = user.identities ?? const <UserIdentity>[];
    for (final identity in identities) {
      if (identity.provider.toLowerCase() == provider.toLowerCase()) {
        return identity;
      }
    }
    return null;
  }

  String _authErrorMessage(Object error) {
    if (error is AuthException) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('manual_linking_disabled')) {
        return '現在の設定ではアカウント連携が無効です';
      }
      if (lower.contains('identity_already_exists')) {
        return 'この連携先は別のアカウントで使用されています';
      }
      if (lower.contains('single_identity_not_deletable') ||
          lower.contains('email_conflict_identity_not_deletable')) {
        return 'この連携は解除できません。ログイン方法を1つ以上残してください';
      }
      if (lower.contains('provider_disabled')) {
        return 'このプロバイダは現在利用できません';
      }
      return msg;
    }
    return 'エラーが発生しました: $error';
  }

  bool _isValidEmail(String input) {
    final email = input.trim();
    if (email.isEmpty) return false;
    final exp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return exp.hasMatch(email);
  }

  Future<User?> _fetchLatestUser() async {
    final supabase = Supabase.instance.client;
    try {
      final userResponse = await supabase.auth.getUser();
      return userResponse.user ?? supabase.auth.currentUser;
    } catch (_) {
      return supabase.auth.currentUser;
    }
  }

  Future<void> _showEmailUpdateSheet() async {
    final user = Supabase.instance.client.auth.currentUser;
    final currentEmail = user?.email ?? '-';
    final controller = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final count = controller.text.characters.length;
            final canSubmit = _isValidEmail(controller.text) && !isSubmitting;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF4B5E72),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'メールアドレス',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE6EBF2)),
                    const SizedBox(height: 14),
                    const Text(
                      '現在のメールアドレス',
                      style: TextStyle(
                        color: Color(0xFF687A95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentEmail,
                      style: const TextStyle(
                        color: Color(0xFF2C3844),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '新しいメールアドレスを入力',
                      style: TextStyle(
                        color: Color(0xFF687A95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: '例: sample.kaimono@icloud.com',
                        hintStyle: const TextStyle(color: Color(0xFF9AA8BC)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$count / 255文字',
                        style: TextStyle(
                          color: const Color(0xFF687A95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: canSubmit
                            ? () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await Supabase.instance.client.auth.updateUser(
                                    UserAttributes(email: controller.text.trim()),
                                  );
                                  if (!mounted) return;
                                  showTopSnackBar(
                                    this.context,
                                    '確認メールを送信しました。メールをご確認ください',
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  showTopSnackBar(this.context, _authErrorMessage(e));
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                  }
                                }
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: canSubmit
                              ? AppColors.of(context).surfaceHigh
                              : const Color(0xFFB7C2D2),
                          disabledBackgroundColor: const Color(0xFFB7C2D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                '確認メールを送信する',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAccountLinkageSheet() async {
    final supabase = Supabase.instance.client;
    User? sheetUser = supabase.auth.currentUser;
    bool appleBusy = false;
    bool googleBusy = false;
    bool manualLinkingDisabled = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        Future<void> refreshUser(StateSetter setSheetState) async {
          final latest = await _fetchLatestUser();
          if (!mounted) return;
          setSheetState(() {
            sheetUser = latest;
          });
          if (mounted) setState(() {});
        }

        Future<void> onLink(
          OAuthProvider provider,
          StateSetter setSheetState,
        ) async {
          if (provider == OAuthProvider.apple && appleBusy) return;
          if (provider == OAuthProvider.google && googleBusy) return;

          setSheetState(() {
            if (provider == OAuthProvider.apple) appleBusy = true;
            if (provider == OAuthProvider.google) googleBusy = true;
          });
          try {
            final providerKey =
                provider == OAuthProvider.apple ? 'apple' : 'google';
            await supabase.auth.linkIdentity(provider);
            var linked = false;
            for (var i = 0; i < 16; i++) {
              await Future.delayed(const Duration(milliseconds: 250));
              final latest = await _fetchLatestUser();
              if (latest != null && _linkedProviders(latest).contains(providerKey)) {
                linked = true;
                setSheetState(() {
                  sheetUser = latest;
                });
                if (mounted) setState(() {});
                break;
              }
            }
            if (linked) {
              if (mounted) showTopSnackBar(context, '連携しました');
            } else {
              if (mounted) {
                showTopSnackBar(
                  context,
                  '連携処理の完了を確認できませんでした。少し待って再度確認してください',
                );
              }
            }
          } catch (e) {
            if (e is AuthException &&
                e.message.toLowerCase().contains('manual_linking_disabled')) {
              setSheetState(() => manualLinkingDisabled = true);
            }
            if (mounted) showTopSnackBar(context, _authErrorMessage(e));
          } finally {
            if (sheetContext.mounted) {
              setSheetState(() {
                if (provider == OAuthProvider.apple) appleBusy = false;
                if (provider == OAuthProvider.google) googleBusy = false;
              });
            }
          }
        }

        Future<void> onUnlink(String provider, StateSetter setSheetState) async {
          final identity = _findIdentityByProvider(sheetUser, provider);
          if (identity == null) {
            if (mounted) showTopSnackBar(context, 'この連携は未接続です');
            return;
          }

          setSheetState(() {
            if (provider == 'apple') appleBusy = true;
            if (provider == 'google') googleBusy = true;
          });
          try {
            await supabase.auth.unlinkIdentity(identity);
            await refreshUser(setSheetState);
            if (mounted) showTopSnackBar(context, '連携を解除しました');
          } catch (e) {
            if (mounted) showTopSnackBar(context, _authErrorMessage(e));
          } finally {
            if (sheetContext.mounted) {
              setSheetState(() {
                if (provider == 'apple') appleBusy = false;
                if (provider == 'google') googleBusy = false;
              });
            }
          }
        }

        Widget providerRow({
          required String title,
          required String description,
          required String logoAsset,
          required String providerKey,
          required StateSetter setSheetState,
          required bool busy,
        }) {
          final linked = (sheetUser != null)
              ? _linkedProviders(sheetUser!).contains(providerKey)
              : false;
          final linkedCount = (sheetUser != null)
              ? _linkedProviders(sheetUser!)
                  .where((p) => p == 'apple' || p == 'google' || p == 'email')
                  .length
              : 0;
          final unlinkDisabledBySingleIdentity = linked && linkedCount <= 1;
          final linkDisabledByServer = !linked && manualLinkingDisabled;
          final actionDisabled =
              busy || unlinkDisabledBySingleIdentity || linkDisabledByServer;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Image.asset(logoAsset, width: 20, height: 20, fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF2C3844),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF687A95),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: actionDisabled
                      ? null
                      : () {
                          if (linked) {
                            onUnlink(providerKey, setSheetState);
                          } else {
                            onLink(
                              providerKey == 'apple'
                                  ? OAuthProvider.apple
                                  : OAuthProvider.google,
                              setSheetState,
                            );
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB7C2D2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 38),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : Icon(
                          linked ? Icons.link_off : Icons.link,
                          size: 16,
                          color: linked
                              ? const Color(0xFF4B5E72)
                              : const Color(0xFF2ECCA1),
                        ),
                  label: Text(
                    linked ? '連携解除' : '連携する',
                    style: TextStyle(
                      color: actionDisabled
                          ? const Color(0xFFACB7C8)
                          : linked
                          ? const Color(0xFF4B5E72)
                          : const Color(0xFF2ECCA1),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF4B5E72),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'アカウント連携',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    providerRow(
                      title: 'Apple',
                      description: 'Appleアカウントでログインできるようになります',
                      logoAsset: 'assets/icons/img_AppleLogo.png',
                      providerKey: 'apple',
                      setSheetState: setSheetState,
                      busy: appleBusy,
                    ),
                    providerRow(
                      title: 'Google',
                      description: 'Googleアカウントでログインできるようになります',
                      logoAsset: 'assets/icons/img_GoogleLogo.png',
                      providerKey: 'google',
                      setSheetState: setSheetState,
                      busy: googleBusy,
                    ),
                    if (manualLinkingDisabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '現在の設定ではアカウント連携が無効です',
                            style: TextStyle(
                              color: Color(0xFFCC2E59),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '連携解除には他のログイン方法の連携が必要です',
                            style: TextStyle(
                              color: Color(0xFF687A95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveName() async {
    final repository = ref.read(profileRepositoryProvider);
    final inputName = _nameController.text.trim().isEmpty
        ? 'ゲスト'
        : _nameController.text.trim();

    if (inputName == _seededName) return;

    await repository.updateProfile(inputName);
    if (!mounted) return;
    setState(() {
      _seededName = inputName;
    });
    showTopSnackBar(context, '名前を「$inputName」に保存しました');
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await db.disconnectAndClear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartPage()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    setState(() => _isDeletingAccount = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('delete_my_account');
      await supabase.auth.signOut();
      await db.disconnectAndClear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StartPage()),
        (_) => false,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == 'PGRST202') {
        showTopSnackBar(
          context,
          '削除機能のサーバー設定が未反映です（delete_my_account）',
        );
        return;
      }
      showTopSnackBar(context, 'アカウント削除に失敗しました: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(context, 'アカウント削除に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    if (_isDeletingAccount) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'アカウントを削除',
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 28 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'すべてのデータが完全に失われます。\nこの操作は取り消せません。よろしいですか？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 26 / 2,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isDeletingAccount
                        ? null
                        : () async {
                            Navigator.of(dialogContext).pop();
                            await _deleteAccount();
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF2D3B4A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isDeletingAccount
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '削除する',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Color(0xFF2C3844),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAvatarSelectionDialog() async {
    final profile = ref.read(myProfileProvider).value;
    final initialPreset = profile?.avatarPreset;
    final initialUrl = profile?.avatarUrl;

    final result = await showModalBottomSheet<_AvatarSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var selectedPreset = initialPreset;
        var selectedUrl = initialUrl;
        var withGlasses = _isGlassesPreset(initialPreset);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedImage = _avatarImageProvider(
              avatarUrl: selectedUrl,
              avatarPreset: selectedPreset,
            );
            final hasChanged =
                selectedPreset != initialPreset || selectedUrl != initialUrl;

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.94,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D7E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF4B5E72),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'アイコン',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 22 / 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFFFFD9D9),
                      backgroundImage: selectedImage,
                      child: selectedImage == null
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: Color(0xFF687A95),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'メガネをかける',
                            style: TextStyle(
                              color: Color(0xFF687A95),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch(
                            value: withGlasses,
                            onChanged: (value) {
                              setSheetState(() {
                                withGlasses = value;
                                if (selectedPreset != null) {
                                  selectedPreset = _presetForToggle(
                                    selectedPreset!,
                                    withGlasses,
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: _presetIcons.length,
                        itemBuilder: (context, index) {
                          final basePreset = _presetIcons[index];
                          final preset = _presetForToggle(basePreset, withGlasses);
                          final selected =
                              selectedPreset == preset && selectedUrl == null;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedPreset = preset;
                                selectedUrl = null;
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundImage: AssetImage(preset),
                                ),
                                if (selected)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2ECCA1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final toolbarColor = Theme.of(context).primaryColor;
                        final croppedPath = await _pickAndCropSquareImage(
                          toolbarColor: toolbarColor,
                        );
                        if (croppedPath == null) return;
                        setSheetState(() {
                          selectedUrl = croppedPath;
                          selectedPreset = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB7C2D2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFF687A95),
                        size: 18,
                      ),
                      label: const Text(
                        '写真から選ぶ',
                        style: TextStyle(
                          color: Color(0xFF687A95),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: hasChanged
                              ? () {
                                  Navigator.pop(
                                    sheetContext,
                                    _AvatarSelectionResult(
                                      preset: selectedPreset,
                                      url: selectedUrl,
                                    ),
                                  );
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            backgroundColor: hasChanged
                                ? AppColors.of(context).surfaceHigh
                                : const Color(0xFFB7C2D2),
                            disabledBackgroundColor: const Color(0xFFB7C2D2),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '保存する',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    await ref.read(profileRepositoryProvider).updateAvatar(
          preset: result.preset,
          url: result.url,
        );
    if (!mounted) return;
    showTopSnackBar(context, 'アイコンを変更しました');
  }

  Future<String?> _pickAndCropSquareImage({
    required Color toolbarColor,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '切り抜き',
          toolbarColor: toolbarColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '切り抜き',
          aspectRatioLockEnabled: true,
          resetButtonHidden: true,
        ),
      ],
    );
    return croppedFile?.path;
  }

  ImageProvider? _avatarImageProvider({String? avatarUrl, String? avatarPreset}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        return NetworkImage(avatarUrl);
      }
      return FileImage(File(avatarUrl));
    }
    if (avatarPreset != null && avatarPreset.isNotEmpty) {
      return AssetImage(avatarPreset);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final displayName = myProfile?.displayName?.trim() ?? '';
    final user = Supabase.instance.client.auth.currentUser;

    if (_seededName.isEmpty && displayName.isNotEmpty) {
      _seededName = displayName;
      _nameController.text = displayName;
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _showAvatarSelectionDialog,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFFFFD9D9),
                    backgroundImage: _avatarImageProvider(
                      avatarUrl: myProfile?.avatarUrl,
                      avatarPreset: myProfile?.avatarPreset,
                    ),
                    child: (myProfile?.avatarUrl == null ||
                            myProfile!.avatarUrl!.isEmpty) &&
                        (myProfile?.avatarPreset == null ||
                            myProfile!.avatarPreset!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: Color(0xFF687A95),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4B5E72),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '名前',
              style: TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: _maxLength,
            onSubmitted: (_) => _saveName(),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Color(0xFF2C3844),
              fontSize: 28 / 2,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_nameController.text.characters.length} / $_maxLength文字',
              style: const TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'その他',
              style: TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _infoRow(
                  title: 'アカウント連携',
                  value: _loginProviderLabel(),
                  valueLogoAsset: _loginProviderLogoAsset(),
                  showDivider: true,
                  onTap: _showAccountLinkageSheet,
                ),
                _infoRow(
                  title: 'メールアドレス',
                  value: user?.email ?? '-',
                  onTap: _showEmailUpdateSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 44),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                side: const BorderSide(color: Color(0xFFB7C2D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ログアウト',
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _showDeleteAccountDialog,
              child: const Text(
                'アカウントを削除する',
                style: TextStyle(
                  color: Color(0xFFCC2E59),
                  fontSize: 28 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String value,
    String? valueLogoAsset,
    bool showDivider = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFE6EBF2), width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2C3844),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (valueLogoAsset != null) ...[
                    Image.asset(
                      valueLogoAsset,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687A95),
                        fontSize: 30 / 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF9AA8BC)),
          ],
        ),
      ),
    );
  }
}

class _AvatarSelectionResult {
  const _AvatarSelectionResult({
    required this.preset,
    required this.url,
  });

  final String? preset;
  final String? url;
}
  bool _isGlassesPreset(String? preset) {
    return preset != null && preset.contains('_glasses');
  }

  String _toPlainPreset(String preset) {
    return preset.replaceFirst('_glasses', '');
  }

  String _toGlassesPreset(String preset) {
    if (preset.contains('_glasses')) return preset;
    return preset.replaceFirstMapped(
      RegExp(r'(\d+)\.png$'),
      (m) => '_glasses${m.group(1)}.png',
    );
  }

  String _presetForToggle(String basePreset, bool withGlasses) {
    final plain = _toPlainPreset(basePreset);
    return withGlasses ? _toGlassesPreset(plain) : plain;
  }
