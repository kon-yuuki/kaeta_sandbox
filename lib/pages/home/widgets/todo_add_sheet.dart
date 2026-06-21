import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_bottom_sheet_header.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../../core/widgets/app_action_icons.dart';
import '../../../core/widgets/app_bottom_action_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/home_provider.dart';
import '../view/todo_edit_page.dart';
import 'budget_section.dart';
import 'quantity_section.dart';
import '../../../data/providers/billing_provider.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import '../../../data/model/database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../../data/repositories/todo_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../view/item_camera_capture_page.dart';
import 'category_edit_sheet.dart';
import 'category_name_editor_sheet.dart';
import '../../setting/view/premium_plan_sheet.dart';

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
    this.editItem,
    this.editImageUrl,
    this.showBottomSubmitBar = true,
    this.onBindSubmitAction,
    this.onSubmitEnabledChanged,
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
  final TodoItem? editItem;
  final String? editImageUrl;
  final bool showBottomSubmitBar;
  final ValueChanged<VoidCallback?>? onBindSubmitAction;
  final ValueChanged<bool>? onSubmitEnabledChanged;

  @override
  ConsumerState<TodoAddSheet> createState() => _TodoAddSheetState();
}

class _TodoAddSheetState extends ConsumerState<TodoAddSheet> {
  static const int _maxCategoryLength = 15;
  static const double _optionSheetHeightRatio = 596 / 852;
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
  bool _preserveMatchedImageFromSelection = false;
  bool _showOptionsAfterNameCommit = false;
  int _suggestionRequestId = 0;
  bool _lastCanSubmit = false;
  bool _allowPop = false;
  String _lastObservedNameText = '';

  String _initialName = '';
  int _initialPriority = 0;
  String _initialCategory = '指定なし';
  String? _initialCategoryId;
  String? _initialImageUrl;
  int _initialBudgetMinAmount = 0;
  int _initialBudgetMaxAmount = 0;
  int _initialBudgetType = 0;
  String _initialQuantityPreset = '未指定';
  String _initialCustomQuantityValue = '';
  int _initialQuantityUnit = 0;
  int? _initialQuantityCount;

  late final ProviderContainer _container;
  bool get _isEditMode => widget.editItem != null;

  void _notifySubmitBridge() {
    widget.onBindSubmitAction?.call(_submitAdd);
    _notifySubmitEnabledIfChanged();
  }

  void _notifySubmitEnabledIfChanged() {
    final canSubmit = _isEditMode
        ? editNameController.text.trim().isNotEmpty && _hasUnsavedChangesInEdit()
        : editNameController.text.trim().isNotEmpty;
    if (canSubmit == _lastCanSubmit) return;
    _lastCanSubmit = canSubmit;
    widget.onSubmitEnabledChanged?.call(canSubmit);
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final item = widget.editItem!;
      editNameController = TextEditingController(text: item.name);
      _ownsNameController = true;
      _nameFocusNode = FocusNode();
      _nameFocusNode.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      selectedPriority = item.priority;
      selectedCategoryId = (item.categoryId?.trim().isEmpty ?? true)
          ? null
          : item.categoryId!.trim();
      category = item.category.trim().isEmpty ? '指定なし' : item.category.trim();
      _matchedImageUrl = widget.editImageUrl;
      _budgetMinAmount = item.budgetMinAmount ?? 0;
      _budgetMaxAmount = item.budgetMaxAmount ?? 0;
      _budgetType = item.budgetType ?? 0;
      final qText = item.quantityText;
      final qUnit = item.quantityUnit;
      if (qText != null && qUnit != null) {
        _selectedQuantityPreset = 'カスタム';
        _customQuantityValue = qText;
        _quantityUnit = qUnit;
      } else if (qText != null) {
        _selectedQuantityPreset = qText;
      }
      _quantityCount = item.quantityCount;
      _initialName = editNameController.text.trim();
      _initialPriority = selectedPriority;
      _initialCategory = category.trim();
      _initialCategoryId = selectedCategoryId;
      _initialImageUrl = _matchedImageUrl;
      _initialBudgetMinAmount = _budgetMinAmount;
      _initialBudgetMaxAmount = _budgetMaxAmount;
      _initialBudgetType = _budgetType;
      _initialQuantityPreset = _selectedQuantityPreset;
      _initialCustomQuantityValue = _customQuantityValue;
      _initialQuantityUnit = _quantityUnit;
      _initialQuantityCount = _quantityCount;
      _showOptionsAfterNameCommit = editNameController.text.trim().isNotEmpty;
      _lastObservedNameText = editNameController.text;
      editNameController.addListener(_onNameControllerChanged);
      Future.microtask(() => _handleNameChanged(editNameController.text));
      debugPrint(
        'TodoAddSheet(edit): itemId=${item.itemId} initialImageUrl=${widget.editImageUrl}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifySubmitBridge();
      });
      return;
    }

    // initState時にcontainerへの参照を保存（dispose時にcontextが使えないため）
    _container = ProviderScope.containerOf(context, listen: false);
    Future.microtask(() {
      if (!mounted) return;
      _container.read(addSheetDiscardOnCloseProvider.notifier).state = false;
    });
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
    _lastObservedNameText = editNameController.text;
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
    _showOptionsAfterNameCommit = editNameController.text.trim().isNotEmpty;

    editNameController.addListener(_onNameControllerChanged);
    // 初期値に基づく候補/補完を反映
    Future.microtask(() => _handleNameChanged(editNameController.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifySubmitBridge();
    });
  }

  @override
  void didUpdateWidget(covariant TodoAddSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBindSubmitAction != widget.onBindSubmitAction ||
        oldWidget.onSubmitEnabledChanged != widget.onSubmitEnabledChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifySubmitBridge();
      });
    }
  }

  @override
  void dispose() {
    if (_isEditMode) {
      editNameController.removeListener(_onNameControllerChanged);
      widget.onBindSubmitAction?.call(null);
      widget.onSubmitEnabledChanged?.call(false);
      if (_ownsNameController) {
        editNameController.dispose();
      }
      _nameFocusNode.dispose();
      super.dispose();
      return;
    }

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
    widget.onBindSubmitAction?.call(null);
    widget.onSubmitEnabledChanged?.call(false);
    if (_ownsNameController) {
      editNameController.dispose();
    }
    _nameFocusNode.dispose();
    final shouldDiscardOnClose = _container.read(
      addSheetDiscardOnCloseProvider,
    );
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
      _container.read(addSheetDraftPriorityProvider.notifier).state =
          draftPriority;
      _container.read(addSheetDraftCategoryIdProvider.notifier).state =
          draftCategoryId;
      _container.read(addSheetDraftCategoryNameProvider.notifier).state =
          draftCategoryName;
      _container.read(addSheetDraftBudgetMinAmountProvider.notifier).state =
          draftBudgetMinAmount;
      _container.read(addSheetDraftBudgetMaxAmountProvider.notifier).state =
          draftBudgetMaxAmount;
      _container.read(addSheetDraftBudgetTypeProvider.notifier).state =
          draftBudgetType;
      _container.read(addSheetDraftQuantityTextProvider.notifier).state =
          draftQText;
      _container.read(addSheetDraftQuantityUnitProvider.notifier).state =
          draftQUnit;
    });
    super.dispose();
  }

  void _onNameControllerChanged() {
    final currentText = editNameController.text;
    final didTextChange = currentText != _lastObservedNameText;
    _lastObservedNameText = currentText;
    if (_isEditMode && mounted) {
      setState(() {});
    }
    _notifySubmitEnabledIfChanged();
    if (_suppressNameChange) {
      _suppressNameChange = false;
      return;
    }
    // 候補(履歴)タップで引き継いだオプションは、
    // 名前を完全に空にした時だけ破棄する。
    if (_prefilledOptionsFromSuggestion &&
        didTextChange &&
        currentText.trim().isEmpty) {
      setState(() {
        _clearInheritedOptionValues();
        category = "指定なし";
        selectedCategoryId = null;
        _matchedImageUrl = null;
        selectedItemReading = null;
        _prefilledOptionsFromSuggestion = false;
        _showOptionsAfterNameCommit = false;
        _preserveMatchedImageFromSelection = false;
      });
    }
    if (didTextChange &&
        currentText.trim().isEmpty &&
        _showOptionsAfterNameCommit) {
      setState(() {
        _showOptionsAfterNameCommit = false;
      });
    }
    _handleNameChanged(editNameController.text);
  }

  Future<void> _handleNameChanged(String value) async {
    final requestId = ++_suggestionRequestId;
    final shouldRestoreFocusAfterLayoutChange =
        _nameFocusNode.hasFocus && _matchedImageUrl != null;

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

    final suggestions = await ref
        .read(homeViewModelProvider)
        .getSuggestions(value);

    if (!mounted) return;
    if (requestId != _suggestionRequestId) return;
    if (value != editNameController.text) return;
    final shouldClearMatchedImage =
        !_isEditMode && !_preserveMatchedImageFromSelection;
    setState(() {
      _suggestions = suggestions;
      // 手入力時は履歴オプションを自動適用しない。
      // ただし編集モード、または履歴/候補選択から引き継いだ画像は維持する。
      if (shouldClearMatchedImage) {
        _matchedImageUrl = null;
      }
      selectedItemReading = null;
    });
    if (shouldClearMatchedImage && shouldRestoreFocusAfterLayoutChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_nameFocusNode.hasFocus) {
          _nameFocusNode.requestFocus();
        }
      });
    }
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
      builder: (dialogContext) {
        final appColors = AppColors.of(dialogContext);
        final appTypography = AppTypography.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: appColors.surfaceHighOnInverse,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 270,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
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
                  Text(
                    'お店にぴったりのアイテムが\nなかったときのために',
                    textAlign: TextAlign.center,
                    style: appTypography.std16B150.copyWith(
                      color: appColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '似たものでも良ければ「目安でOK」\n必ず守る条件があれば「必ず条件を\n守る」を選択してください',
                    textAlign: TextAlign.center,
                    style: appTypography.std14R160.copyWith(
                      color: appColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: appTypography.std14B160.copyWith(
                          color: appColors.textHighOnInverse,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryAddAction({required bool reachedLimit}) {
    return TextButton(
      onPressed: reachedLimit
          ? () => openPremiumPlanPage(context)
          : _showAddCategoryModal,
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
            'カテゴリを追加',
            style: AppTypography.of(context).jaOnl12B100.copyWith(
              color: AppColors.of(context).textAccentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryModal() async {
    final myProfile = ref.read(myProfileProvider).value;
    final name = await showCategoryNameEditorSheet(
      context: context,
      title: 'カテゴリを編集',
      initialName: '',
      hintText: 'カテゴリ名を入力',
      maxLength: _maxCategoryLength,
    );
    if (!mounted || name == null || name.isEmpty) return;
    try {
      await ref
          .read(categoryRepositoryProvider)
          .addCategory(
            name: name,
            userId: myProfile?.id ?? "",
            familyId: myProfile?.currentFamilyId,
            maxCategoryCount: ref.read(categoryLimitProvider),
          );
      if (!mounted) return;
      showTopSnackBar(
        context,
        'カテゴリ「$name」を追加しました',
        familyId: myProfile?.currentFamilyId,
      );
    } on CategoryLimitExceededException catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        '現在のプランではカテゴリ${e.limit}件までです',
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
    final customValueFieldKey = GlobalKey();
    final quantityCountFieldKey = GlobalKey();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.white,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              final screenHeight = MediaQuery.sizeOf(dialogContext).height;
              final keyboardInset = MediaQuery.of(
                dialogContext,
              ).viewInsets.bottom;
              final canSaveQuantity =
                  tempPreset != _selectedQuantityPreset ||
                  tempCustomValue != _customQuantityValue ||
                  tempUnit != _quantityUnit ||
                  tempCount != _quantityCount;

              return SafeArea(
                top: false,
                child: SizedBox(
                  height: screenHeight * _optionSheetHeightRatio,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBottomSheetHeader(
                        title: 'ほしい量',
                        onBack: () => Navigator.pop(dialogContext),
                        trailing: AppBottomSheetSaveButton(
                          enabled: canSaveQuantity,
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
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Column(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      FocusScope.of(dialogContext).unfocus(),
                                  child: SingleChildScrollView(
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        QuantitySection(
                                          selectedPreset: tempPreset,
                                          customValue: tempCustomValue,
                                          unit: tempUnit,
                                          quantityCount: tempCount,
                                          customValueFieldKey:
                                              customValueFieldKey,
                                          onCustomValueTap: () {
                                            Future<void>
                                            scrollToCustomField() async {
                                              final fieldContext =
                                                  customValueFieldKey
                                                      .currentContext;
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

                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  scrollToCustomField();
                                                });
                                            for (final ms in [
                                              120,
                                              240,
                                              380,
                                              520,
                                            ]) {
                                              Future<void>.delayed(
                                                Duration(milliseconds: ms),
                                                scrollToCustomField,
                                              );
                                            }
                                          },
                                          quantityCountFieldKey:
                                              quantityCountFieldKey,
                                          onQuantityCountTap: () {
                                            Future<void>
                                            scrollToCountField() async {
                                              final fieldContext =
                                                  quantityCountFieldKey
                                                      .currentContext;
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

                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  scrollToCountField();
                                                });
                                            for (final ms in [
                                              120,
                                              240,
                                              380,
                                              520,
                                            ]) {
                                              Future<void>.delayed(
                                                Duration(milliseconds: ms),
                                                scrollToCountField,
                                              );
                                            }
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
                                          height: keyboardInset > 0
                                              ? keyboardInset
                                              : 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
        showDragHandle: false,
        backgroundColor: Colors.white,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              final screenHeight = MediaQuery.sizeOf(dialogContext).height;
              final canSaveBudget =
                  tempMin != _budgetMinAmount ||
                  tempMax != _budgetMaxAmount ||
                  tempType != _budgetType;
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: screenHeight * _optionSheetHeightRatio,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          MediaQuery.of(dialogContext).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      children: [
                        AppBottomSheetHeader(
                          title: '予算',
                          onBack: () => Navigator.pop(dialogContext),
                          trailing: AppBottomSheetSaveButton(
                            enabled: canSaveBudget,
                            onPressed: () {
                              setState(() {
                                _prefilledOptionsFromSuggestion = false;
                                _budgetMinAmount = tempMin;
                                _budgetMaxAmount = tempMax;
                                _budgetType = tempType;
                              });
                              Navigator.pop(dialogContext);
                            },
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BudgetSection(
                                    minAmount: tempMin,
                                    maxAmount: tempMax,
                                    type: tempType,
                                    onRangeChanged: (range) {
                                      final normalized = _normalizeBudgetRange(
                                        min: range.min,
                                        max: range.max,
                                      );
                                      setModalState(() {
                                        tempMin = normalized.min;
                                        tempMax = normalized.max;
                                      });
                                    },
                                    onTypeChanged: (value) {
                                      setModalState(() => tempType = value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
    required String label,
    IconData? icon,
    String? iconAsset,
    String? activeIconAsset,
    bool hasContent = false,
    VoidCallback? onTap,
    String? valueLabel,
    VoidCallback? onClear,
  }) {
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    final effectiveLabel = valueLabel == null || valueLabel.isEmpty
        ? label
        : valueLabel;
    final activeStyle = hasContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activeStyle
                  ? appColors.borderAccentPrimary
                  : appColors.borderLow,
              width: 1.2,
            ),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingActionChipIcon(
                icon: icon,
                assetPath: activeStyle
                    ? activeIconAsset ?? iconAsset
                    : iconAsset,
                active: activeStyle,
              ),
              const SizedBox(width: 6),
              Text(
                effectiveLabel,
                style: appTypography.jaOnl12B100.copyWith(
                  color: activeStyle
                      ? appColors.textAccentPrimary
                      : appColors.textMedium,
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
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: appColors.surfaceMedium,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
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

  Widget _buildSettingActionChipIcon({
    IconData? icon,
    String? assetPath,
    required bool active,
  }) {
    final appColors = AppColors.of(context);
    if (assetPath != null) {
      final iconColor = active ? appColors.accentPrimary : appColors.surfaceLow;
      final iconWidget = assetPath.endsWith('.svg')
          ? SvgPicture.asset(
              assetPath,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            )
          : Image.asset(assetPath, width: 16, height: 16);
      return SizedBox(width: 16, height: 16, child: iconWidget);
    }

    return Icon(
      icon,
      size: 16,
      color: active ? appColors.textAccentPrimary : appColors.surfaceMedium,
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
        final units = ['g', 'mg', 'ml', 'kg', 'L'];
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
    const upperNoneThreshold = 2050;
    if (maxAmount <= 0) return null;
    final unit = type == 1 ? '100g' : '1つ';
    if (maxAmount >= upperNoneThreshold) {
      return minAmount <= 0 ? null : '$minAmount円以上／$unit';
    }
    if (minAmount <= 0) return '$maxAmount円以下／$unit';
    if (minAmount >= maxAmount) return '$minAmount円以上／$unit';
    return '$minAmount〜$maxAmount円／$unit';
  }

  ({int min, int max}) _normalizeBudgetRange({
    required int min,
    required int max,
  }) {
    if (min <= 0 && max >= 2050) {
      return (min: 0, max: 0);
    }
    return (min: min, max: max);
  }

  String? _selectedCategoryValueLabel(List<Category>? categories) {
    final categoryId = selectedCategoryId;
    if (categoryId == null || categories == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return null;
  }

  Widget _buildActiveTabContent(AsyncValue<List<Category>> categoryAsync) {
    final categoryLimit = ref.watch(categoryLimitProvider);
    final reachedCategoryLimit =
        categoryLimit != null &&
        (categoryAsync.valueOrNull?.length ?? 0) >= categoryLimit;
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
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      backgroundColor: Colors.white,
                      builder: (sheetContext) {
                        return const CategoryEditSheet(
                          showHeader: true,
                          fullHeight: false,
                        );
                      },
                    );
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  icon: const AppActionIcon.pen(size: 16),
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
                    for (
                      int index = 0;
                      index < dbCategories.length + 1;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AppChoiceChipX(
                          label: index == 0
                              ? "指定なし"
                              : dbCategories[index - 1].name,
                          selected: index == 0
                              ? selectedCategoryId == null
                              : dbCategories[index - 1].id ==
                                    selectedCategoryId,
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
          final normalized = _normalizeBudgetRange(
            min: range.min,
            max: range.max,
          );
          _prefilledOptionsFromSuggestion = false;
          _budgetMinAmount = normalized.min;
          _budgetMaxAmount = normalized.max;
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
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
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
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
    XFile? image;
    if (source == ImageSource.camera) {
      image = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const ItemCameraCapturePage()),
      );
    } else {
      final ImagePicker picker = ImagePicker();
      image = await picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
    }

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
    if (_isEditMode) {
      final item = widget.editItem!;
      final bool budgetSet = _budgetMaxAmount > 0;
      final bool wasBudgetEnabled = (item.budgetMaxAmount ?? 0) > 0;
      final String? finalQText = _selectedQuantityPreset == 'カスタム'
          ? (_customQuantityValue.isNotEmpty ? _customQuantityValue : null)
          : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null);
      final int? finalQUnit =
          _selectedQuantityPreset == 'カスタム' && _customQuantityValue.isNotEmpty
          ? _quantityUnit
          : null;
      final bool wasQuantitySet = item.quantityText != null;
      final bool wasQuantityCountSet = item.quantityCount != null;
      final bool quantityHasValue =
          finalQText != null || (_quantityCount != null && _quantityCount! > 0);

      final imageSavedOfflineWithoutImage = await ref
          .read(homeViewModelProvider)
          .updateTodo(
            item,
            category,
            selectedCategoryId,
            editNameController.text,
            selectedPriority,
            image: _selectedImage,
            removeImage: false,
            budgetMinAmount: budgetSet ? _budgetMinAmount : null,
            budgetMaxAmount: budgetSet ? _budgetMaxAmount : null,
            budgetType: budgetSet ? _budgetType : null,
            removeBudget: wasBudgetEnabled && !budgetSet,
            quantityText: finalQText,
            quantityUnit: finalQUnit,
            quantityCount: _quantityCount,
            removeQuantity:
                (wasQuantitySet || wasQuantityCountSet) && !quantityHasValue,
          );
      if (!mounted) return;
      showTopSnackBar(
        context,
        '${editNameController.text.trim()}を編集しました',
        familyId: ref.read(selectedFamilyIdProvider),
        saveToHistory: false,
        showCloseButton: true,
      );
      if (imageSavedOfflineWithoutImage && _selectedImage != null) {
        showTopSnackBar(
          context,
          '画像はオフライン中のため保存せず、内容だけ更新しました',
          saveToHistory: false,
        );
      }
      _allowPop = true;
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
      return;
    }

    final finalReading =
        (selectedItemReading != null && selectedItemReading!.isNotEmpty)
        ? selectedItemReading!
        : (_currentInputReading.isNotEmpty
              ? _currentInputReading
              : editNameController.text);

    final result = await ref
        .read(homeViewModelProvider)
        .addTodo(
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
          quantityUnit:
              _selectedQuantityPreset == 'カスタム' &&
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
        saveToHistory: false,
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
    final currentFamilyId = ref.read(selectedFamilyIdProvider);
    showTopSnackBar(
      currentContext,
      result.message
          .replaceAll('「', '')
          .replaceAll('」', '')
          .replaceAll('！', ''),
      familyId: currentFamilyId,
      saveToHistory: currentFamilyId == null || currentFamilyId.isEmpty,
      actionLabel: result.todoItem != null ? '編集する' : null,
      onAction: result.todoItem != null
          ? (snackBarContext) {
              debugPrint(
                'Open TodoEditPage(from add snackbar): todoId=${result.todoItem!.id} itemId=${result.todoItem!.itemId} imageUrl=$_matchedImageUrl',
              );
              Navigator.push(
                snackBarContext,
                MaterialPageRoute(
                  builder: (_) => TodoEditPage(
                    item: result.todoItem!,
                    imageUrl: _matchedImageUrl,
                  ),
                ),
              );
            }
          : null,
    );
    if (result.imageSavedOfflineWithoutImage && _selectedImage != null) {
      showTopSnackBar(
        currentContext,
        '画像はオフライン中のため保存せず、アイテムだけ追加しました',
        saveToHistory: false,
      );
    }

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
    final colors = AppColors.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final categoryLimit = ref.watch(categoryLimitProvider);
    final reachedCategoryLimit =
        categoryLimit != null &&
        (categoryAsync.valueOrNull?.length ?? 0) >= categoryLimit;
    final hasCustomQuantity =
        _selectedQuantityPreset == 'カスタム' &&
        _customQuantityValue.trim().isNotEmpty;
    final hasQuantityContent =
        hasCustomQuantity ||
        (_selectedQuantityPreset != '未指定' &&
            _selectedQuantityPreset != 'カスタム') ||
        (_quantityCount != null && _quantityCount! > 0);
    final showFloatingSuggestions = _nameFocusNode.hasFocus;
    final trimmedName = editNameController.text.trim();
    final hasImage = _selectedImage != null || _matchedImageUrl != null;
    final showExpandedPhotoPreview = hasImage && !_nameFocusNode.hasFocus;
    final bottomSubmitBarInset = widget.showBottomSubmitBar
        ? (_isEditMode ? 132.0 : 76.0) + bottomSafeInset
        : 0.0;
    final externalBottomBarInset = widget.showBottomSubmitBar
        ? bottomSubmitBarInset + (showExpandedPhotoPreview ? 28.0 : 0.0)
        : (keyboardInset > 0 ? 0.0 : (76.0 + bottomSafeInset));
    final showRecentCompletedInsteadOfOptions =
        !_nameFocusNode.hasFocus &&
        trimmedName.isEmpty &&
        !_showOptionsAfterNameCommit &&
        !hasQuantityContent &&
        _budgetMaxAmount <= 0 &&
        selectedCategoryId == null &&
        _selectedImage == null &&
        _matchedImageUrl == null;
    final showOptionSection =
        _showOptionsAfterNameCommit ||
        hasQuantityContent ||
        _budgetMaxAmount > 0 ||
        selectedCategoryId != null ||
        _selectedImage != null ||
        _matchedImageUrl != null;
    final hasUnsavedEdit = _isEditMode && _hasUnsavedChangesInEdit();
    final hasUnsavedAdd = !_isEditMode && _hasUnsavedChangesInAdd();
    final canPopRoute = _allowPop || (!hasUnsavedEdit && !hasUnsavedAdd);

    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _showDiscardEditChangesDialog();
        if (shouldDiscard && mounted) {
          if (!_isEditMode) {
            _container.read(addSheetDiscardOnCloseProvider.notifier).state =
                true;
          }
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 10,
                bottom:
                    keyboardInset +
                    (showFloatingSuggestions ? 72 : 108) +
                    externalBottomBarInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名前入力
                  if (!widget.hideNameField) _buildNameInputArea(),

                  const SizedBox(height: 56),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: showRecentCompletedInsteadOfOptions
                        ? KeyedSubtree(
                            key: const ValueKey('recent-completed-section'),
                            child: _buildRecentCompletedSection(),
                          )
                        : showOptionSection
                        ? KeyedSubtree(
                            key: const ValueKey('option-section'),
                            child: _buildFullScreenOptionSection(
                              categoryAsync: categoryAsync,
                              reachedCategoryLimit: reachedCategoryLimit,
                              hasQuantityContent: hasQuantityContent,
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty-section')),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (showFloatingSuggestions)
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboardInset,
                child: _buildSuggestionStrip(),
              ),
            if (widget.showBottomSubmitBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomActionSheet(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: editNameController,
                    builder: (_, value, __) {
                      final canSubmit = _isEditMode
                          ? value.text.trim().isNotEmpty &&
                              _hasUnsavedChangesInEdit()
                          : value.text.trim().isNotEmpty;
                      if (_isEditMode) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: canSubmit ? _submitAdd : null,
                                child: const Text('保存する'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                variant: AppButtonVariant.filled,
                                tone: AppButtonTone.danger,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.surfaceTertiary,
                                  side: BorderSide.none,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  final shouldDelete =
                                      await showAppConfirmDialog(
                                        context: context,
                                        title: 'アイテムを削除',
                                        message: '削除してよろしいですか？',
                                        confirmLabel: '削除する',
                                        cancelLabel: 'キャンセル',
                                      );
                                  if (shouldDelete != true || !mounted) return;
                                  await ref
                                      .read(homeViewModelProvider)
                                      .deleteTodo(widget.editItem!);
                                  if (!mounted) return;
                                  showTopSnackBar(
                                    context,
                                    '「${widget.editItem!.name}」を削除しました',
                                    familyId: ref.read(selectedFamilyIdProvider),
                                    saveToHistory: false,
                                  );
                                  if (widget.onClose != null) {
                                    widget.onClose!();
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('削除する'),
                              ),
                            ),
                          ],
                        );
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          onPressed: canSubmit ? _submitAdd : null,
                          child: const Text('リストに追加する'),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasUnsavedChangesInEdit() {
    if (!_isEditMode) return false;

    if (editNameController.text.trim() != _initialName) return true;
    if (selectedPriority != _initialPriority) return true;
    if (category.trim() != _initialCategory) return true;
    if (selectedCategoryId != _initialCategoryId) return true;

    if (_selectedImage != null) return true;
    if (_matchedImageUrl != _initialImageUrl) return true;

    if (_budgetMinAmount != _initialBudgetMinAmount) return true;
    if (_budgetMaxAmount != _initialBudgetMaxAmount) return true;
    if (_budgetType != _initialBudgetType) return true;

    if (_selectedQuantityPreset != _initialQuantityPreset) return true;
    if (_customQuantityValue != _initialCustomQuantityValue) return true;
    if (_quantityUnit != _initialQuantityUnit) return true;
    if (_quantityCount != _initialQuantityCount) return true;

    return false;
  }

  bool _hasUnsavedChangesInAdd() {
    if (_isEditMode) return false;

    if (editNameController.text.trim().isNotEmpty) return true;
    if (selectedPriority != 0) return true;
    if (selectedCategoryId != null) return true;
    if (category.trim() != '指定なし') return true;
    if (_selectedImage != null) return true;
    if ((_matchedImageUrl ?? '').isNotEmpty) return true;
    if (_budgetMinAmount != 0 || _budgetMaxAmount != 0 || _budgetType != 0) {
      return true;
    }
    if (_selectedQuantityPreset != '未指定') return true;
    if (_customQuantityValue.trim().isNotEmpty) return true;
    if (_quantityUnit != 0) return true;
    if ((_quantityCount ?? 0) > 0) return true;

    return false;
  }

  Future<bool> _showDiscardEditChangesDialog() async {
    final shouldDiscard = await showDiscardChangesConfirmDialog(
      context: context,
    );
    return shouldDiscard;
  }

  Widget _buildNameInputArea() {
    final colors = AppColors.of(context);
    final hasImage = _selectedImage != null || _matchedImageUrl != null;
    final showExpandedPhotoPreview = hasImage && !_nameFocusNode.hasFocus;
    final suppressClearButton = _showOptionsAfterNameCommit;
    final showInlinePhotoSlot =
        _showOptionsAfterNameCommit && (!hasImage || _nameFocusNode.hasFocus);
    final hasNameText = editNameController.text.trim().isNotEmpty;

    Widget imagePreview() {
      if (_selectedImage != null) {
        return Image.file(File(_selectedImage!.path), fit: BoxFit.cover);
      }
      if (_matchedImageUrl != null) {
        return Image.network(
          _matchedImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }

    Widget nameField() {
      return TextField(
        controller: editNameController,
        focusNode: _nameFocusNode,
        autofocus: widget.autoFocusNameField,
        readOnly: widget.readOnlyNameField,
        showCursor: !widget.readOnlyNameField,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        minLines: 1,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontSize: 40 / 2,
          fontWeight: FontWeight.w500,
          color: colors.textHigh,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          hintText: '買うものを入力…',
          hintStyle: TextStyle(
            fontSize: 40 / 2,
            fontWeight: FontWeight.w500,
            color: colors.textLow,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          suffixIcon: !suppressClearButton && hasNameText
              ? InkWell(
                  onTap: () {
                    editNameController.clear();
                    _nameFocusNode.requestFocus();
                  },
                  child: SizedBox(
                    width: 36,
                    height: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SvgPicture.asset(
                        'assets/icons/clear.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: !suppressClearButton && hasNameText
              ? const BoxConstraints(minWidth: 36, minHeight: 24)
              : null,
        ),
        onTap: () {
          if (widget.readOnlyNameField) return;
          final endOffset = editNameController.text.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            editNameController.selection = TextSelection.fromPosition(
              TextPosition(offset: endOffset),
            );
          });
        },
        onSubmitted: (_) {
          setState(() {
            _showOptionsAfterNameCommit = editNameController.text
                .trim()
                .isNotEmpty;
          });
          FocusScope.of(context).unfocus();
        },
      );
    }

    final nameFieldSection = Expanded(
      child: showExpandedPhotoPreview
          ? nameField()
          : SizedBox(
              height: 200,
              child: nameField(),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: showExpandedPhotoPreview ? 1 : 0,
            child: Align(
              heightFactor: showExpandedPhotoPreview ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: imagePreview(),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            width: 97,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedImage = null;
                                        _matchedImageUrl = null;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.expand(),
                                    icon: const AppActionIcon.trash(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: colors.surfaceTertiary,
                                ),
                                Expanded(
                                  child: IconButton(
                                    onPressed: () =>
                                        _pickImage(ImageSource.camera),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.expand(),
                                    icon: SvgPicture.asset(
                                      'assets/icons/refresh-cw.svg',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            nameFieldSection,
            ClipRect(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: showInlinePhotoSlot ? 1 : 0,
                child: Align(
                  widthFactor: showInlinePhotoSlot ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !showInlinePhotoSlot,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _pickImage(ImageSource.camera),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colors.surfaceHighOnInverse,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.borderLow),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: hasImage
                                  ? imagePreview()
                                  : _InlinePhotoPlaceholder(colors: colors),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _applyItemToForm(
    Item original, {
    required String name,
    required String reading,
  }) {
    _suggestionRequestId++;
    FocusScope.of(context).unfocus();
    _nameFocusNode.unfocus();
    widget.onSuggestionSelected?.call();
    _suppressNameChange = true;
    _lastObservedNameText = name;
    setState(() {
      editNameController.text = name;
      _showOptionsAfterNameCommit = true;
      _preserveMatchedImageFromSelection =
          original.imageUrl != null && original.imageUrl!.isNotEmpty;
      selectedItemReading = reading;
      _suggestions = [];
      category = original.category;
      selectedCategoryId = original.categoryId;
      _matchedImageUrl = original.imageUrl;
      selectedItemReading = reading;
      _currentInputReading = reading;
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
      editNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: editNameController.text.length),
      );
    });
  }

  // 候補タップ時の共通処理
  void _onSuggestionTap(SearchSuggestion item) {
    if (item.original is Item) {
      _applyItemToForm(
        item.original as Item,
        name: item.name,
        reading: item.reading,
      );
      return;
    }

    _suggestionRequestId++;
    FocusScope.of(context).unfocus();
    _nameFocusNode.unfocus();
    widget.onSuggestionSelected?.call();
    _suppressNameChange = true;
    setState(() {
      editNameController.text = item.name;
      _showOptionsAfterNameCommit = true;
      _preserveMatchedImageFromSelection = false;
      selectedItemReading = item.reading;
      _suggestions = [];
      category = "指定なし";
      selectedCategoryId = null;
      _matchedImageUrl = null;
      _clearInheritedOptionValues();
      _prefilledOptionsFromSuggestion = false;
      editNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: editNameController.text.length),
      );
    });
  }

  Widget _buildSuggestionChip(SearchSuggestion suggestion) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isHistory = suggestion.original is Item;

    if (isHistory) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onSuggestionTap(suggestion),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceHighOnInverse,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/history.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  colors.surfaceMedium,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                suggestion.name,
                style: typography.std18R160.copyWith(color: colors.textHigh),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onSuggestionTap(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          child: Text(
            suggestion.name,
            style: typography.std18R160.copyWith(color: colors.textHigh),
          ),
        ),
      ),
    );
  }

  bool _shouldShowSuggestions({required bool isTypingFocus}) {
    return _suggestions.isNotEmpty && isTypingFocus;
  }

  Widget _buildSuggestionStrip() {
    final suggestions = _suggestions.whereType<SearchSuggestion>().toList();
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 74,
      child: ColoredBox(
        color: colors.backgroundGray,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16, right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < suggestions.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == suggestions.length - 1 ? 0 : 8,
                  ),
                  child: _buildSuggestionChip(suggestions[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSelectRecentCompleted(PurchaseWithMaster entry) {
    _applyItemToForm(
      entry.masterItem,
      name: entry.masterItem.name,
      reading: entry.masterItem.reading,
    );
    if (!mounted) return;
    setState(() {
      _selectedImage = null;
      _matchedImageUrl = entry.masterItem.imageUrl;
      _showOptionsAfterNameCommit = true;
      _preserveMatchedImageFromSelection =
          entry.masterItem.imageUrl != null &&
          entry.masterItem.imageUrl!.isNotEmpty;
    });
  }

  Widget _buildRecentCompletedSection() {
    final colors = AppColors.of(context);
    final repository = ref.watch(todoRepositoryProvider);
    final familyId = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
    );
    final billingState = ref.watch(billingControllerProvider);
    final historyRetentionDays = billingState.purchaseHistoryRetentionDays;

    return StreamBuilder<List<PurchaseWithMaster>>(
      stream: repository.watchTopPurchaseHistory(
        familyId,
        retentionDays: historyRetentionDays,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final visibleItems = snapshot.data!.take(6).toList();
        if (visibleItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近の履歴をもとに作成',
              style: AppTypography.of(
                context,
              ).std18Sb160.copyWith(color: colors.textHigh),
            ),
            const SizedBox(height: 16),
            ...visibleItems.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _RecentCompletedHistoryCard(
                  entry: entry,
                  onAdd: () => _handleSelectRecentCompleted(entry),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFullScreenOptionSection({
    required AsyncValue<List<Category>> categoryAsync,
    required bool reachedCategoryLimit,
    required bool hasQuantityContent,
  }) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '条件の重視度',
              style: typography.std12B160.copyWith(color: colors.textHigh),
            ),
            IconButton(
              onPressed: _showPriorityInfoDialog,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: Image.asset(
                'assets/icons/info-green.png',
                width: 20,
                height: 20,
              ),
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
        Row(
          children: [
            Text(
              'カテゴリ',
              style: typography.std12B160.copyWith(color: colors.textHigh),
            ),
            if (reachedCategoryLimit) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    backgroundColor: Colors.white,
                    builder: (sheetContext) {
                      return const CategoryEditSheet(
                        showHeader: true,
                        fullHeight: false,
                      );
                    },
                  );
                },
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const AppActionIcon.pen(size: 16),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            category = index == 0
                                ? '指定なし'
                                : dbCategories[index - 1].name;
                            selectedCategoryId = index == 0
                                ? null
                                : dbCategories[index - 1].id;
                          });
                        },
                        child: Container(
                          height: 35,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color:
                                (index == 0
                                    ? selectedCategoryId == null
                                    : dbCategories[index - 1].id ==
                                          selectedCategoryId)
                                ? colors.highlightedOutlineButton
                                : colors.surfaceTertiary,
                            border:
                                (index == 0
                                    ? selectedCategoryId == null
                                    : dbCategories[index - 1].id ==
                                          selectedCategoryId)
                                ? Border.all(
                                    color: colors.accentPrimary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Text(
                            index == 0 ? '指定なし' : dbCategories[index - 1].name,
                            style: typography.std12B160.copyWith(
                              color:
                                  (index == 0
                                      ? selectedCategoryId == null
                                      : dbCategories[index - 1].id ==
                                            selectedCategoryId)
                                  ? colors.textAccentPrimary
                                  : colors.textMedium,
                            ),
                          ),
                        ),
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '希望の条件',
            style: typography.std12B160.copyWith(color: colors.textHigh),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSettingActionChip(
                index: 3,
                label: '写真で伝える',
                iconAsset: 'assets/icons/image-plus.png',
                activeIconAsset: 'assets/icons/image-plus-green.png',
                hasContent: _selectedImage != null || _matchedImageUrl != null,
                onTap: () {
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(width: 8),
              _buildSettingActionChip(
                index: 1,
                label: 'ほしい量',
                iconAsset: 'assets/icons/bag.svg',
                activeIconAsset: 'assets/icons/bag-green.png',
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
                label: '予算',
                iconAsset: 'assets/icons/money.png',
                activeIconAsset: 'assets/icons/money-green.png',
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
          ),
        if (_activeConditionTab == 2)
          BudgetSection(
            minAmount: _budgetMinAmount,
            maxAmount: _budgetMaxAmount,
            type: _budgetType,
            onRangeChanged: (range) => setState(() {
              final normalized = _normalizeBudgetRange(
                min: range.min,
                max: range.max,
              );
              _prefilledOptionsFromSuggestion = false;
              _budgetMinAmount = normalized.min;
              _budgetMaxAmount = normalized.max;
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
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
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
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);

    // フルスクリーンモードの場合は縦積みレイアウトを使用
    if (widget.isFullScreen) {
      return _buildFullScreenLayout(categoryAsync);
    }

    final selectedCategoryValueLabel = _selectedCategoryValueLabel(
      categoryAsync.valueOrNull,
    );

    // 以下はモーダル用のレイアウト
    final showOptionsWhileEditing =
        !widget.hideOptionsWhileTyping || widget.hideNameField;
    final isTypingOnlyMode =
        widget.hideOptionsWhileTyping && !showOptionsWhileEditing;
    final isTypingFocus = widget.hideNameField
        ? widget.hideOptionsWhileTyping
        : _nameFocusNode.hasFocus;
    final hasSuggestions = _suggestions.isNotEmpty;
    final showTypingSuggestions = isTypingOnlyMode
        ? hasSuggestions
        : _shouldShowSuggestions(isTypingFocus: isTypingFocus);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final showDetailPanel = _activeConditionTab != null;
    final showCompactSuggestionBar =
        widget.hideNameField && hasSuggestions && !showDetailPanel;

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
    const compactSuggestionRowHeight = 74.0;
    final compactOptionsLift = widget.hideNameField && showOptionsWhileEditing
        ? 250.0
        : 0.0;
    final liftedKeyboardHeight = (resolvedKeyboardHeight + compactOptionsLift)
        .clamp(0.0, MediaQuery.sizeOf(context).height * 0.68);
    final detailPanelHeight = liftedKeyboardHeight;
    final suggestionHeight = showCompactSuggestionBar
        ? compactSuggestionRowHeight
        : 0.0;
    final compactKeyboardSpacer = showCompactSuggestionBar
        ? keyboardHeight
        : 0.0;
    final panelHeight = widget.hideNameField
        ? (isTypingOnlyMode
              ? (showCompactSuggestionBar
                    ? suggestionHeight + compactKeyboardSpacer
                    : 0.0)
              : liftedKeyboardHeight)
        : resolvedKeyboardHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: panelHeight,
      decoration: widget.hideNameField && showOptionsWhileEditing
          ? BoxDecoration(
              color: AppColors.of(context).surfaceHighOnInverse,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            AppPageHeader(
              title: 'アイテムを追加',
              onBack: widget.onClose ?? () => Navigator.pop(context),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.opaque,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom:
                          (isTypingOnlyMode
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
                            keepActiveBorder: true,
                          ),

                        if (showOptionsWhileEditing) ...[
                          const SizedBox(height: 8),

                          Center(
                            child: Text(
                              '条件の重視度',
                              textAlign: TextAlign.center,
                              style: AppTypography.of(context).std11M160
                                  .copyWith(
                                    color: AppColors.of(context).textLow,
                                  ),
                            ),
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
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.of(context).borderDivider,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildSettingActionChip(
                                          index: 0,
                                          iconAsset: 'assets/icons/folder.svg',
                                          label: 'カテゴリ',
                                          hasContent:
                                              selectedCategoryId != null,
                                          valueLabel:
                                              selectedCategoryValueLabel,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSettingActionChip(
                                          index: 3,
                                          label: '写真で伝える',
                                          iconAsset:
                                              'assets/icons/image-plus.png',
                                          activeIconAsset:
                                              'assets/icons/image-plus-green.png',
                                          hasContent:
                                              _selectedImage != null ||
                                              _matchedImageUrl != null,
                                          onTap: () {
                                            _pickImage(ImageSource.camera);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSettingActionChip(
                                          index: 1,
                                          label: 'ほしい量',
                                          iconAsset: 'assets/icons/bag.svg',
                                          activeIconAsset:
                                              'assets/icons/bag-green.png',
                                          hasContent:
                                              _selectedQuantityPreset !=
                                                  '未指定' ||
                                              (_quantityCount != null &&
                                                  _quantityCount! > 0),
                                          onTap: _showQuantityEditorModal,
                                          valueLabel: _quantityChipValueLabel(
                                            preset: _selectedQuantityPreset,
                                            customValue: _customQuantityValue,
                                            unit: _quantityUnit,
                                            count: _quantityCount,
                                          ),
                                          onClear: () {
                                            setState(() {
                                              _prefilledOptionsFromSuggestion =
                                                  false;
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
                                          label: '予算',
                                          iconAsset: 'assets/icons/money.png',
                                          activeIconAsset:
                                              'assets/icons/money-green.png',
                                          hasContent: _budgetMaxAmount > 0,
                                          onTap: _showBudgetEditorModal,
                                          valueLabel: _budgetChipValueLabel(
                                            minAmount: _budgetMinAmount,
                                            maxAmount: _budgetMaxAmount,
                                            type: _budgetType,
                                          ),
                                          onClear: () {
                                            setState(() {
                                              _prefilledOptionsFromSuggestion =
                                                  false;
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
                                  final canSubmit = value.text
                                      .trim()
                                      .isNotEmpty;
                                  return AppButton(
                                    size: AppButtonSize.sm,
                                    onPressed: canSubmit ? _submitAdd : null,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 42),
                                      fixedSize: const Size.fromHeight(42),
                                    ),
                                    child: _isEditMode
                                        ? const Text('保存')
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/icons/plus.svg',
                                                width: 20,
                                                height: 20,
                                                colorFilter: ColorFilter.mode(
                                                  AppColors.of(
                                                    context,
                                                  ).textHighOnInverse,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '追加',
                                                style: AppTypography.of(context)
                                                    .jaOnl14B100
                                                    .copyWith(
                                                      color: AppColors.of(
                                                        context,
                                                      ).textHighOnInverse,
                                                    ),
                                              ),
                                            ],
                                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: _buildActiveTabContent(categoryAsync),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                if (showTypingSuggestions)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: showCompactSuggestionBar
                        ? compactKeyboardSpacer
                        : 0,
                    child: _buildSuggestionStrip(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePhotoPlaceholder extends StatelessWidget {
  const _InlinePhotoPlaceholder({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/icons/image-plus.png',
        width: 24,
        height: 24,
        color: colors.surfacePrimary,
      ),
    );
  }
}

class _RecentCompletedHistoryCard extends StatelessWidget {
  const _RecentCompletedHistoryCard({required this.entry, required this.onAdd});

  final PurchaseWithMaster entry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final hasImage =
        entry.masterItem.imageUrl != null &&
        entry.masterItem.imageUrl!.isNotEmpty;
    final quantityLine = _buildRecentCompletedQuantityLine(entry.masterItem);
    final budgetLine = _buildRecentCompletedBudgetLine(entry.masterItem);
    final countLabel = _buildRecentCompletedCountLabel(entry.masterItem);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onAdd,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: colors.backgroundGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEDF1F7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Text(
                          entry.masterItem.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.jaOnl14Sb100.copyWith(
                            color: colors.textHigh,
                          ),
                        ),
                      ),
                      if (countLabel != null)
                        Text(
                          countLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: colors.textHigh,
                          ),
                        ),
                    ],
                  ),
                  if (quantityLine != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/bag.svg',
                            width: 14,
                            height: 14,
                            colorFilter: ColorFilter.mode(
                              colors.textLow,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              quantityLine,
                              style: typography.jaOnl12M120.copyWith(
                                color: colors.textLow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (budgetLine != null) ...[
                    if (quantityLine == null) const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        budgetLine,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: colors.textLow,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.topRight,
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
              ),
          ],
        ),
      ),
    );
  }
}

String? _buildRecentCompletedQuantityLine(Item item) {
  if (item.quantityText == null || item.quantityText!.isEmpty) return null;
  final unit = _recentCompletedQuantityUnitLabel(item.quantityUnit);
  return '${item.quantityText}$unit';
}

String? _buildRecentCompletedBudgetLine(Item item) {
  const upperNoneThreshold = 2050;
  final minAmount = item.budgetMinAmount ?? 0;
  final maxAmount = item.budgetMaxAmount;
  if (maxAmount == null || maxAmount <= 0) return null;
  final unit = item.budgetType == 1 ? '100g' : '1つ';
  if (maxAmount >= upperNoneThreshold) {
    return minAmount <= 0 ? null : '$minAmount円以上 / $unit';
  }
  if (minAmount <= 0) return '$maxAmount円以下 / $unit';
  if (minAmount >= maxAmount) return '$minAmount円以上 / $unit';
  return '$minAmount〜$maxAmount円 / $unit';
}

String? _buildRecentCompletedCountLabel(Item item) {
  final count = item.quantityCount;
  if (count == null || count <= 1) return null;
  return '×$count';
}

String _recentCompletedQuantityUnitLabel(int? unit) {
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
