import 'package:flutter/material.dart';
import '../../../data/model/database.dart';
import '../widgets/todo_edit_sheet.dart';

class TodoEditPage extends StatelessWidget {
  const TodoEditPage({
    super.key,
    required this.item,
    this.imageUrl,
  });

  final TodoItem item;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アイテムを編集'),
      ),
      body: TodoEditSheet(
        item: item,
        imageUrl: imageUrl,
      ),
    );
  }
}
