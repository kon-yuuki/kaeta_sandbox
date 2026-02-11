import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/snackbar_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../data/model/database.dart';
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
    final repository = ref.watch(todoRepositoryProvider);
    final familyId = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
    );
    final categoryAsync = ref.watch(categoryListProvider);
    final familyMembers = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: AppBar(
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleSpacing: 12,
        title: Row(
          children: [
            TextButton(
              onPressed: _toggleSelectAllCurrentFilter,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                _selectedItemIds.isEmpty ? 'すべて選択' : 'すべて解除',
                style: TextStyle(
                  color: colors.textHigh,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectedItemIds.isEmpty
                  ? null
                  : () => _showMoveCategorySheet(categoryAsync.valueOrNull ?? const []),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'カテゴリを移動',
                style: TextStyle(
                  color: _selectedItemIds.isEmpty
                      ? colors.textMedium
                      : colors.accentPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                '完了',
                style: TextStyle(
                  color: colors.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<PurchaseWithMaster>>(
        stream: repository.watchTopPurchaseHistory(familyId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data!;
          final categoryOptions = <String>{'すべて'};
          for (final entry in allItems) {
            categoryOptions.add(entry.masterItem.category);
          }

          final filtered = allItems.where((entry) {
            if (_selectedFilterCategory == 'すべて') return true;
            return entry.masterItem.category == _selectedFilterCategory;
          }).toList()
            ..sort((a, b) =>
                b.history.lastPurchasedAt.compareTo(a.history.lastPurchasedAt));

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
              const SizedBox(height: 14),
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
                                setState(() => _selectedFilterCategory = category);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                      avatar: avatarByUserId[entry.history.userId],
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

    repository.watchTopPurchaseHistory(familyId).first.then((allItems) {
      final filteredIds = allItems
          .where((entry) =>
              _selectedFilterCategory == 'すべて' ||
              entry.masterItem.category == _selectedFilterCategory)
          .map((e) => e.masterItem.id)
          .whereType<String>()
          .toSet();

      if (!mounted) return;
      setState(() {
        final alreadyAllSelected = filteredIds.isNotEmpty &&
            _selectedItemIds.intersection(filteredIds).length == filteredIds.length;
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.borderMedium,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        Expanded(
                          child: Text(
                            '移動先カテゴリを選択',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textHigh,
                              fontSize: 30 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    Divider(color: colors.borderLow, height: 1),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final checked = option == selected;
                          return InkWell(
                            onTap: () => setModalState(() => selected = option),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: index == 0
                                    ? null
                                    : Border(
                                        top: BorderSide(color: colors.borderLow),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    checked
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 24,
                                    color: checked
                                        ? colors.accentPrimary
                                        : colors.borderMedium,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    option.name,
                                    style: TextStyle(
                                      color: colors.textHigh,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        child: const Text('保存する'),
                        onPressed: () => Navigator.pop(context, selected),
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
    final allItems = await repository.watchTopPurchaseHistory(familyId).first;

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
      '$movedCount件のカテゴリを更新しました',
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
          final categoryId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
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
    return InkWell(
      onTap: onTapSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderLow)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.accentPrimary : colors.borderMedium,
                  width: 2,
                ),
                color: selected
                    ? colors.accentPrimary.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 16, color: colors.accentPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HistoryUserAvatar(avatar: avatar),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(entry.history.lastPurchasedAt),
                        style: TextStyle(
                          color: colors.textMedium,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.masterItem.name,
                    style: TextStyle(
                      color: colors.textHigh,
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildSubInfo(entry.masterItem),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textLow,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (entry.masterItem.imageUrl != null &&
                entry.masterItem.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  entry.masterItem.imageUrl!,
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.image_outlined, color: colors.textMedium, size: 24),
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
  const _PreviousCategory({
    required this.category,
    required this.categoryId,
  });

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
      return CircleAvatar(
        radius: 10,
        backgroundImage: NetworkImage(url),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 10,
        backgroundImage: AssetImage(preset),
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: colors.accentPrimaryLight,
      child: Icon(Icons.person, size: 12, color: colors.accentPrimaryDark),
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

  if (parts.isEmpty) return item.category;
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
