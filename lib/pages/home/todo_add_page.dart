import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/common_app_bar.dart';
import 'widgets/history_add_view.dart';
import 'widgets/todo_add_sheet.dart';

enum _TodoAddTab { create, history }

class TodoAddPage extends ConsumerStatefulWidget {
  const TodoAddPage({
    super.key,
    this.initialCategoryName,
    this.initialCategoryId,
  });

  final String? initialCategoryName;
  final String? initialCategoryId;

  @override
  ConsumerState<TodoAddPage> createState() => _TodoAddPageState();
}

class _TodoAddPageState extends ConsumerState<TodoAddPage>
    with SingleTickerProviderStateMixin {
  _TodoAddTab _activeTab = _TodoAddTab.create;
  VoidCallback? _submitAddAction;
  bool _canSubmit = false;
  double _topControlsHiddenOffset = 0;
  double _lastScrollPixels = 0;
  late final TextEditingController _historySearchController;
  late final FocusNode _historySearchFocusNode;
  late final TabController _tabController;

  void _scheduleParentStateUpdate(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(update);
    });
  }

  @override
  void initState() {
    super.initState();
    _historySearchController = TextEditingController();
    _historySearchFocusNode = FocusNode();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final nextTab = _tabController.index == 0
          ? _TodoAddTab.create
          : _TodoAddTab.history;
      if (_activeTab != nextTab && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _activeTab = nextTab;
            _topControlsHiddenOffset = _topControlsHiddenOffset.clamp(
              0.0,
              _topControlsHeight,
            );
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    _historySearchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  double get _topControlsHeight =>
      _activeTab == _TodoAddTab.history ? 64 + 79 : 64;

  void _handleHistoryScrollMetrics(ScrollMetrics metrics) {
    final hasScrollableRange =
        metrics.maxScrollExtent > metrics.minScrollExtent;
    final isOutOfRange = metrics.outOfRange;
    if (!hasScrollableRange || isOutOfRange) {
      _lastScrollPixels = metrics.pixels.clamp(
        metrics.minScrollExtent,
        metrics.maxScrollExtent,
      );
      return;
    }

    final pixels = metrics.pixels;
    final delta = pixels - _lastScrollPixels;
    _lastScrollPixels = pixels;
    final nextHiddenOffset = pixels <= 0
        ? 0.0
        : (_topControlsHiddenOffset + delta).clamp(0.0, _topControlsHeight);
    if ((nextHiddenOffset - _topControlsHiddenOffset).abs() < 0.5) return;
    if (!mounted) return;
    setState(() {
      _topControlsHiddenOffset = nextHiddenOffset;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.depth != 0) return false;
    if (_activeTab == _TodoAddTab.history) return false;

    final metrics = notification.metrics;
    final hasScrollableRange =
        metrics.maxScrollExtent > metrics.minScrollExtent;
    final isOutOfRange = metrics.outOfRange;
    if (!hasScrollableRange || isOutOfRange) {
      _lastScrollPixels = metrics.pixels.clamp(
        metrics.minScrollExtent,
        metrics.maxScrollExtent,
      );
      return false;
    }

    final pixels = metrics.pixels;
    final delta = pixels - _lastScrollPixels;
    _lastScrollPixels = pixels;
    final nextHiddenOffset = pixels <= 0
        ? 0.0
        : (_topControlsHiddenOffset + delta).clamp(0.0, _topControlsHeight);
    if ((nextHiddenOffset - _topControlsHiddenOffset).abs() < 0.5) {
      return false;
    }
    setState(() {
      _topControlsHiddenOffset = nextHiddenOffset;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: CommonAppBar(
        showBackButton: true,
        title: 'アイテムを追加',
        showLogoutButton: false,
        onBackPressed: () async {
          await Navigator.maybePop(context);
          return false;
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: 1 + _topControlsHeight - _topControlsHiddenOffset,
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    TodoAddSheet(
                      isFullScreen: true,
                      showHeader: false,
                      stayAfterAdd: true,
                      autoFocusNameField: false,
                      showBottomSubmitBar: false,
                      onBindSubmitAction: (action) {
                        if (!mounted) return;
                        if (identical(_submitAddAction, action)) return;
                        _scheduleParentStateUpdate(() {
                          _submitAddAction = action;
                        });
                      },
                      onSubmitEnabledChanged: (enabled) {
                        if (!mounted) return;
                        if (_canSubmit == enabled) return;
                        _scheduleParentStateUpdate(() {
                          _canSubmit = enabled;
                        });
                      },
                      initialCategoryName: widget.initialCategoryName,
                      initialCategoryId: widget.initialCategoryId,
                    ),
                    HistoryAddView(
                      showSearchBar: false,
                      searchController: _historySearchController,
                      searchFocusNode: _historySearchFocusNode,
                      onSearchChanged: (_) {
                        if (!mounted) return;
                        setState(() {});
                      },
                      onScrollMetricsChanged: _handleHistoryScrollMetrics,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: Offset(0, -_topControlsHiddenOffset),
              child: ColoredBox(
                color: colors.surfaceHighOnInverse,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: colors.borderLow,
                    ),
                    SizedBox(
                      height: 64,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _AddModeTabs(
                          controller: _tabController,
                          activeTab: _activeTab,
                          onChanged: (tab) {
                            if (_activeTab != tab) {
                              setState(() {
                                _activeTab = tab;
                                _topControlsHiddenOffset =
                                    _topControlsHiddenOffset.clamp(
                                      0.0,
                                      tab == _TodoAddTab.history ? 64 + 79 : 64,
                                    );
                              });
                            }
                            final index = tab == _TodoAddTab.create ? 0 : 1;
                            if (_tabController.index != index) {
                              _tabController.animateTo(index);
                            }
                          },
                        ),
                      ),
                    ),
                    if (_activeTab == _TodoAddTab.history)
                      SizedBox(
                        height: 79,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 13, 24, 18),
                          child: HistorySearchField(
                            controller: _historySearchController,
                            focusNode: _historySearchFocusNode,
                            onChanged: (_) {
                              if (!mounted) return;
                              setState(() {});
                            },
                            colors: colors,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _activeTab == _TodoAddTab.create && !isKeyboardVisible
          ? Container(
              padding: EdgeInsets.fromLTRB(
                12,
                16,
                12,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceHighOnInverse,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, -2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: SizedBox(
                  height: 60,
                  child: AppButton(
                    onPressed: _canSubmit ? _submitAddAction : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('リストに追加する'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _AddModeTabs extends StatelessWidget {
  const _AddModeTabs({
    required this.controller,
    required this.activeTab,
    required this.onChanged,
  });

  final TabController controller;
  final _TodoAddTab activeTab;
  final ValueChanged<_TodoAddTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surfaceSecondary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: activeTab == _TodoAddTab.create
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: (constraints.maxWidth - 10) / 2,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colors.surfaceHighOnInverse,
                  ),
                ),
              ),
              TabBar(
                controller: controller,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                labelPadding: EdgeInsets.zero,
                onTap: (index) {
                  onChanged(
                    index == 0 ? _TodoAddTab.create : _TodoAddTab.history,
                  );
                },
                tabs: [
                  _TabLabel(
                    text: '新規作成',
                    color: activeTab == _TodoAddTab.create
                        ? colors.textHigh
                        : colors.textMedium,
                  ),
                  _TabLabel(
                    text: '履歴から追加',
                    color: activeTab == _TodoAddTab.history
                        ? colors.textHigh
                        : colors.textMedium,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Tab(
      height: 30,
      child: SizedBox.expand(
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: typography.jaOnl12B100.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
