import 'package:flutter/material.dart';
import '../widgets/category_edit_sheet.dart';

class CategoryEditPage extends StatelessWidget {
  const CategoryEditPage({
    super.key,
    this.initialCategoryName,
    this.initialCategoryId,
  });

  final String? initialCategoryName;
  final String? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カテゴリを編集'),
      ),
      body: CategoryEditSheet(
        showHeader: false,
        fullHeight: true,
        initialCategoryName: initialCategoryName,
        initialCategoryId: initialCategoryId,
      ),
    );
  }
}
