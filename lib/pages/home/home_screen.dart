import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart';
import 'providers/home_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../main.dart';
import '../login/view/login_screen.dart';
import "widgets/todo_add_sheet.dart";
import 'widgets/todo_list_view.dart';
import 'widgets/home_bottom_nav_bar.dart';
import '../history/history_screen.dart';
import "./view_models/home_view_model.dart";

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  int selectedPriorityForNew = 0;

  Future<void> initializeData() async {
    await ref.read(homeViewModelProvider).initializeData();
  }

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => ref.read(profileRepositoryProvider).ensureProfile());
    final myProfile = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('${myProfile?.displayName ?? 'ゲスト'}のメモ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1. Supabaseからサインアウト
              await Supabase.instance.client.auth.signOut();

              await db.disconnectAndClear();

              // 2. ログイン画面へ戻す（今の画面を捨てて LoginPage へ）
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Text(
                        '履歴を見る',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),

            const TodoItemList(),

            SizedBox(height: 20),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) {
              return const TodoAddSheet();
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const HomeBottomNavBar(),
    );
  }
}
