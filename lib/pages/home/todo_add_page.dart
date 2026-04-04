import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
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
  bool _showTopControls = true;
  double _lastScrollPixels = 0;
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final nextTab = _tabController.index == 0
          ? _TodoAddTab.create
          : _TodoAddTab.history;
      if (_activeTab != nextTab && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _activeTab = nextTab);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.depth != 0) return false;

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

    if (delta > 6 && _showTopControls) {
      setState(() => _showTopControls = false);
    } else if (delta < -6 && !_showTopControls) {
      setState(() => _showTopControls = true);
    }
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
      appBar: AppBar(
        title: const Text('アイテムを追加'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            offset: _showTopControls ? Offset.zero : const Offset(0, -0.25),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              opacity: _showTopControls ? 1 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: _showTopControls ? 62 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: _AddModeTabs(
                    controller: _tabController,
                    activeTab: _activeTab,
                    onChanged: (tab) {
                      final index = tab == _TodoAddTab.create ? 0 : 1;
                      if (_tabController.index != index) {
                        _tabController.animateTo(index);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
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
                    autoFocusNameField: true,
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
                  HistoryAddView(showSearchBar: _showTopControls),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _activeTab == _TodoAddTab.create && !isKeyboardVisible
          ? Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              color: colors.backgroundGray,
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _canSubmit ? _submitAddAction : null,
                  child: const Text('リストに追加する'),
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
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.surfaceTertiary,
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
                  width: (constraints.maxWidth - 4) / 2,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors.surfaceHighOnInverse,
                    border: Border.all(color: colors.borderMedium),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
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
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textHigh,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textMedium,
                ),
                tabs: const [
                  Tab(height: 40, text: '新規作成'),
                  Tab(height: 40, text: '履歴から追加'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
