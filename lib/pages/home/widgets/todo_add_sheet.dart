import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/home_provider.dart';
import '../view/todo_edit_page.dart';
import 'budget_section.dart';
import 'quantity_section.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import '../../../data/model/database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../view/category_edit_page.dart';

class TodoAddSheet extends ConsumerStatefulWidget {
  const TodoAddSheet({
    super.key,
    this.nameController,
    this.readOnlyNameField = false,
    this.isFullScreen = false,
    this.height,
    this.showHeader = true,
    this.hideNameField = false,
    this.onClose,
    this.includeKeyboardInsetInBody = true,
    this.keepKeyboardSpace = false,
    this.stayAfterAdd = false,
    this.hideOptionsWhileTyping = false,
    this.onSuggestionSelected,
    this.lastKeyboardInset,
    this.initialCategoryName,
    this.initialCategoryId,
    this.autoFocusNameField = false,
  });

  final TextEditingController? nameController;
  final bool readOnlyNameField;
  final bool isFullScreen;
  final double? height;
  final bool showHeader;
  final bool hideNameField;
  final VoidCallback? onClose;
  final bool includeKeyboardInsetInBody;
  final bool keepKeyboardSpace;
  final bool stayAfterAdd;
  final bool hideOptionsWhileTyping;
  final VoidCallback? onSuggestionSelected;
  final double? lastKeyboardInset;
  final String? initialCategoryName;
  final String? initialCategoryId;
  final bool autoFocusNameField;

  @override
  ConsumerState<TodoAddSheet> createState() => _TodoAddSheetState();
}

class _TodoAddSheetState extends ConsumerState<TodoAddSheet> {
  static const int _maxCategoryLength = 15;
  late TextEditingController editNameController;
  late final FocusNode _nameFocusNode;
  late final bool _ownsNameController;
  bool _suppressNameChange = false;
  int selectedPriority = 0;
  String category = "指定なし";
  String? selectedCategoryId;
  XFile? _selectedImage;
  String? _matchedImageUrl;
  String? selectedItemReading;
  List<dynamic> _suggestions = [];
  String _currentInputReading = "";
  int? _activeConditionTab; // 0=カテゴリ, 1=ほしい量, 2=予算, 3=写真
  double _lastKeyboardHeight = 0;
  int _budgetMinAmount = 0;
  int _budgetMaxAmount = 0;
  int _budgetType = 0;
  String _selectedQuantityPreset = '未指定';
  String _customQuantityValue = '';
  int _quantityUnit = 0;
  int? _quantityCount;
  bool _prefilledOptionsFromSuggestion = false;
  int _suggestionRequestId = 0;
  double _lastTypingPanelHeight = 0;

  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    // initState時にcontainerへの参照を保存（dispose時にcontextが使えないため）
    _container = ProviderScope.containerOf(context, listen: false);
    // Providerからドラフトを復元
    final draftName = _container.read(addSheetDraftNameProvider);
    if (widget.nameController != null) {
      editNameController = widget.nameController!;
      _ownsNameController = false;
      if (editNameController.text.isEmpty && draftName.isNotEmpty) {
        editNameController.text = draftName;
      }
    } else {
      editNameController = TextEditingController(text: draftName);
      _ownsNameController = true;
    }
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    selectedPriority = _container.read(addSheetDraftPriorityProvider);
    selectedCategoryId = _container.read(addSheetDraftCategoryIdProvider);
    category = _container.read(addSheetDraftCategoryNameProvider);
    final initialCategoryName = widget.initialCategoryName?.trim();
    final initialCategoryId = widget.initialCategoryId?.trim();
    if (initialCategoryName != null && initialCategoryName.isNotEmpty) {
      category = initialCategoryName;
      selectedCategoryId =
          (initialCategoryId == null || initialCategoryId.isEmpty)
              ? null
              : initialCategoryId;
    }
    _budgetMinAmount = _container.read(addSheetDraftBudgetMinAmountProvider);
    _budgetMaxAmount = _container.read(addSheetDraftBudgetMaxAmountProvider);
    _budgetType = _container.read(addSheetDraftBudgetTypeProvider);
    final draftQText = _container.read(addSheetDraftQuantityTextProvider);
    final draftQUnit = _container.read(addSheetDraftQuantityUnitProvider);
    if (draftQText != null && draftQUnit != null) {
      _selectedQuantityPreset = 'カスタム';
      _customQuantityValue = draftQText;
      _quantityUnit = draftQUnit;
    } else if (draftQText != null) {
      _selectedQuantityPreset = draftQText;
    }

    editNameController.addListener(_onNameControllerChanged);
    // 初期値に基づく候補/補完を反映
    Future.microtask(() => _handleNameChanged(editNameController.text));
  }

  @override
  void dispose() {
    // dispose時の値をキャプチャしてからコントローラーを破棄
    final draftName = editNameController.text;
    final draftPriority = selectedPriority;
    final draftCategoryId = selectedCategoryId;
    final draftCategoryName = category;
    final draftBudgetMinAmount = _budgetMinAmount;
    final draftBudgetMaxAmount = _budgetMaxAmount;
    final draftBudgetType = _budgetType;
    final draftQText = _selectedQuantityPreset == 'カスタム'
        ? _customQuantityValue
        : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null);
    final draftQUnit = _selectedQuantityPreset == 'カスタム' ? _quantityUnit : null;
    editNameController.removeListener(_onNameControllerChanged);
    if (_ownsNameController) {
      editNameController.dispose();
    }
    _nameFocusNode.dispose();
    final shouldDiscardOnClose =
        _container.read(addSheetDiscardOnCloseProvider);
    if (shouldDiscardOnClose) {
      super.dispose();
      return;
    }
    // ビルドフェーズ終了後にProviderを更新（ビルド中のstate変更を回避）
    Future.microtask(() {
      // すでに外部でドラフト破棄済みなら、dispose時に古い値で上書きしない
      final isAlreadyCleared =
          _container.read(addSheetDraftNameProvider).isEmpty &&
          _container.read(addSheetDraftPriorityProvider) == 0 &&
          _container.read(addSheetDraftCategoryIdProvider) == null &&
          _container.read(addSheetDraftCategoryNameProvider) == '指定なし' &&
          _container.read(addSheetDraftBudgetMinAmountProvider) == 0 &&
          _container.read(addSheetDraftBudgetMaxAmountProvider) == 0 &&
          _container.read(addSheetDraftBudgetTypeProvider) == 0 &&
          _container.read(addSheetDraftQuantityTextProvider) == null &&
          _container.read(addSheetDraftQuantityUnitProvider) == null;
      if (isAlreadyCleared) return;

      _container.read(addSheetDraftNameProvider.notifier).state = draftName;
      _container.read(addSheetDraftPriorityProvider.notifier).state = draftPriority;
      _container.read(addSheetDraftCategoryIdProvider.notifier).state = draftCategoryId;
      _container.read(addSheetDraftCategoryNameProvider.notifier).state = draftCategoryName;
      _container.read(addSheetDraftBudgetMinAmountProvider.notifier).state =
          draftBudgetMinAmount;
      _container.read(addSheetDraftBudgetMaxAmountProvider.notifier).state =
          draftBudgetMaxAmount;
      _container.read(addSheetDraftBudgetTypeProvider.notifier).state = draftBudgetType;
      _container.read(addSheetDraftQuantityTextProvider.notifier).state = draftQText;
      _container.read(addSheetDraftQuantityUnitProvider.notifier).state = draftQUnit;
    });
    super.dispose();
  }

  void _onNameControllerChanged() {
    if (_suppressNameChange) {
      _suppressNameChange = false;
      return;
    }
    // 候補(履歴)タップで引き継いだオプションは、手入力が始まった時点で破棄する。
    if (_prefilledOptionsFromSuggestion) {
      setState(() {
        _clearInheritedOptionValues();
        category = "指定なし";
        selectedCategoryId = null;
        _matchedImageUrl = null;
        selectedItemReading = null;
        _prefilledOptionsFromSuggestion = false;
      });
    }
    _handleNameChanged(editNameController.text);
  }

  Future<void> _handleNameChanged(String value) async {
    final requestId = ++_suggestionRequestId;

    // ホーム簡易追加では、外部フォーカス中のみ候補を扱う。
    if (widget.hideNameField && !widget.hideOptionsWhileTyping) {
      if (mounted) {
        setState(() {
          _suggestions = [];
        });
      }
      return;
    }

    final hasKanji = RegExp(r'[一-龠]').hasMatch(value);
    if (!hasKanji) {
      setState(() {
        _currentInputReading = value;
      });
    }
    if (value.isEmpty) {
      setState(() => _suggestions = []);
      _currentInputReading = "";
      selectedItemReading = null;
      return;
    }

    final suggestions = await ref.read(homeViewModelProvider).getSuggestions(value);

    if (!mounted) return;
    if (requestId != _suggestionRequestId) return;
    if (value != editNameController.text) return;
    setState(() {
      _suggestions = suggestions;
      // 手入力時は履歴オプションを自動適用しない。
      // オプション継承は _onSuggestionTap（明示選択）のみで行う。
      _matchedImageUrl = null;
      selectedItemReading = null;
    });
  }

  void _clearInheritedOptionValues() {
    _budgetMinAmount = 0;
    _budgetMaxAmount = 0;
    _budgetType = 0;
    _selectedQuantityPreset = '未指定';
    _customQuantityValue = '';
    _quantityUnit = 0;
    _quantityCount = null;
  }

  Future<void> _showPriorityInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/Tab_ItemCreate/book-open-check.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'お店にぴったりのアイテムが\nなかったときのために',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26 / 2,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3B4A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '似たものでも良ければ「目安でOK」\n必ず守る条件があれば「必ず条件を\n守る」を選択してください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24 / 2,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4A5A6D),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryLimitModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                  color: const Color(0xFF5A6E89),
                  splashRadius: 20,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/Tab_ItemCreate/img_Premium-lg.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '4個以上のカテゴリ追加には\nプラン変更が必要です',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3B4A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '変更で上限数を10個にアップ◎\n履歴・人数の上限アップ／広告非表示などの機\n能も充実します',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF4A5A6D),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: () {
                    showTopSnackBar(context, 'プレミアム詳細は準備中です');
                    Navigator.of(dialogContext).pop();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: const Color(0xFF2ECCA1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'プレミアムプラン詳細 ↗',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AppButton(
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAddAction({required bool reachedLimit}) {
    return TextButton(
      onPressed: reachedLimit ? _showCategoryLimitModal : _showAddCategoryModal,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reachedLimit) ...[
            Image.asset(
              'assets/images/common/crown.png',
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            'カテゴリ追加',
            style: TextStyle(
              color: AppColors.of(context).textAccentPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryModal() async {
    final myProfile = ref.read(myProfileProvider).value;
    final fixedBottomInset = _resolveCategoryModalBottomInset(context);
    Future<bool> askDiscardConfirmation(BuildContext dialogContext) async {
      final shouldDiscard = await showDialog<bool>(
        context: dialogContext,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '入力内容の破棄',
                  style: TextStyle(
                    fontSize: 30 / 2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3B4A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '変更は保存されていません\n破棄してよろしいですか？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27 / 2,
                    height: 1.6,
                    color: Color(0xFF4A5A6D),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: const Color(0xFFF2F5FA),
                      foregroundColor: const Color(0xFFC64063),
                    ),
                    child: const Text('破棄する'),
                  ),
                ),
                const SizedBox(height: 10),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
        ),
      );
      return shouldDiscard == true;
    }

    var shouldReopen = true;
    final controller = TextEditingController();
    while (shouldReopen) {
      shouldReopen = false;
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (modalContext, setModalState) {
              final appColors = AppColors.of(modalContext);
              final text = controller.text;
              final canSave =
                  text.trim().isNotEmpty && text.length <= _maxCategoryLength;

              Future<void> requestCloseWithConfirm() async {
                if (controller.text.trim().isEmpty) {
                  if (modalContext.mounted) {
                    Navigator.of(modalContext).pop('discard');
                  }
                  return;
                }
                final shouldDiscard = await askDiscardConfirmation(modalContext);
                if (shouldDiscard && modalContext.mounted) {
                  Navigator.of(modalContext).pop('discard');
                }
              }

              return Container(
                decoration: BoxDecoration(
                  color: appColors.surfaceHighOnInverse,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: appColors.borderMedium,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: requestCloseWithConfirm,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'カテゴリを追加',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: canSave
                                    ? () async {
                                        final name = controller.text.trim();
                                        try {
                                          await ref
                                              .read(categoryRepositoryProvider)
                                              .addCategory(
                                                name: name,
                                                userId: myProfile?.id ?? "",
                                                familyId: myProfile?.currentFamilyId,
                                              );
                                          if (!mounted) return;
                                          Navigator.of(modalContext).pop('saved');
                                          showTopSnackBar(
                                            context,
                                            'カテゴリ「$name」を追加しました',
                                            familyId: myProfile?.currentFamilyId,
                                          );
                                        } on CategoryLimitExceededException catch (e) {
                                          if (!mounted) return;
                                          showTopSnackBar(
                                            context,
                                            '無料プランはカテゴリ${e.limit}件までです',
                                            familyId: myProfile?.currentFamilyId,
                                          );
                                        } on DuplicateCategoryNameException {
                                          if (!mounted) return;
                                          showTopSnackBar(
                                            context,
                                            '同じ名前のカテゴリは追加できません',
                                            familyId: myProfile?.currentFamilyId,
                                          );
                                        }
                                      }
                                    : null,
                                child: const Text('保存'),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: appColors.borderLow),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            24,
                            16,
                            24 + fixedBottomInset + 40,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'カテゴリ名',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              AppTextField(
                                controller: controller,
                                hintText: '追加したいカテゴリを入力',
                                maxLength: _maxCategoryLength,
                                maxLengthEnforcement: MaxLengthEnforcement.none,
                                counterText:
                                    '${controller.text.length}/$_maxCategoryLength文字',
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (result == 'saved' || result == 'discard') {
        break;
      }

      if (controller.text.trim().isEmpty) {
        break;
      }

      if (!mounted) return;
      final shouldDiscard = await askDiscardConfirmation(context);
      if (!mounted) return;
      if (!shouldDiscard) {
        shouldReopen = true;
      }
    }
    // BottomSheetを閉じるアニメーション/キーボード遷移中にdisposeすると
    // TextField側がcontrollerへアクセスして例外になることがあるため、
    // 破棄を少し遅らせて安全に後始末する。
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      controller.dispose();
    });
  }

  double _resolveCategoryModalBottomInset(BuildContext context) {
    final media = MediaQuery.of(context);
    double inset = media.viewInsets.bottom;
    if (_lastKeyboardHeight > inset) inset = _lastKeyboardHeight;
    if ((widget.lastKeyboardInset ?? 0) > inset) {
      inset = widget.lastKeyboardInset!;
    }
    if (inset <= 0) inset = 320;
    final maxAllowed = media.size.height * 0.55;
    if (inset > maxAllowed) inset = maxAllowed;
    return inset;
  }

  Future<void> _showQuantityEditorModal() async {
    FocusScope.of(context).unfocus();
    final previousCanRequestFocus = _nameFocusNode.canRequestFocus;
    _nameFocusNode.canRequestFocus = false;
    // 直前の入力欄キーボードが閉じ切る前にモーダルを開くと、
    // viewInsetsの差分で高さが跳ねるため少し待ってから表示する。
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) {
      _nameFocusNode.canRequestFocus = previousCanRequestFocus;
      return;
    }

    var tempPreset = _selectedQuantityPreset;
    var tempCustomValue = _customQuantityValue;
    var tempUnit = _quantityUnit;
    int? tempCount = _quantityCount;
    final quantityCountFieldKey = GlobalKey();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              final screenHeight = MediaQuery.sizeOf(dialogContext).height;
              final keyboardInset = MediaQuery.of(dialogContext).viewInsets.bottom;

              return SafeArea(
                top: false,
                child: SizedBox(
                  height: screenHeight * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOptionModalHeader(
                        context: dialogContext,
                        title: 'ほしい量',
                        onBack: () => Navigator.pop(dialogContext),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => FocusScope.of(dialogContext).unfocus(),
                                  child: SingleChildScrollView(
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior.onDrag,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        QuantitySection(
                                          selectedPreset: tempPreset,
                                          customValue: tempCustomValue,
                                          unit: tempUnit,
                                          quantityCount: tempCount,
                                          quantityCountFieldKey:
                                              quantityCountFieldKey,
                                          onQuantityCountTap: () {
                                            Future<void> scrollToCountField() async {
                                              final fieldContext =
                                                  quantityCountFieldKey.currentContext;
                                              if (fieldContext == null) return;
                                              await Scrollable.ensureVisible(
                                                fieldContext,
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                curve: Curves.easeOut,
                                                alignment: 0.15,
                                              );
                                            }

                                            // 1) タップ直後
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              scrollToCountField();
                                            });
                                            // 2) キーボード表示後（レイアウト再計算後）
                                            Future<void>.delayed(
                                              const Duration(milliseconds: 180),
                                              scrollToCountField,
                                            );
                                          },
                                          onPresetChanged: (value) {
                                            setModalState(
                                              () => tempPreset = value,
                                            );
                                          },
                                          onCustomValueChanged: (value) {
                                            setModalState(
                                              () => tempCustomValue = value,
                                            );
                                          },
                                          onUnitChanged: (value) {
                                            setModalState(
                                              () => tempUnit = value,
                                            );
                                          },
                                          onQuantityCountChanged: (value) {
                                            setModalState(
                                              () => tempCount = value,
                                            );
                                          },
                                        ),
                                        SizedBox(
                                          height:
                                              keyboardInset > 0 ? keyboardInset : 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AppButton(
                                    variant: AppButtonVariant.text,
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('キャンセル'),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton(
                                    onPressed: () {
                                      setState(() {
                                        _prefilledOptionsFromSuggestion = false;
                                        _selectedQuantityPreset = tempPreset;
                                        _customQuantityValue = tempCustomValue;
                                        _quantityUnit = tempUnit;
                                        _quantityCount = tempCount;
                                      });
                                      Navigator.pop(dialogContext);
                                    },
                                    child: const Text('完了'),
                                  ),
                                ],
                              ),
                            ],
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
    } finally {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      _nameFocusNode.canRequestFocus = previousCanRequestFocus;
    }
  }

  Widget _buildOptionModalHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onBack,
  }) {
    final appColors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2),
        Center(
          child: Container(
            width: 72,
            height: 6,
            decoration: BoxDecoration(
              color: appColors.borderMedium,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3B4A),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        Divider(height: 1, color: appColors.borderLow),
      ],
    );
  }

  Future<void> _showBudgetEditorModal() async {
    FocusScope.of(context).unfocus();
    final previousCanRequestFocus = _nameFocusNode.canRequestFocus;
    _nameFocusNode.canRequestFocus = false;
    var tempMin = _budgetMinAmount;
    var tempMax = _budgetMaxAmount;
    var tempType = _budgetType;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOptionModalHeader(
                        context: dialogContext,
                        title: '予算',
                        onBack: () => Navigator.pop(dialogContext),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BudgetSection(
                              minAmount: tempMin,
                              maxAmount: tempMax,
                              type: tempType,
                              onRangeChanged: (range) {
                                setModalState(() {
                                  tempMin = range.min;
                                  tempMax = range.max;
                                });
                              },
                              onTypeChanged: (value) {
                                setModalState(() => tempType = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AppButton(
                                  variant: AppButtonVariant.text,
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('キャンセル'),
                                ),
                                const SizedBox(width: 8),
                                AppButton(
                                  onPressed: () {
                                    setState(() {
                                      _prefilledOptionsFromSuggestion = false;
                                      _budgetMinAmount = tempMin;
                                      _budgetMaxAmount = tempMax;
                                      _budgetType = tempType;
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text('完了'),
                                ),
                              ],
                            ),
                          ],
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
    } finally {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      _nameFocusNode.canRequestFocus = previousCanRequestFocus;
    }
  }

  Widget _buildSettingActionChip({
    required int index,
    required IconData icon,
    required String label,
    bool hasContent = false,
    VoidCallback? onTap,
    String? valueLabel,
    VoidCallback? onClear,
  }) {
    final appColors = AppColors.of(context);
    final effectiveLabel = valueLabel == null || valueLabel.isEmpty
        ? label
        : valueLabel;
    final activeStyle = hasContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          FocusScope.of(context).unfocus();
          if (onTap != null) {
            setState(() {
              _activeConditionTab = null;
            });
            onTap();
            return;
          }
          setState(() {
            _activeConditionTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activeStyle ? appColors.borderAccentPrimary : appColors.borderMedium,
              width: 1.2,
            ),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: activeStyle ? appColors.textAccentPrimary : appColors.surfaceMedium,
              ),
              const SizedBox(width: 6),
              Text(
                effectiveLabel,
                style: TextStyle(
                  color: activeStyle ? appColors.textAccentPrimary : appColors.textHigh,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasContent && onClear != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    onClear();
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: appColors.surfaceMedium,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _quantityChipValueLabel({
    required String preset,
    required String customValue,
    required int unit,
    required int? count,
  }) {
    String? base;
    if (preset == 'カスタム') {
      if (customValue.trim().isNotEmpty) {
        final units = ['g', 'mg', 'ml'];
        final safeUnit = (unit >= 0 && unit < units.length) ? units[unit] : '';
        base = '${customValue.trim()}$safeUnit';
      }
    } else if (preset != '未指定' && preset.trim().isNotEmpty) {
      base = preset.trim();
    }

    if (count != null && count > 0) {
      return base == null ? 'x$count' : '$base x$count';
    }
    return base;
  }

  String? _budgetChipValueLabel({
    required int minAmount,
    required int maxAmount,
    required int type,
  }) {
    if (maxAmount <= 0) return null;
    final unit = type == 1 ? '100g' : '1つ';
    if (minAmount > 0) return '¥$minAmount〜¥$maxAmount/$unit';
    return '¥$maxAmount/$unit';
  }

  Widget _buildActiveTabContent(AsyncValue<List<Category>> categoryAsync) {
    final reachedCategoryLimit =
        (categoryAsync.valueOrNull?.length ?? 0) >=
        CategoryRepository.freePlanCategoryLimit;
    if (_activeConditionTab == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('カテゴリ'),
              if (reachedCategoryLimit) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryEditPage(),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                ),
              ],
              const Spacer(),
              _buildCategoryAddAction(reachedLimit: reachedCategoryLimit),
            ],
          ),
          categoryAsync.when(
            data: (dbCategories) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int index = 0; index < dbCategories.length + 1; index++)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AppChoiceChipX(
                          label: index == 0 ? "指定なし" : dbCategories[index - 1].name,
                          selected: index == 0
                              ? selectedCategoryId == null
                              : dbCategories[index - 1].id == selectedCategoryId,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              category = index == 0
                                  ? "指定なし"
                                  : dbCategories[index - 1].name;
                              selectedCategoryId = index == 0
                                  ? null
                                  : dbCategories[index - 1].id;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    if (_activeConditionTab == 1) {
      return QuantitySection(
        selectedPreset: _selectedQuantityPreset,
        customValue: _customQuantityValue,
        unit: _quantityUnit,
        quantityCount: _quantityCount,
        onPresetChanged: (preset) {
          setState(() {
            _prefilledOptionsFromSuggestion = false;
            _selectedQuantityPreset = preset;
            if (preset == '未指定') {
              _customQuantityValue = '';
            }
          });
        },
        onCustomValueChanged: (value) => setState(() {
          _prefilledOptionsFromSuggestion = false;
          _customQuantityValue = value;
        }),
        onUnitChanged: (value) => setState(() {
          _prefilledOptionsFromSuggestion = false;
          _quantityUnit = value;
        }),
        onQuantityCountChanged: (value) => setState(() {
          _prefilledOptionsFromSuggestion = false;
          _quantityCount = value;
        }),
      );
    }

    if (_activeConditionTab == 2) {
      return BudgetSection(
        minAmount: _budgetMinAmount,
        maxAmount: _budgetMaxAmount,
        type: _budgetType,
        onRangeChanged: (range) => setState(() {
          _prefilledOptionsFromSuggestion = false;
          _budgetMinAmount = range.min;
          _budgetMaxAmount = range.max;
        }),
        onTypeChanged: (value) => setState(() {
          _prefilledOptionsFromSuggestion = false;
          _budgetType = value;
        }),
      );
    }

    if (_activeConditionTab == 3) {
      return Column(
        children: [
          if (_selectedImage != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: SizedBox(
                    height: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.close, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white70,
                  ),
                ),
              ],
            )
          else if (_matchedImageUrl != null)
            GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: SizedBox(
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _matchedImageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AppButton(
                variant: AppButtonVariant.text,
                icon: const Icon(Icons.camera_alt, size: 16),
                onPressed: () => _pickImage(ImageSource.camera),
                child: const Text('カメラで撮影'),
              ),
              AppButton(
                variant: AppButtonVariant.text,
                icon: const Icon(Icons.photo_library, size: 16),
                onPressed: () => _pickImage(ImageSource.gallery),
                child: const Text('写真から選択'),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );

    if (image == null) return;

    // --- ここから切り抜き処理 ---
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 正方形に固定
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '切り抜き',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // アスペクト比を固定
        ),
        IOSUiSettings(
          title: '切り抜き',
          aspectRatioLockEnabled: true, // アスペクト比を固定
          resetButtonHidden: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        // CroppedFile型をXFile型に戻して保持する
        _selectedImage = XFile(croppedFile.path);
      });
    }
  }

  Future<void> _submitAdd() async {
    final finalReading =
        (selectedItemReading != null && selectedItemReading!.isNotEmpty)
            ? selectedItemReading!
            : (_currentInputReading.isNotEmpty
                ? _currentInputReading
                : editNameController.text);

    final result = await ref.read(homeViewModelProvider).addTodo(
          text: editNameController.text,
          category: category,
          categoryId: selectedCategoryId,
          priority: selectedPriority,
          reading: finalReading,
          image: _selectedImage,
          budgetMinAmount: _budgetMaxAmount > 0 ? _budgetMinAmount : null,
          budgetMaxAmount: _budgetMaxAmount > 0 ? _budgetMaxAmount : null,
          budgetType: _budgetMaxAmount > 0 ? _budgetType : null,
          quantityText: _selectedQuantityPreset == 'カスタム'
              ? (_customQuantityValue.isNotEmpty ? _customQuantityValue : null)
              : (_selectedQuantityPreset != '未指定'
                  ? _selectedQuantityPreset
                  : null),
          quantityUnit: _selectedQuantityPreset == 'カスタム' &&
                  _customQuantityValue.isNotEmpty
              ? _quantityUnit
              : null,
          quantityCount: _quantityCount,
        );

    if (!mounted) return;
    if (result == null) {
      showTopSnackBar(
        context,
        '追加に失敗しました。設定を確認してください',
        familyId: ref.read(selectedFamilyIdProvider),
      );
      return;
    }

    // ドラフト状態をクリア
    editNameController.clear();
    ref.read(addSheetDraftNameProvider.notifier).state = '';
    ref.read(addSheetDraftPriorityProvider.notifier).state = 0;
    ref.read(addSheetDraftCategoryIdProvider.notifier).state = null;
    ref.read(addSheetDraftCategoryNameProvider.notifier).state = '指定なし';
    ref.read(addSheetDraftBudgetMinAmountProvider.notifier).state = 0;
    ref.read(addSheetDraftBudgetMaxAmountProvider.notifier).state = 0;
    ref.read(addSheetDraftBudgetTypeProvider.notifier).state = 0;
    ref.read(addSheetDraftQuantityTextProvider.notifier).state = null;
    ref.read(addSheetDraftQuantityUnitProvider.notifier).state = null;

    final currentContext = context;
    showTopSnackBar(
      currentContext,
      result.message,
      familyId: ref.read(selectedFamilyIdProvider),
      actionLabel: result.todoItem != null ? '編集' : null,
        onAction: result.todoItem != null
            ? (snackBarContext) {
                Navigator.push(
                  snackBarContext,
                  MaterialPageRoute(
                    builder: (_) => TodoEditPage(item: result.todoItem!),
                  ),
                );
              }
            : null,
    );

    // 連続追加モードの場合はページに留まる
    if (widget.stayAfterAdd) {
      setState(() {
        // ローカル状態もリセット
        selectedPriority = 0;
        category = '指定なし';
        selectedCategoryId = null;
        _selectedImage = null;
        _matchedImageUrl = null;
        selectedItemReading = null;
        _suggestions = [];
        _currentInputReading = '';
        _activeConditionTab = null;
        _budgetMinAmount = 0;
        _budgetMaxAmount = 0;
        _budgetType = 0;
        _selectedQuantityPreset = '未指定';
        _customQuantityValue = '';
        _quantityUnit = 0;
        _quantityCount = null;
      });
      return;
    }

    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(currentContext);
    }
  }

  // フルスクリーン用の縦積みレイアウト（編集ページ風）
  Widget _buildFullScreenLayout(AsyncValue<List<Category>> categoryAsync) {
    final reachedCategoryLimit =
        (categoryAsync.valueOrNull?.length ?? 0) >=
        CategoryRepository.freePlanCategoryLimit;
    final hasCustomQuantity = _selectedQuantityPreset == 'カスタム' &&
        _customQuantityValue.trim().isNotEmpty;
    final hasQuantityContent = hasCustomQuantity ||
        (_selectedQuantityPreset != '未指定' &&
            _selectedQuantityPreset != 'カスタム') ||
        (_quantityCount != null && _quantityCount! > 0);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 名前入力
          if (!widget.hideNameField)
            AppTextField(
              controller: editNameController,
              focusNode: _nameFocusNode,
              label: '買うものを入力…',
              autofocus: widget.autoFocusNameField,
              readOnly: widget.readOnlyNameField,
              showCursor: !widget.readOnlyNameField,
              onFieldSubmitted: (_) => _nameFocusNode.unfocus(),
            ),

          // 候補表示
          if (_suggestions.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final suggestion in _suggestions)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 8.0,
                        ),
                        child: AppSuggestionChip(
                          avatar: suggestion.imageUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    suggestion.imageUrl!,
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.history, size: 16),
                          label: suggestion.name,
                          onTap: () => _onSuggestionTap(suggestion),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // 条件の重視度
          Row(
            children: [
              const AppHeading('条件の重視度', type: AppHeadingType.tertiary),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _showPriorityInfoDialog,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppSegmentedControl<int>(
            options: const [
              AppSegmentOption(value: 0, label: '目安でOK'),
              AppSegmentOption(value: 1, label: '必ず条件を守る'),
            ],
            selectedValue: selectedPriority,
            onChanged: (newValue) {
              FocusScope.of(context).unfocus();
              setState(() {
                selectedPriority = newValue;
              });
            },
          ),

          const SizedBox(height: 16),

          // カテゴリ
          Row(
            children: [
              const AppHeading('カテゴリ', type: AppHeadingType.tertiary),
              if (reachedCategoryLimit) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryEditPage(),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                ),
              ],
              const Spacer(),
              _buildCategoryAddAction(reachedLimit: reachedCategoryLimit),
            ],
          ),
          categoryAsync.when(
            data: (dbCategories) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int index = 0; index < dbCategories.length + 1; index++)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AppChoiceChipX(
                          label: index == 0 ? "指定なし" : dbCategories[index - 1].name,
                          selected: index == 0
                              ? selectedCategoryId == null
                              : dbCategories[index - 1].id == selectedCategoryId,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              category = index == 0
                                  ? "指定なし"
                                  : dbCategories[index - 1].name;
                              selectedCategoryId = index == 0
                                  ? null
                                  : dbCategories[index - 1].id;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // 希望の条件
          const Align(
            alignment: Alignment.centerLeft,
            child: AppHeading('希望の条件', type: AppHeadingType.tertiary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSettingActionChip(
                  index: 3,
                  icon: Icons.camera_alt,
                  label: '写真で伝える',
                  hasContent: _selectedImage != null || _matchedImageUrl != null,
                  onTap: () {
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(width: 8),
                _buildSettingActionChip(
                  index: 1,
                  icon: Icons.straighten,
                  label: 'ほしい量',
                  hasContent: hasQuantityContent,
                  onTap: _showQuantityEditorModal,
                  valueLabel: _quantityChipValueLabel(
                    preset: _selectedQuantityPreset,
                    customValue: _customQuantityValue,
                    unit: _quantityUnit,
                    count: _quantityCount,
                  ),
                  onClear: () {
                    setState(() {
                      _prefilledOptionsFromSuggestion = false;
                      _selectedQuantityPreset = '未指定';
                      _customQuantityValue = '';
                      _quantityUnit = 0;
                      _quantityCount = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildSettingActionChip(
                  index: 2,
                  icon: Icons.payments,
                  label: '予算',
                  hasContent: _budgetMaxAmount > 0,
                  onTap: _showBudgetEditorModal,
                  valueLabel: _budgetChipValueLabel(
                    minAmount: _budgetMinAmount,
                    maxAmount: _budgetMaxAmount,
                    type: _budgetType,
                  ),
                  onClear: () {
                    setState(() {
                      _prefilledOptionsFromSuggestion = false;
                      _budgetMinAmount = 0;
                      _budgetMaxAmount = 0;
                      _budgetType = 0;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 選択中のタブのコンテンツ
          if (_activeConditionTab == 1)
            QuantitySection(
              selectedPreset: _selectedQuantityPreset,
              customValue: _customQuantityValue,
              unit: _quantityUnit,
              quantityCount: _quantityCount,
              onPresetChanged: (preset) {
                setState(() {
                  _prefilledOptionsFromSuggestion = false;
                  _selectedQuantityPreset = preset;
                  if (preset == '未指定') {
                    _customQuantityValue = '';
                  }
                });
              },
              onCustomValueChanged: (value) =>
                  setState(() {
                    _prefilledOptionsFromSuggestion = false;
                    _customQuantityValue = value;
                  }),
              onUnitChanged: (value) => setState(() {
                _prefilledOptionsFromSuggestion = false;
                _quantityUnit = value;
              }),
              onQuantityCountChanged: (value) =>
                  setState(() {
                    _prefilledOptionsFromSuggestion = false;
                    _quantityCount = value;
                  }),
            ),

          if (_activeConditionTab == 2)
            BudgetSection(
              minAmount: _budgetMinAmount,
              maxAmount: _budgetMaxAmount,
              type: _budgetType,
              onRangeChanged: (range) => setState(() {
                _prefilledOptionsFromSuggestion = false;
                _budgetMinAmount = range.min;
                _budgetMaxAmount = range.max;
              }),
              onTypeChanged: (value) => setState(() {
                _prefilledOptionsFromSuggestion = false;
                _budgetType = value;
              }),
            ),

          if (_activeConditionTab == 3) ...[
            if (_selectedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: SizedBox(
                      height: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white70,
                    ),
                  ),
                ],
              )
            else if (_matchedImageUrl != null)
              GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _matchedImageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  icon: const Icon(Icons.camera_alt, size: 16),
                  onPressed: () => _pickImage(ImageSource.camera),
                  child: const Text('カメラで撮影'),
                ),
                AppButton(
                  variant: AppButtonVariant.text,
                  icon: const Icon(Icons.photo_library, size: 16),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  child: const Text('写真から選択'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // 追加ボタン
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: editNameController,
            builder: (_, value, __) {
              final canSubmit = value.text.trim().isNotEmpty;
              return SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: canSubmit ? _submitAdd : null,
                  child: const Text('リストに追加'),
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }

  // 候補タップ時の共通処理
  void _onSuggestionTap(SearchSuggestion item) {
    _suggestionRequestId++;
    FocusScope.of(context).unfocus();
    _nameFocusNode.unfocus();
    widget.onSuggestionSelected?.call();
    _suppressNameChange = true;
    setState(() {
      editNameController.text = item.name;
      selectedItemReading = item.reading;
      _suggestions = [];
      if (item.original is Item) {
        final original = item.original as Item;
        category = original.category;
        selectedCategoryId = original.categoryId;
        _matchedImageUrl = original.imageUrl;
        selectedItemReading = item.reading;
        _currentInputReading = item.reading;
        final originalBudgetMax = original.budgetMaxAmount;
        var hasInheritedOption = false;
        if (originalBudgetMax != null && originalBudgetMax > 0) {
          _budgetMinAmount = original.budgetMinAmount ?? 0;
          _budgetMaxAmount = originalBudgetMax;
          _budgetType = original.budgetType ?? 0;
          hasInheritedOption = true;
        } else {
          _budgetMinAmount = 0;
          _budgetMaxAmount = 0;
          _budgetType = 0;
        }
        _quantityCount = original.quantityCount;
        if (_quantityCount != null && _quantityCount! > 0) {
          hasInheritedOption = true;
        }
        if (original.quantityText != null) {
          if (original.quantityUnit != null) {
            _selectedQuantityPreset = 'カスタム';
            _customQuantityValue = original.quantityText!;
            _quantityUnit = original.quantityUnit!;
            hasInheritedOption = true;
          } else {
            _selectedQuantityPreset = original.quantityText!;
            hasInheritedOption = true;
          }
        } else {
          _selectedQuantityPreset = '未指定';
          _customQuantityValue = '';
          _quantityUnit = 0;
          _quantityCount = null;
        }
        _prefilledOptionsFromSuggestion = hasInheritedOption;
      } else {
        category = "指定なし";
        selectedCategoryId = null;
        _matchedImageUrl = null;
        _clearInheritedOptionValues();
        _prefilledOptionsFromSuggestion = false;
      }
      editNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: editNameController.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);

    // フルスクリーンモードの場合は縦積みレイアウトを使用
    if (widget.isFullScreen) {
      return _buildFullScreenLayout(categoryAsync);
    }

    // 以下はモーダル用のレイアウト
    final showOptionsWhileEditing = !widget.hideOptionsWhileTyping;
    final isTypingOnlyMode = widget.hideOptionsWhileTyping;
    final isTypingFocus = widget.hideNameField
        ? widget.hideOptionsWhileTyping
        : _nameFocusNode.hasFocus;
    final showTypingSuggestions =
        _suggestions.isNotEmpty && isTypingFocus;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final showDetailPanel = _activeConditionTab != null;

    // 入力中(タブ未選択)はキーボード高さを取り込み、タブ選択後は固定値として使う
    if (!showDetailPanel && keyboardHeight > 0) {
      if (keyboardHeight > _lastKeyboardHeight) {
        _lastKeyboardHeight = keyboardHeight;
      }
    }

    final resolvedKeyboardHeight = _lastKeyboardHeight > 0
        ? _lastKeyboardHeight
        : (widget.lastKeyboardInset != null && widget.lastKeyboardInset! > 0
            ? widget.lastKeyboardInset!
            : (keyboardHeight > 0 ? keyboardHeight : 220.0));
    final detailPanelHeight = resolvedKeyboardHeight;
    final suggestionHeight =
        (isTypingOnlyMode && _suggestions.isNotEmpty) ? 50.0 : 0.0;
    final typingInset = (isTypingOnlyMode && showTypingSuggestions)
        ? MediaQuery.of(context).viewInsets.bottom
        : 0.0;
    if (isTypingOnlyMode && showTypingSuggestions && typingInset > 0) {
      _lastTypingPanelHeight = suggestionHeight + typingInset;
    }

    final panelHeight = isTypingOnlyMode
        ? (suggestionHeight + typingInset)
        : (_lastTypingPanelHeight > 0
            ? _lastTypingPanelHeight
            : resolvedKeyboardHeight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: panelHeight,
      child: Column(
        children: [
          if (widget.showHeader) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onClose ?? () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const Text(
                    'アイテムを追加',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: (isTypingOnlyMode
                          ? 0
                          : (widget.includeKeyboardInsetInBody
                              ? MediaQuery.of(context).viewInsets.bottom
                              : 0)) +
                      (showDetailPanel ? 12 : 0),
                ),
                child: Column(
                  children: [
                  if (!widget.hideNameField)
                    AppTextField(
                      controller: editNameController,
                      focusNode: _nameFocusNode,
                      label: '買うものを入力…',
                      autofocus: widget.autoFocusNameField,
                      readOnly: widget.readOnlyNameField,
                      showCursor: !widget.readOnlyNameField,
                      onFieldSubmitted: (_) => _nameFocusNode.unfocus(),
                    ),

                  if (showTypingSuggestions)
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final suggestion in _suggestions)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 8.0,
                                ),
                                child: AppSuggestionChip(
                                  avatar: suggestion.imageUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            suggestion.imageUrl!,
                                            width: 20,
                                            height: 20,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.history, size: 16),
                                  label: suggestion.name,
                                  onTap: () => _onSuggestionTap(suggestion),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  if (showOptionsWhileEditing) ...[
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Text('条件の重要度', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _showPriorityInfoDialog,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          icon: const Icon(Icons.info_outline, size: 14),
                        ),
                      ],
                    ),
                    AppSegmentedControl<int>(
                      options: const [
                        AppSegmentOption(value: 0, label: '目安でOK'),
                        AppSegmentOption(value: 1, label: '必ず条件を守る'),
                      ],
                      selectedValue: selectedPriority,
                      onChanged: (newValue) {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          selectedPriority = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSettingActionChip(
                                    index: 0,
                                    icon: Icons.category,
                                    label: 'カテゴリ',
                                    hasContent: selectedCategoryId != null,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSettingActionChip(
                                    index: 3,
                                    icon: Icons.camera_alt,
                                    label: '写真で伝える',
                                    hasContent: _selectedImage != null || _matchedImageUrl != null,
                                    onTap: () {
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSettingActionChip(
                                    index: 1,
                                    icon: Icons.straighten,
                                    label: 'ほしい量',
                                    hasContent: _selectedQuantityPreset != '未指定' || (_quantityCount != null && _quantityCount! > 0),
                                    onTap: _showQuantityEditorModal,
                                    valueLabel: _quantityChipValueLabel(
                                      preset: _selectedQuantityPreset,
                                      customValue: _customQuantityValue,
                                      unit: _quantityUnit,
                                      count: _quantityCount,
                                    ),
                                    onClear: () {
                                      setState(() {
                                        _prefilledOptionsFromSuggestion = false;
                                        _selectedQuantityPreset = '未指定';
                                        _customQuantityValue = '';
                                        _quantityUnit = 0;
                                        _quantityCount = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSettingActionChip(
                                    index: 2,
                                    icon: Icons.payments,
                                    label: '予算',
                                    hasContent: _budgetMaxAmount > 0,
                                    onTap: _showBudgetEditorModal,
                                    valueLabel: _budgetChipValueLabel(
                                      minAmount: _budgetMinAmount,
                                      maxAmount: _budgetMaxAmount,
                                      type: _budgetType,
                                    ),
                                    onClear: () {
                                      setState(() {
                                        _prefilledOptionsFromSuggestion = false;
                                        _budgetMinAmount = 0;
                                        _budgetMaxAmount = 0;
                                        _budgetType = 0;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: editNameController,
                          builder: (_, value, __) {
                            final canSubmit = value.text.trim().isNotEmpty;
                            return AppButton(
                              size: AppButtonSize.sm,
                              onPressed: canSubmit ? _submitAdd : null,
                              child: const Text('リストに追加'),
                            );
                          },
                        ),
                      ],
                    ),
                    if (showDetailPanel) ...[
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        height: detailPanelHeight,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: SingleChildScrollView(
                          child: _buildActiveTabContent(categoryAsync),
                        ),
                      ),
                    ],
                  ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
