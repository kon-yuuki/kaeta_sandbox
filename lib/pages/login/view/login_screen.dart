import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final mailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  StreamSubscription<AuthState>? _authSub;
  bool _handledSignedIn = false;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (!mounted) return;
      if (_handledSignedIn) return;
      if (session == null) return;
      _handledSignedIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    mailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// エラーオブジェクトをユーザー向けの日本語メッセージに変換
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
      if (msg.contains('weak_password') ||
          msg.contains('password should be')) {
        return 'パスワードが短すぎます。6文字以上で入力してください';
      }
      if (msg.contains('rate') || msg.contains('too many requests')) {
        return 'リクエストが多すぎます。しばらくしてからお試しください';
      }
      if (msg.contains('network') || msg.contains('socket')) {
        return 'ネットワークに接続できません。通信環境をご確認ください';
      }
      // 未知のAuthExceptionはメッセージだけ表示（コード部分を除外）
      return 'エラーが発生しました: ${error.message}';
    }
    // ネットワーク系の一般エラー
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection')) {
      return 'ネットワークに接続できません。通信環境をご確認ください';
    }
    return '予期せぬエラーが発生しました。しばらくしてからお試しください';
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: mailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // 成功時、RiverpodのisLoggedInProviderなどが反応して自動で画面が切り替わります
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

  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      await supabase.auth.signUp(
        email: mailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('確認メールを送信しました（設定による）または登録完了しました')),
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

  Future<void> _handleGoogleSignIn() async {
    try {
      // 画面のローディング状態を開始
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

      // 1. ログイン実行（ユーザーがキャンセルすると例外を投げる）
      final googleUser = await googleSignIn.authenticate();

      // 2. 認可情報の取得
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('No ID Token found.');
      }

      // 3. Supabaseにサインイン
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on GoogleSignInException catch (e) {
      // 【重要】キャンセル時のエラーハンドリング
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('ユーザーがログインをキャンセルしました。');
        return; // エラー画面を出さずに終了
      }
      // キャンセル以外（ネットワークエラー等）は例外を再送出
      rethrow;
    } catch (e) {
      // 4. その他のエラー表示
      debugPrint('Googleログイン中に予期せぬエラーが発生しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } finally {
      // 処理が終わったら（成功・失敗問わず）ローディングを解除
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => isLoading = true);

      // 1. Appleのサインインダイアログを表示
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

      // 2. SupabaseにIDトークンでサインイン
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: credential.authorizationCode,
      );
      // 成功時、auth状態の変更で自動的に画面が切り替わります
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('ユーザーがAppleログインをキャンセルしました。');
        return;
      }
      debugPrint('Appleログインエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } catch (e) {
      debugPrint('Appleログインエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => isLoading = true);
    try {
      await supabase.auth.signInAnonymously();
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
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チームを作成してはじめる')),
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
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'メールアドレス',
                  controller: mailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                    return null;
                  },
                ),
                AppTextField(
                  label: 'パスワード',
                  controller: passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'パスワードを入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: isLoading ? null : _handleEmailSignIn,
                    child: const Text('メールでログイン'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    variant: AppButtonVariant.outlined,
                    onPressed: isLoading ? null : _handleEmailSignUp,
                    child: const Text('新規登録する'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.login),
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    child: const Text('Googleでログイン'),
                  ),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: isLoading ? null : _handleGuestSignIn,
                  child: const Text('ゲストで始める'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
