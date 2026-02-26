import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/app_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
      debugPrint(
        '[LoginPage] onAuthStateChange event=${event.event} session=${session != null ? 'present' : 'null'} user=${supabase.auth.currentUser?.id}',
      );
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
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// エラーオブジェクトをユーザー向けの日本語メッセージに変換
  String _friendlyErrorMessage(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      final details = (error.message ?? '').trim();
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
      debugPrint('Appleログインエラー: code=${e.code.name}, message=${e.message}');
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
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool emailLoading = false;
    String? emailErrorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(0, 6, 0, bottomInset + 16),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
              StatefulBuilder(
                builder: (context, setModalState) {
                  Future<void> createAccountWithEmail() async {
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    debugPrint(
                      '[LoginPage] createAccountWithEmail tapped email=$email passwordLen=${password.length}',
                    );
                    if (email.isEmpty || password.isEmpty) {
                      debugPrint('[LoginPage] createAccountWithEmail blocked: empty field');
                      setModalState(() {
                        emailErrorMessage = 'メールアドレスとパスワードを入力してください';
                      });
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('メールアドレスとパスワードを入力してください')),
                      );
                      return;
                    }
                    setModalState(() {
                      emailLoading = true;
                      emailErrorMessage = null;
                    });
                    debugPrint('[LoginPage] signUp start');
                    try {
                      final result = await supabase.auth.signUp(
                        email: email,
                        password: password,
                      );
                      debugPrint(
                        '[LoginPage] signUp done session=${result.session != null ? 'present' : 'null'} user=${result.user?.id}',
                      );
                      if (!mounted) return;
                      if (result.session == null) {
                        // 設定値や環境差で signUp 後に session が返らないケースがあるため
                        // その場でサインインを試みてオンボ導線へ進める。
                        debugPrint('[LoginPage] signUp session null -> signInWithPassword start');
                        await supabase.auth.signInWithPassword(
                          email: email,
                          password: password,
                        );
                        debugPrint('[LoginPage] signInWithPassword done');
                      }
                      if (!mounted) return;
                      if (Navigator.of(context).canPop()) {
                        debugPrint('[LoginPage] close modal after email account flow');
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      debugPrint('[LoginPage] createAccountWithEmail error: $e');
                      if (e is AuthException) {
                        final msg = e.message.toLowerCase();
                        final isAlreadyExists =
                            msg.contains('user_already_exists') ||
                            msg.contains('user already registered');
                        if (isAlreadyExists) {
                          debugPrint(
                            '[LoginPage] user already exists -> fallback signInWithPassword start',
                          );
                          try {
                            await supabase.auth.signInWithPassword(
                              email: email,
                              password: password,
                            );
                            debugPrint(
                              '[LoginPage] fallback signInWithPassword done',
                            );
                            if (!mounted) return;
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            return;
                          } catch (signInError) {
                            debugPrint(
                              '[LoginPage] fallback signInWithPassword error: $signInError',
                            );
                            if (mounted) {
                              setModalState(() {
                                emailErrorMessage =
                                    'このメールアドレスは既にアカウントがあります。'
                                    'パスワードが正しいか確認してください。';
                              });
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'このメールアドレスは既にアカウントがあります。パスワードが正しいか確認してください。',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                      }
                      if (!mounted) return;
                      setModalState(() {
                        emailErrorMessage = _friendlyErrorMessage(e);
                      });
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text(_friendlyErrorMessage(e))),
                      );
                    } finally {
                      debugPrint('[LoginPage] createAccountWithEmail finally');
                      if (mounted) setModalState(() => emailLoading = false);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'パスワード',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => createAccountWithEmail(),
                        ),
                        if (emailErrorMessage != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              emailErrorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFD93838),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isLoading || emailLoading
                                ? null
                                : createAccountWithEmail,
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
                            label: emailLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'メールアドレスで新規作成',
                                    style: TextStyle(
                                      color: Color(0xFF2C3844),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
