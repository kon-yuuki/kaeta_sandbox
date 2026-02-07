import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/todo_add_sheet.dart';

class TodoAddPage extends ConsumerWidget {
  const TodoAddPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アイテムを追加'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const TodoAddSheet(
        isFullScreen: true,
        showHeader: false,
      ),
    );
  }
}
