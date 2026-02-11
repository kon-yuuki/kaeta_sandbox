import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'history_category_bulk_edit_page.dart';
import '../home/widgets/history_add_view.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: AppBar(
        title: const Text('購入履歴'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const HistoryCategoryBulkEditPage(),
                ),
              );
            },
            child: Text(
              '編集',
              style: TextStyle(
                color: colors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: const HistoryAddView(),
    );
  }
}
