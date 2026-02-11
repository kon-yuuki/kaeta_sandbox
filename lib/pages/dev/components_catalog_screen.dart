import 'package:flutter/material.dart';
import '../../core/common_app_bar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_heading.dart';
import '../../core/widgets/app_list_item.dart';
import '../../core/widgets/app_selection.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/app_step_bar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_button.dart';

class ComponentsCatalogScreen extends StatefulWidget {
  const ComponentsCatalogScreen({super.key});

  @override
  State<ComponentsCatalogScreen> createState() => _ComponentsCatalogScreenState();
}

class _ComponentsCatalogScreenState extends State<ComponentsCatalogScreen> {
  final _textController = TextEditingController(text: 'テキスト');
  bool _pillSelected = true;
  bool _radioSelected = true;
  bool _checkShopping = true;
  bool _checkEdit = true;
  int _dropdownValue = 0;
  int _segmentValue = 1;
  bool _choiceSelected = false;
  bool _conditionSelected = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _colorChip(String label, Color color) {
    final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: const CommonAppBar(showBackButton: true, title: 'コンポーネント一覧'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AppButton',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _sectionTitle('Filled'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                AppButton(onPressed: null, child: Text('無効')),
                AppButton(onPressed: _noop, child: Text('通常')),
                AppButton(
                  size: AppButtonSize.sm,
                  onPressed: _noop,
                  child: Text('sm'),
                ),
                AppButton(
                  onPressed: _noop,
                  icon: Icon(Icons.add),
                  child: Text('アイコンあり'),
                ),
                AppButton(
                  tone: AppButtonTone.danger,
                  onPressed: _noop,
                  child: Text('Danger'),
                ),
              ],
            ),
            _sectionTitle('Outlined'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                AppButton(
                  variant: AppButtonVariant.outlined,
                  onPressed: null,
                  child: Text('無効'),
                ),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  onPressed: _noop,
                  child: Text('通常'),
                ),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.sm,
                  onPressed: _noop,
                  child: Text('sm'),
                ),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  isSelected: true,
                  onPressed: _noop,
                  child: Text('選択状態'),
                ),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  tone: AppButtonTone.danger,
                  onPressed: _noop,
                  child: Text('Danger'),
                ),
                AppButton(
                  variant: AppButtonVariant.outlined,
                  onPressed: _noop,
                  icon: Icon(Icons.person_add_alt_1),
                  child: Text('アイコンあり'),
                ),
              ],
            ),
            _sectionTitle('Text'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: null,
                  child: Text('無効'),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: _noop,
                  child: Text('通常'),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.sm,
                  onPressed: _noop,
                  child: Text('sm'),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  tone: AppButtonTone.danger,
                  onPressed: _noop,
                  child: Text('Danger'),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: _noop,
                  icon: Icon(Icons.edit),
                  child: Text('アイコンあり'),
                ),
              ],
            ),
            _sectionTitle('Color Tokens'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _colorChip('border/medium', colors.borderMedium),
                _colorChip('text/high', colors.textHigh),
                _colorChip('surface/medium', colors.surfaceMedium),
              ],
            ),
            _sectionTitle('AppHeading'),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeading('Primary Heading', type: AppHeadingType.primary),
                SizedBox(height: 6),
                AppHeading('Secondary Heading', type: AppHeadingType.secondary),
                SizedBox(height: 6),
                AppHeading('Tertiary Heading', type: AppHeadingType.tertiary),
              ],
            ),
            _sectionTitle('AppTextField'),
            const SizedBox(height: 8),
            AppTextField(
              hintText: '入力してください',
              helperText: 'ヘルプテキスト',
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: '項目ラベル',
              hintText: 'エラー表示サンプル',
              errorText: 'エラーテキスト',
              suffixIcon: Icon(Icons.error_outline, size: 18),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _textController,
              heightType: AppTextFieldHeight.h56SingleLineEdit,
              prefixIcon: const Icon(Icons.edit, size: 18),
            ),
            _sectionTitle('Selection'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppChoicePill(
                  label: 'ラベル',
                  selected: _pillSelected,
                  onTap: () => setState(() => _pillSelected = !_pillSelected),
                ),
                AppChoicePill(
                  label: 'sm',
                  size: AppSelectionSize.sm,
                  selected: !_pillSelected,
                  onTap: () => setState(() => _pillSelected = !_pillSelected),
                ),
                AppRadioCircle(
                  selected: _radioSelected,
                  onTap: () => setState(() => _radioSelected = !_radioSelected),
                ),
                AppCheckCircle(
                  selected: _checkShopping,
                  onTap: () => setState(() => _checkShopping = !_checkShopping),
                ),
                AppCheckCircle(
                  type: AppCheckType.edit,
                  selected: _checkEdit,
                  onTap: () => setState(() => _checkEdit = !_checkEdit),
                ),
              ],
            ),
            _sectionTitle('Step Bar'),
            const AppStepBar(
              steps: ['商品', 'カテゴリ', '条件', '確認'],
              currentIndex: 2,
              expanded: true,
            ),
            const SizedBox(height: 10),
            const AppStepBar(
              steps: ['Step1', 'Step2', 'Step3', 'Step4'],
              currentIndex: 1,
              expanded: false,
            ),
            _sectionTitle('AppChip'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                AppSuggestionChip(
                  label: '牛乳',
                  avatar: const Icon(Icons.history, size: 14),
                  onTap: _noop,
                ),
                AppChoiceChipX(
                  label: 'カテゴリ',
                  selected: _choiceSelected,
                  onTap: () => setState(() => _choiceSelected = !_choiceSelected),
                ),
                AppConditionChip(
                  icon: Icons.straighten,
                  label: '欲しい量',
                  selected: _conditionSelected,
                  hasContent: true,
                  onTap: () => setState(
                    () => _conditionSelected = !_conditionSelected,
                  ),
                ),
              ],
            ),
            _sectionTitle('カテゴリチップ (AppChoiceChipX)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                AppChoiceChipX(label: '指定なし', selected: true),
                AppChoiceChipX(label: '野菜だね', selected: false),
                AppChoiceChipX(label: 'ペットあかかかか', selected: false),
                AppChoiceChipX(label: '肉', selected: false),
              ],
            ),
            _sectionTitle('AppSegmentedControl'),
            AppSegmentedControl<int>(
              options: const [
                AppSegmentOption(value: 0, label: '低'),
                AppSegmentOption(value: 1, label: '中'),
                AppSegmentOption(value: 2, label: '高'),
              ],
              selectedValue: _segmentValue,
              onChanged: (value) => setState(() => _segmentValue = value),
            ),
            _sectionTitle('AppDropdown'),
            AppDropdown<int>(
              value: _dropdownValue,
              options: const [
                AppDropdownOption(value: 0, label: 'g'),
                AppDropdownOption(value: 1, label: 'mg'),
                AppDropdownOption(value: 2, label: 'ml'),
              ],
              onChanged: (value) => setState(() => _dropdownValue = value),
            ),
            _sectionTitle('AppListItem'),
            const Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListItem(
                    showDivider: true,
                    leading: CircleAvatar(child: Icon(Icons.person, size: 16)),
                    title: Text('タイトル'),
                    subtitle: Text('サブタイトル'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  AppListItem(
                    title: Text('サブタイトルなし'),
                    trailing: Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
