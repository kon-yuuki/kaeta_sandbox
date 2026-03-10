import 'package:flutter/material.dart';
import '../../../data/model/database.dart';
import '../widgets/todo_add_sheet.dart';
import '../../../core/theme/app_colors.dart';

class TodoEditPage extends StatelessWidget {
  const TodoEditPage({super.key, required this.item, this.imageUrl});

  final TodoItem item;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surfaceHighOnInverse,
      appBar: AppBar(title: const Text('アイテムを編集')),
      body: TodoAddSheet(
        isFullScreen: true,
        showHeader: false,
        editItem: item,
        editImageUrl: imageUrl,
      ),
    );
  }
}
