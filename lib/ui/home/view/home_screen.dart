import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/home_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../main.dart';
import '../../../data/model/database.dart';
import '../../login/view/login_screen.dart';
import "../widgets/todo_add_sheet.dart";
import "../widgets/todo_history_list.dart";
import '../widgets/todo_list_view.dart';
import '../widgets/home_bottom_nav_bar.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  int selectedPriorityForNew = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => ref.read(profileRepositoryProvider).ensureProfile());
    final sortOrder = ref.watch(todoSortOrderProvider);
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
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                leading: const Icon(Icons.search),
                hintText: 'タスクを検索...',
                elevation: WidgetStateProperty.all(0.5),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  ref.read(todoSearchQueryProvider.notifier).state = value;
                },
              ),
            ),

            const TodoItemList(),

            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('履歴', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            const TodoHistoryList(),

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
      bottomNavigationBar: const HomeBottomNavBar()
    );
  }
}
