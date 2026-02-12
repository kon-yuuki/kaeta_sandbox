import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/profiles_provider.dart';
import '../providers/onboarding_provider.dart';

class ProfileSetupStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool requireEmailCredentials;

  const ProfileSetupStep({
    super.key,
    required this.onNext,
    this.requireEmailCredentials = false,
  });

  @override
  ConsumerState<ProfileSetupStep> createState() => _ProfileSetupStepState();
}

class _ProfileSetupStepState extends ConsumerState<ProfileSetupStep> {
  static const int _maxLength = 15;

  final _scrollController = ScrollController();
  final _nameFieldKey = GlobalKey();
  final _teamFieldKey = GlobalKey();
  final _emailFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();

  late TextEditingController _nameController;
  late TextEditingController _teamController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _nameFocusNode;
  late FocusNode _teamFocusNode;
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _teamController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameFocusNode = FocusNode();
    _teamFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();

    _nameFocusNode.addListener(() => _onFocusChanged(_nameFocusNode, _nameFieldKey));
    _teamFocusNode.addListener(() => _onFocusChanged(_teamFocusNode, _teamFieldKey));
    _emailFocusNode.addListener(() => _onFocusChanged(_emailFocusNode, _emailFieldKey));
    _passwordFocusNode.addListener(
      () => _onFocusChanged(_passwordFocusNode, _passwordFieldKey),
    );

    // OAuthから名前を取得して自動入力
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final oauthName = ref.read(profileRepositoryProvider).getOAuthDisplayName();
      if (oauthName != null && _nameController.text.isEmpty) {
        // 15文字を超える場合は切り詰める
        final truncatedName = oauthName.length > _maxLength
            ? oauthName.substring(0, _maxLength)
            : oauthName;
        _nameController.text = truncatedName;
        ref.read(onboardingDataProvider.notifier).setDisplayName(truncatedName);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _teamController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _teamFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged(FocusNode node, GlobalKey key) {
    if (!node.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (targetContext == null || !mounted) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.18,
      );
    });
  }

  bool _isValid() {
    final nameTrimmed = _nameController.text.trim();
    final teamTrimmed = _teamController.text.trim();
    final baseValid = nameTrimmed.isNotEmpty &&
        nameTrimmed.length <= _maxLength &&
        teamTrimmed.isNotEmpty &&
        teamTrimmed.length <= _maxLength;
    if (!widget.requireEmailCredentials) return baseValid;

    final emailTrimmed = _emailController.text.trim();
    final password = _passwordController.text;
    return baseValid &&
        emailTrimmed.isNotEmpty &&
        emailTrimmed.contains('@') &&
        password.isNotEmpty &&
        password.length >= 6;
  }

  String? _getLimitWarning(int currentLength) {
    if (currentLength >= _maxLength) {
      return '入力文字数は$_maxLength文字以内にしてください';
    }
    return null;
  }

  Future<void> _submitEmailSignUpIfNeeded() async {
    if (!widget.requireEmailCredentials) return;

    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'full_name': name,
        },
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final alreadyRegistered =
          msg.contains('user already registered') ||
          msg.contains('user already registerd') ||
          msg.contains('user_already_exists') ||
          msg.contains('already registerd') ||
          msg.contains('already exists');
      if (!alreadyRegistered) rethrow;

      // 途中離脱で「登録済み」になっているケースはログインして再開する
      try {
        await supabase.auth.signInWithPassword(email: email, password: password);
      } on AuthException {
        throw const AuthException(
          'このメールアドレスは既に登録されています。登録時のパスワードでログインしてください。',
        );
      }
    }

    // signup 後に profile を確実に作成
    await ref.read(profileRepositoryProvider).ensureProfile(displayName: name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final nameWarning = _getLimitWarning(_nameController.text.length);
    final teamWarning = _getLimitWarning(_teamController.text.length);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 8, 16, keyboardInset + 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - keyboardInset - 24,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(title: '名前'),
                  const SizedBox(height: 6),
                  Container(
                    key: _nameFieldKey,
                    child: AppTextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      maxLength: _maxLength,
                      hintText: 'みさき',
                      errorText: nameWarning,
                      suffixIcon: _nameController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _nameController.clear();
                                ref.read(onboardingDataProvider.notifier).setDisplayName('');
                                setState(() {});
                              },
                              icon: Icon(
                                Icons.cancel,
                                size: 18,
                                color: colors.surfaceLow,
                              ),
                            )
                          : null,
                      onChanged: (value) {
                        ref.read(onboardingDataProvider.notifier).setDisplayName(value);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(title: 'チーム名'),
                  const SizedBox(height: 6),
                  Container(
                    key: _teamFieldKey,
                    child: AppTextField(
                      controller: _teamController,
                      focusNode: _teamFocusNode,
                      maxLength: _maxLength,
                      hintText: '○○チーム、○○家など',
                      errorText: teamWarning,
                      onChanged: (value) {
                        ref.read(onboardingDataProvider.notifier).setTeamName(value);
                        setState(() {});
                      },
                    ),
                  ),
                  if (widget.requireEmailCredentials) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(title: 'メールアドレス'),
                    const SizedBox(height: 6),
                    Container(
                      key: _emailFieldKey,
                      child: AppTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'example@domain.com',
                        onChanged: (_) => setState(() {}),
                        errorText: _emailController.text.isEmpty ||
                                _emailController.text.contains('@')
                            ? null
                            : 'メールアドレスの形式を確認してください',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(title: 'パスワード'),
                    const SizedBox(height: 6),
                    Container(
                      key: _passwordFieldKey,
                      child: AppTextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: true,
                        hintText: '6文字以上',
                        onChanged: (_) => setState(() {}),
                        errorText: _passwordController.text.isEmpty ||
                                _passwordController.text.length >= 6
                            ? null
                            : 'パスワードは6文字以上で入力してください',
                      ),
                    ),
                  ],
                  if (keyboardInset == 0) const Spacer() else const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: _isValid() && !_isSubmitting
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              FocusScope.of(context).unfocus();
                              try {
                                setState(() => _isSubmitting = true);
                                ref
                                    .read(onboardingDataProvider.notifier)
                                    .setDisplayName(_nameController.text.trim());
                                ref
                                    .read(onboardingDataProvider.notifier)
                                    .setTeamName(_teamController.text.trim());
                                await _submitEmailSignUpIfNeeded();
                                if (!mounted) return;
                                widget.onNext();
                              } on AuthException catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('登録に失敗しました: $e')),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                              }
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('アイコン設定へ進む', style: TextStyle(fontSize: 16)),
                      ),
                    ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textLow,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEBEF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '必須',
            style: TextStyle(
              color: colors.textAlert,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
