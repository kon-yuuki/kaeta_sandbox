import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/common_app_bar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'history_category_bulk_edit_page.dart';
import '../home/widgets/history_add_view.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: CommonAppBar(
        showBackButton: true,
        showLogoutButton: false,
        showFamilyToggle: false,
        title: '購入履歴',
        extraActions: [
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
              style: typography.jaOnl14Sb100.copyWith(
                height: 1.3,
                color: colors.textHigh,
              ),
            ),
          ),
        ],
      ),
      body: const HistoryAddView(),
    );
  }
}
