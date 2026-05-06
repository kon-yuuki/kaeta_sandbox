import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/app_button.dart';
import '../../invite/view/invite_join_screen.dart';
import '../../login/view/existing_account_login_screen.dart';
import '../../login/view/login_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  static const _heroAssetPath = 'assets/images/start/start_hero.png';
  bool _isGuestLoading = false;

  Future<void> _startAsGuest() async {
    setState(() => _isGuestLoading = true);
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ゲストログインに失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGuestLoading = false);
      }
    }
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _goToInviteJoin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InviteJoinPage()));
  }

  void _goToExistingAccountLogin() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const ExistingAccountLoginPage(asModal: true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Image.asset(
                      _heroAssetPath,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  onPressed: _goToLogin,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(60),
                                    fixedSize: const Size.fromHeight(60),
                                    backgroundColor: const Color(0xFF2F3A4B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.6,
                                    ),
                                  ),
                                  child: const Text('チームを作成'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  onPressed: _goToInviteJoin,
                                  variant: AppButtonVariant.outlined,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(60),
                                    fixedSize: const Size.fromHeight(60),
                                    side: const BorderSide(
                                      color: Color(0xFFD2D9E5),
                                    ),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.6,
                                    ),
                                  ),
                                  child: const Text('チームに参加'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(color: Color(0xFFDCE3EE)),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'または',
                                  style: TextStyle(
                                    color: Color(0xFF8B97A8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Color(0xFFDCE3EE)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AppButton(
                            onPressed: _isGuestLoading ? null : _startAsGuest,
                            variant: AppButtonVariant.text,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF52657D),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            child: _isGuestLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('ゲストとしてすぐにはじめる'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'すでにアカウントをお持ちの方',
                        style: TextStyle(
                          color: Color(0xFF202938),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                    ),
                    AppButton(
                      onPressed: _goToExistingAccountLogin,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 46),
                        backgroundColor: const Color(0xFF2F3A4B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('ログイン'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
