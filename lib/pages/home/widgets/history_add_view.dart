import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/todo_repository.dart';
import '../providers/home_provider.dart';

enum HistorySortOrder { latestFirst, oldestFirst }

class HistoryAddView extends ConsumerStatefulWidget {
  const HistoryAddView({super.key});

  @override
  ConsumerState<HistoryAddView> createState() => _HistoryAddViewState();
}

class _HistoryAddViewState extends ConsumerState<HistoryAddView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedCategory = 'すべて';
  HistorySortOrder _sortOrder = HistorySortOrder.latestFirst;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final repository = ref.watch(todoRepositoryProvider);
    final familyId = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
    );

    return StreamBuilder<List<PurchaseWithMaster>>(
      stream: repository.watchTopPurchaseHistory(familyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allItems = snapshot.data!;
        final query = _searchController.text.trim();

        final categoryOptions = <String>{'すべて'};
        for (final entry in allItems) {
          categoryOptions.add(entry.masterItem.category);
        }

        List<PurchaseWithMaster> filterItems({Set<String>? suggestedNames}) {
          return allItems.where((entry) {
            final categoryMatch = _selectedCategory == 'すべて' ||
                entry.masterItem.category == _selectedCategory;
            final suggestionMatch = suggestedNames == null ||
                suggestedNames.contains(entry.masterItem.name);
            return categoryMatch && suggestionMatch;
          }).toList();
        }

        Widget buildHistoryList(
          List<PurchaseWithMaster> filtered, {
          required bool hasQuery,
        }) {
          if (hasQuery && filtered.isEmpty) {
            return _HistoryNoResultPremiumState(
              colors: colors,
              onPremiumTap: () {
                showTopSnackBar(
                  context,
                  'プレミアムプラン詳細は準備中です',
                  familyId: ref.read(selectedFamilyIdProvider),
                );
              },
            );
          }

          final topFrequency = [...filtered]
            ..sort((a, b) =>
                b.masterItem.purchaseCount.compareTo(a.masterItem.purchaseCount));
          final topFrequencyPages = <List<PurchaseWithMaster>>[];
          for (var i = 0; i < topFrequency.length; i += 3) {
            final end = (i + 3 < topFrequency.length) ? i + 3 : topFrequency.length;
            topFrequencyPages.add(topFrequency.sublist(i, end));
          }
          final recentItems = [...filtered]
            ..sort((a, b) {
              if (_sortOrder == HistorySortOrder.latestFirst) {
                return b.history.lastPurchasedAt.compareTo(a.history.lastPurchasedAt);
              }
              return a.history.lastPurchasedAt.compareTo(b.history.lastPurchasedAt);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _SectionTitle(
                icon: Icons.trending_up,
                title: '購入頻度が高い',
                color: colors.textLow,
              ),
              const SizedBox(height: 10),
              if (topFrequency.isEmpty)
                _EmptyHint(text: '履歴がありません')
              else
                SizedBox(
                  height: 276,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: topFrequencyPages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, pageIndex) {
                      final pageItems = topFrequencyPages[pageIndex];
                      return SizedBox(
                        width: MediaQuery.sizeOf(context).width * 0.82,
                        child: Column(
                          children: pageItems
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TopHistoryCard(
                                    entry: entry,
                                    onAdd: () =>
                                        _handleAddFromHistory(context, entry),
                                    colors: colors,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '購入履歴 (最新1週間)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textHigh,
                      ),
                    ),
                  ),
                  PopupMenuButton<HistorySortOrder>(
                    initialValue: _sortOrder,
                    tooltip: '並び替え',
                    onSelected: (value) => setState(() => _sortOrder = value),
                    itemBuilder: (context) => [
                      PopupMenuItem<HistorySortOrder>(
                        value: HistorySortOrder.latestFirst,
                        child: _SortMenuLabel(
                          label: '最新の購入日順',
                          selected: _sortOrder == HistorySortOrder.latestFirst,
                        ),
                      ),
                      PopupMenuItem<HistorySortOrder>(
                        value: HistorySortOrder.oldestFirst,
                        child: _SortMenuLabel(
                          label: '古い購入日順',
                          selected: _sortOrder == HistorySortOrder.oldestFirst,
                        ),
                      ),
                    ],
                    child: Icon(Icons.sort, size: 20, color: colors.textMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categoryOptions
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChoiceChipX(
                            label: category,
                            selected: _selectedCategory == category,
                            onTap: () {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (query.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.history,
                  title: '検索候補に一致した履歴',
                  color: colors.textLow,
                ),
                const SizedBox(height: 10),
              ],
              if (recentItems.isEmpty)
                _EmptyHint(text: '条件に合う履歴がありません')
              else
                ...recentItems.map(
                  (entry) => _HistoryRow(
                    entry: entry,
                    onAdd: () => _handleAddFromHistory(context, entry),
                    colors: colors,
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: _HistorySearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (_) => setState(() {}),
                colors: colors,
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? buildHistoryList(filterItems(), hasQuery: false)
                  : FutureBuilder<List<dynamic>>(
                      future: ref.read(homeViewModelProvider).getSuggestions(query),
                      builder: (context, suggestionSnapshot) {
                        if (suggestionSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final suggestedNames = suggestionSnapshot.data
                                ?.map((s) => (s as dynamic).name as String)
                                .toSet() ??
                            <String>{};
                        return buildHistoryList(
                          filterItems(suggestedNames: suggestedNames),
                          hasQuery: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAddFromHistory(
    BuildContext context,
    PurchaseWithMaster entry,
  ) async {
    final addedTodo =
        await ref.read(homeViewModelProvider).addFromHistory(entry.masterItem);
    if (!context.mounted) return;
    showTopSnackBar(
      context,
      '「${entry.masterItem.name}」をリストに追加しました',
      actionLabel: addedTodo != null ? '元に戻す' : null,
      onAction: addedTodo != null
          ? (snackBarContext) async {
              await ref.read(homeViewModelProvider).deleteTodo(addedTodo);
              if (!snackBarContext.mounted) return;
              showTopSnackBar(
                snackBarContext,
                '「${entry.masterItem.name}」を元に戻しました',
                familyId: ref.read(selectedFamilyIdProvider),
              );
            }
          : null,
      familyId: ref.read(selectedFamilyIdProvider),
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.colors,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceTertiary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: colors.textMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('history-search-text-field'),
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: 'アイテム名からさがす...',
                      hintStyle: TextStyle(color: colors.textMedium, fontSize: 16),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: colors.textHigh,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasText)
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: colors.textMedium,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: colors.surfaceHighOnInverse,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasText) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              controller.clear();
              onChanged('');
            },
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: colors.textHigh,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HistoryNoResultPremiumState extends StatelessWidget {
  const _HistoryNoResultPremiumState({
    required this.colors,
    required this.onPremiumTap,
  });

  final AppColors colors;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const SizedBox(height: 56),
        Center(
          child: Text(
            '検索結果はありません',
            style: TextStyle(
              color: colors.textHigh,
              fontSize: 34 / 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '無料プランは最新1週間の履歴が記録されます',
            style: TextStyle(
              color: colors.textLow,
              fontSize: 24 / 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 36),
        GestureDetector(
          onTap: onPremiumTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/Tab_ItemCreate/add_item_premiere_banner.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '月額500円 / オーナー1人の登録でみんなで使える',
          style: TextStyle(
            color: colors.textLow,
            fontSize: 24 / 2,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SortMenuLabel extends StatelessWidget {
  const _SortMenuLabel({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? Icon(Icons.check, size: 18, color: colors.textHigh)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: colors.textHigh,
          ),
        ),
      ],
    );
  }
}

class _TopHistoryCard extends StatelessWidget {
  const _TopHistoryCard({
    required this.entry,
    required this.onAdd,
    required this.colors,
  });

  final PurchaseWithMaster entry;
  final VoidCallback onAdd;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderLow),
        color: colors.surfaceHighOnInverse,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.masterItem.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textHigh,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildSubInfo(entry.masterItem),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textLow,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.masterItem.imageUrl != null &&
              entry.masterItem.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                entry.masterItem.imageUrl!,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            )
          else
            Icon(Icons.image_outlined, size: 24, color: colors.textMedium),
          const SizedBox(width: 10),
          _AddCircleButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.onAdd,
    required this.colors,
  });

  final PurchaseWithMaster entry;
  final VoidCallback onAdd;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderLow)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: colors.accentPrimaryLight,
            child: Icon(Icons.person, size: 12, color: colors.accentPrimaryDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(entry.history.lastPurchasedAt),
                  style: TextStyle(
                    color: colors.textMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.masterItem.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textHigh,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _buildSubInfo(entry.masterItem),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textLow, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AddCircleButton(onTap: onAdd),
          ),
        ],
      ),
    );
  }
}

class _AddCircleButton extends StatelessWidget {
  const _AddCircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.surfaceHigh,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(Icons.add, size: 18, color: colors.surfaceHighOnInverse),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _buildSubInfo(Item item) {
  final parts = <String>[];

  if (item.quantityText != null && item.quantityText!.isNotEmpty) {
    final unit = _quantityUnitLabel(item.quantityUnit);
    final count = item.quantityCount != null && item.quantityCount! > 1
        ? '×${item.quantityCount}'
        : '';
    parts.add('${item.quantityText}$unit$count');
  }

  if (item.budgetMaxAmount != null && item.budgetMaxAmount! > 0) {
    parts.add('¥${item.budgetMaxAmount}以下');
  }

  if (parts.isEmpty) {
    return item.category;
  }
  return parts.join('  ');
}

String _quantityUnitLabel(int? unit) {
  switch (unit) {
    case 0:
      return 'g';
    case 1:
      return 'mg';
    case 2:
      return 'ml';
    default:
      return '';
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}
