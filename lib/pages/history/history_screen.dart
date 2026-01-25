import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './widgets/todo_history_list.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物履歴'),
        // 必要に応じて、履歴のクリアボタンなどをここに追加できます
      ),
      // 履歴が長くなってもスクロールできるように SingleChildScrollView で包みます
      body: const SingleChildScrollView(
        child: Column(
          children: [
            TodoHistoryList(),
            // ページ下部に余白を持たせるための調整
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}