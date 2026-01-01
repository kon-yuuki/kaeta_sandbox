import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../todo/views/todo_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final mailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    mailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ログイン')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                controller: mailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return '正しいメールアドレスの形式で入力してください';
                  }
                  return null; // 問題なければnullを返す
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'パスワード'),
                controller: passwordController,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null; // 問題なければnullを返す
                },
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        try {
                          setState(() {
                            isLoading = true;
                          });
                          await Supabase.instance.client.auth
                              .signInWithPassword(
                                password: passwordController.text,
                                email: mailController.text,
                              );

                          print('ログイン成功');

                          setState(() {
                            isLoading = false;
                          });

                          if (mounted && _formKey.currentState!.validate()) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const TodoPage(),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          print('エラーが発生しました:$e');
                        } finally {
                          if (mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                        ;
                      },
          child: isLoading
                    ? CircularProgressIndicator()
                    : const Text('ログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
