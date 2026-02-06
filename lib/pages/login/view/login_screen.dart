import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  @override
  void dispose() {
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
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ...（メールアドレス・パスワードの入力フォームは変更なし）...
              TextFormField(
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                controller: mailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'パスワード'),
                controller: passwordController,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'パスワードを入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: isLoading ? null : _handleEmailSignIn,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('ログイン'),
              ),
              const SizedBox(height: 5),

              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Googleでログイン'),
                onPressed: isLoading ? null : _handleGoogleSignIn, // 新しい関数を呼び出す
              ),
              const SizedBox(height: 10),
              const Divider(), // 区切り線
              TextButton(
                onPressed: isLoading ? null : _handleEmailSignUp,
                child: const Text('新規でアカウントを作成する'),
              ),

              OutlinedButton.icon(
                icon: const Icon(Icons.apple),
                label: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Appleでログイン'),
                onPressed: isLoading ? null : _handleAppleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
