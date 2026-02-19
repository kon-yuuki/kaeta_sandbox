import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_button.dart';
import '../../invite/view/invite_start_screen.dart';
import '../../onboarding/onboarding_flow.dart';
import 'existing_account_login_screen.dart';

class InviteAuthStartPage extends StatefulWidget {
  const InviteAuthStartPage({super.key});

  @override
  State<InviteAuthStartPage> createState() => _InviteAuthStartPageState();
}

class _InviteAuthStartPageState extends State<InviteAuthStartPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  StreamSubscription<AuthState>? _authSub;
  bool _handledSignedIn = false;
  bool _suppressAuthAutoPop = false;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (!mounted) return;
      if (_suppressAuthAutoPop) return;
      if (_handledSignedIn) return;
      if (session == null) return;
      _handledSignedIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleSignedInNavigation();
      });
    });
  }

  Future<void> _handleSignedInNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingInviteId = prefs.getString('pending_invite_id');
    final hasPendingInvite = pendingInviteId != null && pendingInviteId.isNotEmpty;
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

    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error) {
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
      if (msg.contains('user already registered') ||
          msg.contains('user_already_exists')) {
        return 'このメールアドレスは既に登録されています';
      }
      if (msg.contains('weak_password') || msg.contains('password should be')) {
        return 'パスワードが短すぎます。6文字以上で入力してください';
      }
      if (msg.contains('rate') || msg.contains('too many requests')) {
        return 'リクエストが多すぎます。しばらくしてからお試しください';
      }
      if (msg.contains('network') || msg.contains('socket')) {
        return 'ネットワークに接続できません。通信環境をご確認ください';
      }
      return 'エラーが発生しました: ${error.message}';
    }
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection')) {
      return 'ネットワークに接続できません。通信環境をご確認ください';
    }
    return '予期せぬエラーが発生しました。しばらくしてからお試しください';
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => isLoading = true);

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
      if (idToken == null) {
        throw const AuthException('No ID Token found.');
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => isLoading = true);

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
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チームに参加してはじめる')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
          child: Image.asset(
            'assets/images/start/start_auth.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFDCE2EA))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '利用規約およびプライバシーポリシーに同意します',
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  variant: AppButtonVariant.filled,
                  onPressed: isLoading ? null : _handleAppleSignIn,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Appleのアカウントで続ける'),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                variant: AppButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => _showOtherSignInMethods(context),
                child: const Text(
                  'その他の方法ではじめる',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExistingAccountLoginPage(),
                          ),
                        );
                      },
                variant: AppButtonVariant.text,
                child: const Text(
                  'すでにアカウントをお持ちの方はこちら',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOtherSignInMethods(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF4B5E72)),
                    ),
                    const Expanded(
                      child: Text(
                        'その他の方法ではじめる',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF2C3844),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE6EBF2)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                            _handleGoogleSignIn();
                          },
                    icon: Image.asset(
                      'assets/icons/img_GoogleLogo.png',
                      width: 18,
                      height: 18,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFB7C2D2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'Googleでログイン',
                      style: TextStyle(
                        color: Color(0xFF2C3844),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'または',
                style: TextStyle(
                  color: Color(0xFF687A95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            Navigator.pop(context);
                            if (!mounted) return;
                            setState(() => _suppressAuthAutoPop = true);
                            await Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => OnboardingFlow(
                                  requireEmailCredentials: true,
                                  onComplete: () {
                                    if (!mounted) return;
                                    Navigator.of(this.context).popUntil(
                                      (route) => route.isFirst,
                                    );
                                  },
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() => _suppressAuthAutoPop = false);
                            }
                          },
                    icon: const Icon(
                      Icons.mail_outline,
                      size: 18,
                      color: Color(0xFF4B5E72),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFB7C2D2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'メールアドレスではじめる',
                      style: TextStyle(
                        color: Color(0xFF2C3844),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
