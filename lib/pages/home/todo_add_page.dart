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

class _TodoAddPageState extends ConsumerState<TodoAddPage> {
  _TodoAddTab _activeTab = _TodoAddTab.create;
  VoidCallback? _submitAddAction;
  bool _canSubmit = false;

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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _AddModeTabs(
              activeTab: _activeTab,
              onChanged: (tab) => setState(() => _activeTab = tab),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _activeTab == _TodoAddTab.create ? 0 : 1,
              children: [
                TodoAddSheet(
                  isFullScreen: true,
                  showHeader: false,
                  stayAfterAdd: true,
                  autoFocusNameField: true,
                  showBottomSubmitBar: false,
                  onBindSubmitAction: (action) {
                    if (!mounted) return;
                    setState(() => _submitAddAction = action);
                  },
                  onSubmitEnabledChanged: (enabled) {
                    if (!mounted) return;
                    setState(() => _canSubmit = enabled);
                  },
                  initialCategoryName: widget.initialCategoryName,
                  initialCategoryId: widget.initialCategoryId,
                ),
                const HistoryAddView(),
              ],
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
    required this.activeTab,
    required this.onChanged,
  });

  final _TodoAddTab activeTab;
  final ValueChanged<_TodoAddTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget buildTab(_TodoAddTab tab, String label) {
      final selected = activeTab == tab;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected ? colors.surfaceHighOnInverse : Colors.transparent,
              border: selected
                  ? Border.all(color: colors.borderMedium)
                  : Border.all(color: Colors.transparent),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.surfaceTertiary,
      ),
      child: Row(
        children: [
          buildTab(_TodoAddTab.create, '新規作成'),
          buildTab(_TodoAddTab.history, '履歴から追加'),
        ],
      ),
    );
  }
}
