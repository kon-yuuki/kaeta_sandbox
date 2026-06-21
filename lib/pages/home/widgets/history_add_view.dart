import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/billing_provider.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/todo_repository.dart';
import '../../setting/view/premium_plan_sheet.dart';
import '../providers/home_provider.dart';

enum HistorySortOrder { latestFirst, oldestFirst }

class HistoryAddView extends ConsumerStatefulWidget {
  const HistoryAddView({
    super.key,
    this.showSearchBar = true,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
    this.onScrollMetricsChanged,
  });

  final bool showSearchBar;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<ScrollMetrics>? onScrollMetricsChanged;

  @override
  ConsumerState<HistoryAddView> createState() => _HistoryAddViewState();
}

class _HistoryAddViewState extends ConsumerState<HistoryAddView> {
  late final TextEditingController _fallbackSearchController;
  late final FocusNode _fallbackSearchFocusNode;
  final Map<String, TodoItem> _addedTodoByItemId = <String, TodoItem>{};
  String _selectedCategory = 'すべて';
  HistorySortOrder _sortOrder = HistorySortOrder.latestFirst;

  TextEditingController get _searchController =>
      widget.searchController ?? _fallbackSearchController;
  FocusNode get _searchFocusNode =>
      widget.searchFocusNode ?? _fallbackSearchFocusNode;

  @override
  void initState() {
    super.initState();
    _fallbackSearchController = TextEditingController();
    _fallbackSearchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _fallbackSearchController.dispose();
    _fallbackSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final repository = ref.watch(todoRepositoryProvider);
    final familyMembers =
        ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final familyId = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
    );
    final billingState = ref.watch(billingControllerProvider);
    final historyRetentionDays = billingState.purchaseHistoryRetentionDays;
    final historyWindowLabel = billingState.purchaseHistoryWindowLabel;

    return StreamBuilder<List<PurchaseWithMaster>>(
      stream: repository.watchTopPurchaseHistory(
        familyId,
        retentionDays: historyRetentionDays,
      ),
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
            final categoryMatch =
                _selectedCategory == 'すべて' ||
                entry.masterItem.category == _selectedCategory;
            final suggestionMatch =
                suggestedNames == null ||
                suggestedNames.contains(entry.masterItem.name);
            return categoryMatch && suggestionMatch;
          }).toList();
        }

        int wordMatchPriority(String name, String keyword) {
          final normalizedName = name.trim().toLowerCase();
          final normalizedKeyword = keyword.trim().toLowerCase();
          if (normalizedKeyword.isEmpty) return 3;
          if (normalizedName == normalizedKeyword) return 0;
          if (normalizedName.startsWith(normalizedKeyword)) return 1;
          if (normalizedName.contains(normalizedKeyword)) return 2;
          return 3;
        }

        Widget buildHistoryList(
          List<PurchaseWithMaster> filtered, {
          required bool hasQuery,
        }) {
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

          if (hasQuery && filtered.isEmpty) {
            return _HistoryNoResultPremiumState(
              colors: colors,
              historyWindowLabel: historyWindowLabel,
              onPremiumTap: () {
                openPremiumPlanPage(context);
              },
            );
          }

          final topFrequency = [...filtered]
            ..sort(
              (a, b) => b.masterItem.purchaseCount.compareTo(
                a.masterItem.purchaseCount,
              ),
            );
          final topFrequencyLimited = topFrequency.take(9).toList();
          final topFrequencyPages = <List<PurchaseWithMaster>>[];
          for (var i = 0; i < topFrequencyLimited.length; i += 3) {
            final end = (i + 3 < topFrequencyLimited.length)
                ? i + 3
                : topFrequencyLimited.length;
            topFrequencyPages.add(topFrequencyLimited.sublist(i, end));
          }
          final topFrequencyRows = topFrequencyPages.isEmpty
              ? 0
              : topFrequencyPages.first.length;
          final topFrequencyHeight = topFrequencyRows <= 0
              ? 0.0
              : (topFrequencyRows * 84.0) + ((topFrequencyRows - 1) * 6.0);
          final recentItems = [...filtered]
            ..sort((a, b) {
              if (hasQuery) {
                final aPriority = wordMatchPriority(a.masterItem.name, query);
                final bPriority = wordMatchPriority(b.masterItem.name, query);
                if (aPriority != bPriority) {
                  return aPriority.compareTo(bPriority);
                }
                return b.history.lastPurchasedAt.compareTo(
                  a.history.lastPurchasedAt,
                );
              }
              if (_sortOrder == HistorySortOrder.latestFirst) {
                return b.history.lastPurchasedAt.compareTo(
                  a.history.lastPurchasedAt,
                );
              }
              return a.history.lastPurchasedAt.compareTo(
                b.history.lastPurchasedAt,
              );
            });

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
              if (notification is! ScrollUpdateNotification) return false;
              widget.onScrollMetricsChanged?.call(notification.metrics);
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                if (!hasQuery && billingState.hasPremium) ...[
                  _SectionTitle(
                    leading: SvgPicture.asset(
                      'assets/icons/trending-up.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        colors.bluePrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    title: '購入頻度が高い',
                    color: colors.textLow,
                  ),
                  const SizedBox(height: 10),
                  if (topFrequency.isEmpty)
                    _EmptyHint(text: '履歴がありません')
                  else
                    SizedBox(
                      height: topFrequencyHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: topFrequencyPages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, pageIndex) {
                          final pageItems = topFrequencyPages[pageIndex];
                          return SizedBox(
                            width: MediaQuery.sizeOf(context).width - 98,
                            child: Column(
                              children: pageItems.asMap().entries.map((entry) {
                                final isLast =
                                    entry.key == pageItems.length - 1;
                                final item = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isLast ? 0 : 6,
                                  ),
                                  child: _TopHistoryCard(
                                    entry: item,
                                    isAdded: _addedTodoByItemId.containsKey(
                                      item.masterItem.id,
                                    ),
                                    onAdd: () =>
                                        _handleAddFromHistory(context, item),
                                    onUndo: () =>
                                        _handleUndoFromHistory(context, item),
                                    colors: colors,
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
                if (!hasQuery) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '購入履歴 ($historyWindowLabel)',
                          style: AppTypography.of(
                            context,
                          ).std16B150.copyWith(color: colors.textHigh),
                        ),
                      ),
                      Builder(
                        builder: (buttonContext) => InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final selected =
                                await showAppDropdownMenu<HistorySortOrder>(
                                  triggerContext: buttonContext,
                                  options: const [
                                    AppDropdownOption(
                                      value: HistorySortOrder.latestFirst,
                                      label: '最新の購入日順',
                                    ),
                                    AppDropdownOption(
                                      value: HistorySortOrder.oldestFirst,
                                      label: '古い購入日順',
                                    ),
                                  ],
                                  value: _sortOrder,
                                  menuWidth: 214,
                                  menuElevation: 16,
                                  menuShadowColor: Colors.black.withValues(
                                    alpha: 0.42,
                                  ),
                                  menuDividerColor: const Color(0x80808080),
                                  menuDividerWidth: 0.5,
                                  textStyle: AppTypography.of(buttonContext)
                                      .egOnl16M160
                                      .copyWith(color: colors.textHigh),
                                  menuTextStyle: AppTypography.of(buttonContext)
                                      .egOnl16M160
                                      .copyWith(color: colors.textHigh),
                                );
                            if (selected != null) {
                              setState(() => _sortOrder = selected);
                            }
                          },
                          child: SvgPicture.asset(
                            'assets/icons/sort.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              colors.surfaceMedium,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categoryOptions
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChoicePill(
                                label: category,
                                selected: _selectedCategory == category,
                                size: AppSelectionSize.sm,
                                horizontalPadding: 16,
                                onTap: () {
                                  setState(() => _selectedCategory = category);
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (recentItems.isEmpty)
                  _EmptyHint(text: '条件に合う履歴がありません')
                else
                  ...recentItems.asMap().entries.map(
                    (mapEntry) => _HistoryRow(
                      entry: mapEntry.value,
                      avatar: mapEntry.value.history.userId == null
                          ? null
                          : avatarByUserId[mapEntry.value.history.userId!],
                      isAdded: _addedTodoByItemId.containsKey(
                        mapEntry.value.masterItem.id,
                      ),
                      showBottomBorder: mapEntry.key != recentItems.length - 1,
                      onAdd: () =>
                          _handleAddFromHistory(context, mapEntry.value),
                      onUndo: () =>
                          _handleUndoFromHistory(context, mapEntry.value),
                      colors: colors,
                    ),
                  ),
              ],
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: widget.showSearchBar
                    ? Offset.zero
                    : const Offset(0, -0.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  opacity: widget.showSearchBar ? 1 : 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: widget.showSearchBar ? 95 : 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 13, 24, 28),
                      child: HistorySearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          widget.onSearchChanged?.call(value);
                          setState(() {});
                        },
                        colors: colors,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: query.isEmpty
                    ? buildHistoryList(filterItems(), hasQuery: false)
                    : FutureBuilder<List<dynamic>>(
                        future: ref
                            .read(homeViewModelProvider)
                            .getSuggestions(query),
                        builder: (context, suggestionSnapshot) {
                          if (suggestionSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final suggestedNames =
                              suggestionSnapshot.data
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
          ),
        );
      },
    );
  }

  Future<void> _handleAddFromHistory(
    BuildContext context,
    PurchaseWithMaster entry,
  ) async {
    final currentFamilyId = ref.read(selectedFamilyIdProvider);
    final addedTodo = await ref
        .read(homeViewModelProvider)
        .addFromHistory(entry.masterItem);
    if (!context.mounted) return;
    if (addedTodo != null) {
      setState(() {
        _addedTodoByItemId[entry.masterItem.id] = addedTodo;
      });
    }
    showTopSnackBar(
      context,
      '${entry.masterItem.name}が追加されました',
      actionLabel: addedTodo != null ? '元に戻す' : null,
      onAction: addedTodo != null
          ? (snackBarContext) async {
              await ref.read(homeViewModelProvider).deleteTodo(addedTodo);
              if (mounted) {
                setState(() {
                  _addedTodoByItemId.remove(entry.masterItem.id);
                });
              }
              if (!snackBarContext.mounted) return;
              showTopSnackBar(
                snackBarContext,
                '「${entry.masterItem.name}」を元に戻しました',
                familyId: currentFamilyId,
              );
            }
          : null,
      familyId: currentFamilyId,
      saveToHistory: currentFamilyId == null || currentFamilyId.isEmpty,
    );
  }

  Future<void> _handleUndoFromHistory(
    BuildContext context,
    PurchaseWithMaster entry,
  ) async {
    final addedTodo = _addedTodoByItemId[entry.masterItem.id];
    if (addedTodo == null) return;
    final currentFamilyId = ref.read(selectedFamilyIdProvider);
    await ref.read(homeViewModelProvider).deleteTodo(addedTodo);
    if (!mounted) return;
    setState(() {
      _addedTodoByItemId.remove(entry.masterItem.id);
    });
    showTopSnackBar(
      context,
      '${entry.masterItem.name}をリストから削除しました',
      familyId: currentFamilyId,
      saveToHistory: false,
      showCloseButton: true,
    );
  }
}

class HistorySearchField extends StatelessWidget {
  const HistorySearchField({
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
    final typography = AppTypography.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceTertiary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/search.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(
                    colors.surfaceLow,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('history-search-text-field'),
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    cursorWidth: 2,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      hintText: 'アイテム名からさがす...',
                      hintStyle: TextStyle(
                        color: colors.textMedium,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: typography.std16R160.copyWith(
                      color: colors.textHigh,
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
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.surfaceLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: colors.surfaceHighOnInverse,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasText) ...[
          const SizedBox(width: 16),
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              controller.clear();
              onChanged('');
            },
            child: Text(
              'キャンセル',
              style: typography.std14R160.copyWith(color: colors.textHigh),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    this.icon,
    this.leading,
    required this.title,
    required this.color,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Row(
      children: [
        leading ?? Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title, style: typography.std12B160.copyWith(color: color)),
      ],
    );
  }
}

class _HistoryNoResultPremiumState extends StatelessWidget {
  const _HistoryNoResultPremiumState({
    required this.colors,
    required this.historyWindowLabel,
    required this.onPremiumTap,
  });

  final AppColors colors;
  final String historyWindowLabel;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        const SizedBox(height: 34),
        Center(
          child: Text(
            '検索結果はありません',
            style: typography.jaOnl14Sb100.copyWith(
              height: 1.3,
              color: colors.textHigh,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '現在のプランでは$historyWindowLabelの履歴が記録されます',
            style: typography.std11M160.copyWith(color: colors.textMedium),
          ),
        ),
        const SizedBox(height: 60),
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
          'オーナー1人の登録でみんなで使えます',
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
  const _SortMenuLabel({required this.label, required this.selected});

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
    required this.isAdded,
    required this.onAdd,
    required this.onUndo,
    required this.colors,
  });

  final PurchaseWithMaster entry;
  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onUndo;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    final quantityLabel = _buildQuantityInfo(entry.masterItem);
    final budgetLabel = _buildBudgetInfo(entry.masterItem);
    final hasMeta =
        (quantityLabel != null && quantityLabel.isNotEmpty) ||
        (budgetLabel != null && budgetLabel.isNotEmpty);
    final hasImage =
        entry.masterItem.imageUrl != null &&
        entry.masterItem.imageUrl!.isNotEmpty;
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        color: colors.surfaceHighOnInverse,
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      entry.masterItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.jaOnl14Sb100.copyWith(
                        height: 1.3,
                        color: colors.textHigh,
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
                          if (budgetLabel != null &&
                              budgetLabel.isNotEmpty) ...[
                            if (quantityLabel != null &&
                                quantityLabel.isNotEmpty)
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
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      entry.masterItem.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 48),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _HistoryActionButton(
              isAdded: isAdded,
              onAdd: onAdd,
              onUndo: onUndo,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.avatar,
    required this.isAdded,
    required this.showBottomBorder,
    required this.onAdd,
    required this.onUndo,
    required this.colors,
  });

  final PurchaseWithMaster entry;
  final _HistoryAvatarData? avatar;
  final bool isAdded;
  final bool showBottomBorder;
  final VoidCallback onAdd;
  final VoidCallback onUndo;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    final quantityLabel = _buildQuantityInfo(entry.masterItem);
    final budgetLabel = _buildBudgetInfo(entry.masterItem);
    final hasMeta =
        (quantityLabel != null && quantityLabel.isNotEmpty) ||
        (budgetLabel != null && budgetLabel.isNotEmpty);
    final hasImage =
        entry.masterItem.imageUrl != null &&
        entry.masterItem.imageUrl!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
      decoration: BoxDecoration(
        border: showBottomBorder
            ? Border(bottom: BorderSide(color: colors.borderDivider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                entry.masterItem.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(width: 20),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HistoryActionButton(
              isAdded: isAdded,
              onAdd: onAdd,
              onUndo: onUndo,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAvatarData {
  const _HistoryAvatarData({this.avatarUrl, this.avatarPreset});

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
      child: Icon(Icons.person, size: 10, color: colors.accentPrimaryDark),
    );
  }
}

class _HistoryActionButton extends StatelessWidget {
  const _HistoryActionButton({
    required this.isAdded,
    required this.onAdd,
    required this.onUndo,
  });

  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: isAdded ? onUndo : onAdd,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isAdded ? Colors.transparent : colors.surfaceHigh,
          borderRadius: BorderRadius.circular(99),
          border: isAdded
              ? Border.all(color: colors.borderMedium, width: 2)
              : null,
        ),
        child: Center(
          child: isAdded
              ? Container(
                  width: 10,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: colors.surfaceMedium,
                    borderRadius: BorderRadius.circular(999),
                  ),
                )
              : Icon(Icons.add, size: 18, color: colors.surfaceHighOnInverse),
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
    const upperNoneThreshold = 2050;
    final minAmount = item.budgetMinAmount ?? 0;
    final maxAmount = item.budgetMaxAmount!;
    if (maxAmount >= upperNoneThreshold) {
      if (minAmount > 0) {
        parts.add('¥${minAmount}以上');
      }
    } else if (minAmount <= 0) {
      parts.add('¥${maxAmount}以下');
    } else if (minAmount >= maxAmount) {
      parts.add('¥${minAmount}以上');
    } else {
      parts.add('¥${minAmount}〜${maxAmount}');
    }
  }

  if (parts.isEmpty) {
    return item.category;
  }
  return parts.join('  ');
}

String? _buildQuantityInfo(Item item) {
  if (item.quantityText == null || item.quantityText!.isEmpty) return null;
  final unit = _quantityUnitLabel(item.quantityUnit);
  return '${item.quantityText}$unit';
}

String? _buildBudgetInfo(Item item) {
  if (item.budgetMaxAmount == null || item.budgetMaxAmount! <= 0) return null;
  const upperNoneThreshold = 2050;
  final minAmount = item.budgetMinAmount ?? 0;
  final maxAmount = item.budgetMaxAmount!;
  final unit = item.budgetType == 1 ? '100g' : '1つ';
  if (maxAmount >= upperNoneThreshold) {
    return minAmount <= 0 ? null : '$minAmount円以上／$unit';
  }
  if (minAmount <= 0) return '$maxAmount円以下／$unit';
  if (minAmount >= maxAmount) return '$minAmount円以上／$unit';
  return '$minAmount〜$maxAmount円／$unit';
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
