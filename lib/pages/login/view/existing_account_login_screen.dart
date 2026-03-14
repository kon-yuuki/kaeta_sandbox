import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/device_tokens_repository.dart';
import '../../invite/view/invite_start_screen.dart';

class ExistingAccountLoginPage extends StatefulWidget {
  const ExistingAccountLoginPage({
    super.key,
    this.asModal = false,
  });

  final bool asModal;

  @override
  State<ExistingAccountLoginPage> createState() =>
      _ExistingAccountLoginPageState();
}

class _ExistingAccountLoginPageState extends State<ExistingAccountLoginPage> {
  final supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSub;
  bool _handledSignedIn = false;
  final DeviceTokensRepository _deviceTokensRepository =
      DeviceTokensRepository();

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (_handledSignedIn) return;
      if (event.session == null) return;
      _handledSignedIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleSignedInNavigation();
      });
    });
  }

  Future<void> _handleSignedInNavigation() async {
    unawaited(_syncDeviceTokenIfPossible());

    final prefs = await SharedPreferences.getInstance();
    final pendingInviteId = prefs.getString('pending_invite_id');
    final hasPendingInvite =
        pendingInviteId != null && pendingInviteId.isNotEmpty;
    if (!mounted) return;

    if (hasPendingInvite) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => InviteStartPage(inviteId: pendingInviteId),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    _showLoginSuccessSnackBar();
    // RootGate経由でDB接続/プロフィール同期/オンボーディング判定を行う。
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  Future<void> _syncDeviceTokenIfPossible() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        debugPrint('Skip device token sync: current user is null.');
        return;
      }
      await _deviceTokensRepository.upsertCurrentDeviceToken(userId: userId);
      debugPrint(
        'Device token synced after existing-account login. userId=$userId',
      );
    } catch (e, st) {
      debugPrint('Failed to sync device token after login: $e');
      debugPrint('$st');
    }
  }

  void _showLoginSuccessSnackBar() {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata;
    final metadataName = (metadata?['display_name'] ?? metadata?['name'])
        ?.toString()
        .trim();
    final email = user?.email?.trim();
    final fallbackName = (email != null && email.contains('@'))
        ? email.split('@').first
        : email;
    final name = (metadataName != null && metadataName.isNotEmpty)
        ? metadataName
        : (fallbackName != null && fallbackName.isNotEmpty
              ? fallbackName
              : 'ゲスト');

    showTopSnackBar(context, '$nameさんでログインしました', saveToHistory: false);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      final details = error.message.trim();
      if (details.isNotEmpty) {
        return 'Appleログインに失敗しました（${error.code.name}）: $details';
      }
      return 'Appleログインに失敗しました（${error.code.name}）。時間をおいて再試行してください。';
    }
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        return 'メールアドレスまたはパスワードが正しくありません';
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed')) {
        return 'メールアドレスが確認されていません。確認メールをご確認ください';
      }
      if (msg.contains('rate') || msg.contains('too many requests')) {
        return 'リクエストが多すぎます。しばらくしてからお試しください';
      }
      return 'エラーが発生しました: ${error.message}';
    }
    return '予期せぬエラーが発生しました。しばらくしてからお試しください';
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      const webClientId =
          '414455238092-e36235ggcq0h24lbbv4t56pbmcc03qt3.apps.googleusercontent.com';
      const iosClientId =
          '414455238092-l63u34jj0kliloeoh23lpb95cmfkp964.apps.googleusercontent.com';
      final scopes = ['email', 'profile'];

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
        clientId: iosClientId,
      );

      final googleUser = await googleSignIn.authenticate();
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) throw const AuthException('No ID Token found.');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => _isLoading = true);
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Apple ID Token が取得できませんでした。');
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスとパスワードを入力してください')));
      return;
    }
    try {
      setState(() => _isLoading = true);
      await supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.asModal,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, widget.asModal ? 10 : 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.asModal) ...[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'ログイン',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              const Text(
                'ログイン方法を選択してください',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              onPressed: _isLoading ? null : _handleAppleSignIn,
              child: const Text('Appleアカウントでログイン'),
            ),
            const SizedBox(height: 8),
            AppButton(
              variant: AppButtonVariant.outlined,
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              child: const Text('Googleでログイン'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              onPressed: _isLoading ? null : _handleEmailSignIn,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('メールアドレスでログイン'),
            ),
          ],
        ),
      ),
    );

    if (widget.asModal) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('すでにアカウントをお持ちの方')),
      body: content,
    );
  }
}
