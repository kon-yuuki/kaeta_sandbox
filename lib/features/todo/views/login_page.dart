import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../todo/views/todo_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  // --- ここが「ネイティブ方式」の核心部分です ---
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
        SnackBar(content: Text('ログインに失敗しました: $e')),
      );
    }
  } finally {
    // 処理が終わったら（成功・失敗問わず）ローディングを解除
    if (mounted) {
      setState(() => isLoading = false);
    }
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
                onPressed: isLoading
                    ? null
                    : () async {
                        // ...（通常のログイン処理：省略なしで元のまま維持）...
                      },
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('ログイン'),
              ),
              const SizedBox(height: 15),

              // --- 修正した Google ボタン ---
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
            ],
          ),
        ),
      ),
    );
  }
}
