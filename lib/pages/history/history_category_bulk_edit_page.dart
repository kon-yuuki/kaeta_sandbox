import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/snackbar_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet_header.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_selection.dart';
import '../../data/model/database.dart';
import '../../data/providers/billing_provider.dart';
import '../../data/providers/category_provider.dart';
import '../../data/providers/families_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/repositories/todo_repository.dart';
import '../home/providers/home_provider.dart';

class HistoryCategoryBulkEditPage extends ConsumerStatefulWidget {
  const HistoryCategoryBulkEditPage({super.key});

  @override
  ConsumerState<HistoryCategoryBulkEditPage> createState() =>
      _HistoryCategoryBulkEditPageState();
}

class _HistoryCategoryBulkEditPageState
    extends ConsumerState<HistoryCategoryBulkEditPage> {
  String _selectedFilterCategory = 'すべて';
  final Set<String> _selectedItemIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final repository = ref.watch(todoRepositoryProvider);
    final familyId = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
    );
    final categoryAsync = ref.watch(categoryListProvider);
    final familyMembers =
        ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final retentionDays = ref.watch(
      billingControllerProvider.select(
        (state) => state.purchaseHistoryRetentionDays,
      ),
    );

    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: AppBar(
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleSpacing: 16,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _toggleSelectAllCurrentFilter,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _selectedItemIds.isEmpty ? 'すべて選択' : 'すべて解除',
                style: typography.std14R160.copyWith(color: colors.textHigh),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectedItemIds.isEmpty
                  ? null
                  : () => _showMoveCategorySheet(
                      categoryAsync.valueOrNull ?? const [],
                    ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'カテゴリを移動',
                style: typography.jaOnl14Sb100.copyWith(
                  height: 1.3,
                  color: _selectedItemIds.isEmpty
                      ? colors.textDisabled
                      : colors.accentPrimaryDark,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'キャンセル',
                style: typography.jaOnl14Sb100.copyWith(
                  height: 1.3,
                  color: colors.textHigh,
                ),
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<PurchaseWithMaster>>(
        stream: repository.watchTopPurchaseHistory(
          familyId,
          retentionDays: retentionDays,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data!;
          final categoryOptions = <String>{'すべて'};
          for (final entry in allItems) {
            categoryOptions.add(entry.masterItem.category);
          }

          final filtered =
              allItems.where((entry) {
                if (_selectedFilterCategory == 'すべて') return true;
                return entry.masterItem.category == _selectedFilterCategory;
              }).toList()..sort(
                (a, b) => b.history.lastPurchasedAt.compareTo(
                  a.history.lastPurchasedAt,
                ),
              );

          final avatarByUserId = <String, _HistoryAvatarData>{};
          for (final member in familyMembers) {
            avatarByUserId[member.userId] = _HistoryAvatarData(
              avatarUrl: member.avatarUrl,
              avatarPreset: member.avatarPreset,
            );
          }
          if (myProfile != null) {
            avatarByUserId[myProfile.id] = _HistoryAvatarData(
              avatarUrl: myProfile.avatarUrl,
              avatarPreset: myProfile.avatarPreset,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categoryOptions
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppChoiceChipX(
                              label: category,
                              selected: _selectedFilterCategory == category,
                              onTap: () {
                                setState(
                                  () => _selectedFilterCategory = category,
                                );
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final itemId = entry.masterItem.id;
                    final selected = _selectedItemIds.contains(itemId);
                    return _SelectableHistoryRow(
                      entry: entry,
                      selected: selected,
                      avatar: entry.history.userId == null
                          ? null
                          : avatarByUserId[entry.history.userId!],
                      onTapSelect: () {
                        setState(() {
                          if (selected) {
                            _selectedItemIds.remove(itemId);
                          } else {
                            _selectedItemIds.add(itemId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSelectAllCurrentFilter() {
    final repository = ref.read(todoRepositoryProvider);
    final familyId = ref.read(myProfileProvider).valueOrNull?.currentFamilyId;
    final retentionDays = ref.read(
      billingControllerProvider.select(
        (state) => state.purchaseHistoryRetentionDays,
      ),
    );

    repository
        .watchTopPurchaseHistory(familyId, retentionDays: retentionDays)
        .first
        .then((allItems) {
          final filteredIds = allItems
              .where(
                (entry) =>
                    _selectedFilterCategory == 'すべて' ||
                    entry.masterItem.category == _selectedFilterCategory,
              )
              .map((e) => e.masterItem.id)
              .whereType<String>()
              .toSet();

          if (!mounted) return;
          setState(() {
            final alreadyAllSelected =
                filteredIds.isNotEmpty &&
                _selectedItemIds.intersection(filteredIds).length ==
                    filteredIds.length;
            if (alreadyAllSelected) {
              _selectedItemIds.removeAll(filteredIds);
            } else {
              _selectedItemIds.addAll(filteredIds);
            }
          });
        });
  }

  Future<void> _showMoveCategorySheet(List<Category> categories) async {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final options = <_TargetCategory>[
      const _TargetCategory(name: '指定なし', id: null),
      ...categories.map((c) => _TargetCategory(name: c.name, id: c.id)),
    ];

    _TargetCategory selected = options.first;

    final target = await showModalBottomSheet<_TargetCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              bottom: false,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceHighOnInverse,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBottomSheetHeader(
                      title: '移動先カテゴリを選択',
                      onBack: () => Navigator.pop(context),
                      trailing: AppBottomSheetSaveButton(
                        enabled: true,
                        onPressed: () => Navigator.pop(context, selected),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: colors.backgroundGray,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceHighOnInverse,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: options.asMap().entries.map((entry) {
                              final index = entry.key;
                              final option = entry.value;
                              final checked = option == selected;
                              return InkWell(
                                onTap: () =>
                                    setModalState(() => selected = option),
                                child: Container(
                                  height: 62,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: index == 0
                                        ? null
                                        : Border(
                                            top: BorderSide(
                                              color: colors.borderLow,
                                            ),
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      AppRadioCircle(selected: checked),
                                      const SizedBox(width: 12),
                                      Text(
                                        option.name,
                                        style: typography.std14R160.copyWith(
                                          color: colors.textHigh,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (target == null || _selectedItemIds.isEmpty) return;

    final repository = ref.read(todoRepositoryProvider);
    final familyId = ref.read(myProfileProvider).valueOrNull?.currentFamilyId;
    final retentionDays = ref.read(
      billingControllerProvider.select(
        (state) => state.purchaseHistoryRetentionDays,
      ),
    );
    final allItems = await repository
        .watchTopPurchaseHistory(familyId, retentionDays: retentionDays)
        .first;

    final beforeByItemId = <String, _PreviousCategory>{};
    for (final entry in allItems) {
      final id = entry.masterItem.id;
      if (_selectedItemIds.contains(id)) {
        beforeByItemId[id] = _PreviousCategory(
          category: entry.masterItem.category,
          categoryId: entry.masterItem.categoryId,
        );
      }
    }

    await repository.bulkUpdateItemCategories(
      itemIds: _selectedItemIds.toList(),
      category: target.name,
      categoryId: target.id,
    );

    if (!mounted) return;
    final movedCount = _selectedItemIds.length;
    setState(() {
      _selectedItemIds.clear();
      _selectedFilterCategory = 'すべて';
    });

    showTopSnackBar(
      context,
      'アイテムのカテゴリを編集しました',
      actionLabel: '元に戻す',
      onAction: (snackBarContext) async {
        final grouped = <String, List<String>>{};
        for (final e in beforeByItemId.entries) {
          final key = '${e.value.category}||${e.value.categoryId ?? ''}';
          grouped.putIfAbsent(key, () => <String>[]).add(e.key);
        }

        for (final g in grouped.entries) {
          final parts = g.key.split('||');
          final category = parts[0];
          final categoryId = parts.length > 1 && parts[1].isNotEmpty
              ? parts[1]
              : null;
          await repository.bulkUpdateItemCategories(
            itemIds: g.value,
            category: category,
            categoryId: categoryId,
          );
        }

        if (!snackBarContext.mounted) return;
        showTopSnackBar(
          snackBarContext,
          'カテゴリ変更を元に戻しました',
          familyId: ref.read(selectedFamilyIdProvider),
        );
      },
      familyId: ref.read(selectedFamilyIdProvider),
    );
  }
}

class _SelectableHistoryRow extends StatelessWidget {
  const _SelectableHistoryRow({
    required this.entry,
    required this.selected,
    required this.avatar,
    required this.onTapSelect,
  });

  final PurchaseWithMaster entry;
  final bool selected;
  final _HistoryAvatarData? avatar;
  final VoidCallback onTapSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final quantityLabel = _buildQuantityInfo(entry.masterItem);
    final budgetLabel = _buildBudgetInfo(entry.masterItem);
    final hasMeta =
        (quantityLabel != null && quantityLabel.isNotEmpty) ||
        (budgetLabel != null && budgetLabel.isNotEmpty);
    final hasImage =
        entry.masterItem.imageUrl != null &&
        entry.masterItem.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: onTapSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderDivider)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.blueDark : colors.borderMedium,
                  width: 2,
                ),
                color: selected ? colors.blueDark : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: SvgPicture.asset(
                        'assets/icons/check.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HistoryUserAvatar(avatar: avatar),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(entry.history.lastPurchasedAt),
                        style: typography.jaOnl12M120.copyWith(
                          color: colors.textLow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      entry.masterItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.jaOnl14Sb100.copyWith(
                        height: 1.3,
                        color: colors.textHigh,
                      ),
                    ),
                  ),
                  if (hasMeta) ...[
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (quantityLabel != null && quantityLabel.isNotEmpty)
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/bag.svg',
                                width: 16,
                                height: 16,
                                colorFilter: ColorFilter.mode(
                                  colors.surfaceLow,
                                  BlendMode.srcIn,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  quantityLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.jaOnl12M120.copyWith(
                                    color: colors.textLow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (budgetLabel != null && budgetLabel.isNotEmpty) ...[
                          if (quantityLabel != null && quantityLabel.isNotEmpty)
                            const SizedBox(height: 2),
                          Text(
                            budgetLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.jaOnl12M120.copyWith(
                              color: colors.textLow,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.masterItem.imageUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetCategory {
  const _TargetCategory({required this.name, required this.id});
  final String name;
  final String? id;
}

class _PreviousCategory {
  const _PreviousCategory({required this.category, required this.categoryId});

  final String category;
  final String? categoryId;
}

class _HistoryAvatarData {
  const _HistoryAvatarData({
    required this.avatarUrl,
    required this.avatarPreset,
  });

  final String? avatarUrl;
  final String? avatarPreset;
}

class _HistoryUserAvatar extends StatelessWidget {
  const _HistoryUserAvatar({required this.avatar});

  final _HistoryAvatarData? avatar;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = avatar?.avatarUrl;
    final preset = avatar?.avatarPreset;
    final hasUrl = url != null && url.isNotEmpty;
    final hasPreset = preset != null && preset.isNotEmpty;

    if (hasUrl) {
      return CircleAvatar(radius: 10, backgroundImage: NetworkImage(url));
    }
    if (hasPreset) {
      return CircleAvatar(radius: 10, backgroundImage: AssetImage(preset));
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: colors.accentPrimaryLight,
      child: Icon(Icons.person, size: 12, color: colors.accentPrimaryDark),
    );
  }
}

String? _buildQuantityInfo(Item item) {
  if (item.quantityText != null && item.quantityText!.isNotEmpty) {
    final unit = _quantityUnitLabel(item.quantityUnit);
    final count = item.quantityCount != null && item.quantityCount! > 1
        ? '×${item.quantityCount}'
        : '';
    return '${item.quantityText}$unit$count';
  }
  return null;
}

String? _buildBudgetInfo(Item item) {
  if (item.budgetMaxAmount != null && item.budgetMaxAmount! > 0) {
    const upperNoneThreshold = 2050;
    final minAmount = item.budgetMinAmount ?? 0;
    final maxAmount = item.budgetMaxAmount!;
    if (maxAmount >= upperNoneThreshold) {
      if (minAmount > 0) {
        return '¥${minAmount}以上';
      }
    } else if (minAmount <= 0) {
      return '¥${maxAmount}以下';
    } else if (minAmount >= maxAmount) {
      return '¥${minAmount}以上';
    } else {
      return '¥${minAmount}〜${maxAmount}';
    }
  }
  return null;
}

String _quantityUnitLabel(int? unit) {
  switch (unit) {
    case 0:
      return 'g';
    case 1:
      return 'mg';
    case 2:
      return 'ml';
    case 3:
      return 'kg';
    case 4:
      return 'L';
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
