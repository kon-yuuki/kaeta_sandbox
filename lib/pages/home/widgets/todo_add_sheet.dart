import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import '../view/todo_edit_page.dart';
import 'budget_section.dart';
import 'quantity_section.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/constants.dart';
import '../../../data/model/database.dart';
import '../../../data/repositories/items_repository.dart';

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

  @override
  ConsumerState<TodoAddSheet> createState() => _TodoAddSheetState();
}

class _TodoAddSheetState extends ConsumerState<TodoAddSheet> {
  late TextEditingController editNameController;
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
    selectedPriority = _container.read(addSheetDraftPriorityProvider);
    selectedCategoryId = _container.read(addSheetDraftCategoryIdProvider);
    category = _container.read(addSheetDraftCategoryNameProvider);
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
    _handleNameChanged(editNameController.text);
  }

  Future<void> _handleNameChanged(String value) async {
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

    final matchedItem = await ref
        .read(homeViewModelProvider)
        .searchItemByReading(value);

    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      if (matchedItem != null) {
        category = matchedItem.category;
        selectedCategoryId = matchedItem.categoryId;
        _matchedImageUrl = matchedItem.imageUrl;
        selectedItemReading = matchedItem.reading;
      } else {
        _matchedImageUrl = null;
        selectedItemReading = null;
      }
    });
  }

  Widget _buildSettingActionChip({
    required int index,
    required IconData icon,
    required String label,
    bool hasContent = false,
  }) {
    final appColors = AppColors.of(context);
    final isSelected = _activeConditionTab == index;

    // 色の決定: 選択中 > 入力あり > デフォルト
    final Color backgroundColor;
    final Color borderColor;
    final Color contentColor;

    if (isSelected) {
      backgroundColor = Colors.blueAccent;
      borderColor = Colors.blueAccent;
      contentColor = Colors.white;
    } else if (hasContent) {
      backgroundColor = appColors.accentPrimaryLight;
      borderColor = appColors.accentPrimary;
      contentColor = appColors.textAccentPrimary;
    } else {
      backgroundColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      contentColor = Colors.black87;
    }

    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: contentColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: contentColor,
        ),
      ),
      backgroundColor: backgroundColor,
      side: BorderSide(color: borderColor),
      onPressed: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _activeConditionTab = isSelected ? null : index;
        });
      },
    );
  }

  Widget _buildActiveTabContent(AsyncValue<List<Category>> categoryAsync) {
    if (_activeConditionTab == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('カテゴリ'),
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    isScrollControlled: true,
                    showDragHandle: true,
                    context: context,
                    builder: (context) => const CategoryEditSheet(),
                  );
                },
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
          categoryAsync.when(
            data: (dbCategories) {
              return SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dbCategories.length + 1,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ChoiceChip(
                        label: Text(
                          index == 0 ? "指定なし" : dbCategories[index - 1].name,
                        ),
                        selected: index == 0
                            ? selectedCategoryId == null
                            : dbCategories[index - 1].id == selectedCategoryId,
                        onSelected: (bool selected) {
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
                    );
                  },
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
            _selectedQuantityPreset = preset;
            if (preset == '未指定') {
              _customQuantityValue = '';
            }
          });
        },
        onCustomValueChanged: (value) => setState(() => _customQuantityValue = value),
        onUnitChanged: (value) => setState(() => _quantityUnit = value),
        onQuantityCountChanged: (value) => setState(() => _quantityCount = value),
      );
    }

    if (_activeConditionTab == 2) {
      return BudgetSection(
        minAmount: _budgetMinAmount,
        maxAmount: _budgetMaxAmount,
        type: _budgetType,
        onRangeChanged: (range) => setState(() {
          _budgetMinAmount = range.min;
          _budgetMaxAmount = range.max;
        }),
        onTypeChanged: (value) => setState(() => _budgetType = value),
      );
    }

    if (_activeConditionTab == 3) {
      return Column(
        children: [
          if (_selectedImage != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.cover,
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
            SizedBox(
              height: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _matchedImageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('カメラで撮影'),
              ),
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('写真から選択'),
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
      showTopSnackBar(context, '追加に失敗しました。設定を確認してください');
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

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final showDetailPanel = _activeConditionTab != null;

    // 入力中(タブ未選択)はキーボード高さを取り込み、タブ選択後は固定値として使う
    if (!showDetailPanel && keyboardHeight > 0) {
      if (keyboardHeight > _lastKeyboardHeight) {
        _lastKeyboardHeight = keyboardHeight;
      }
    }

    const compactHeight = 152.0;
    final reservedKeyboardHeight = _lastKeyboardHeight > 0
        ? _lastKeyboardHeight
        : (keyboardHeight > 0 ? keyboardHeight : 220.0);
    final detailPanelHeight = reservedKeyboardHeight;
    final shouldReserveDetailSpace =
        showDetailPanel || keyboardHeight > 0 || widget.keepKeyboardSpace;
    final panelHeight = widget.isFullScreen
        ? double.infinity
        : (shouldReserveDetailSpace
            ? (compactHeight + detailPanelHeight)
            : compactHeight);
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
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: (widget.includeKeyboardInsetInBody
                        ? MediaQuery.of(context).viewInsets.bottom
                        : 0) +
                    (showDetailPanel ? 12 : 0),
              ),
              child: Column(
                children: [
                  if (!widget.hideNameField)
                    TextField(
                      controller: editNameController,
                      decoration: const InputDecoration(labelText: '買うものをを入力…'),
                      autofocus: !widget.readOnlyNameField,
                      readOnly: widget.readOnlyNameField,
                      showCursor: !widget.readOnlyNameField,
                    ),

                  if (_suggestions.isNotEmpty)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final item = _suggestions[index] as SearchSuggestion;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 8.0,
                            ),
                            child: ActionChip(
                              avatar: item.imageUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.history, size: 16),
                              label: Text(item.name),
                              onPressed: () {
                                setState(() {
                                  editNameController.text = item.name;
                                  selectedItemReading = item.reading;
                                  _suggestions = [];
                                  _suggestions = [];
                                  if (item.original is Item) {
                                    final original = item.original as Item;
                                    category = original.category;
                                    selectedCategoryId = original.categoryId;
                                    _matchedImageUrl = original.imageUrl;
                                    selectedItemReading = item.reading;
                                    _currentInputReading = item.reading;
                                    final originalBudgetMax =
                                        original.budgetMaxAmount;
                                    if (originalBudgetMax != null && originalBudgetMax > 0) {
                                      _budgetMinAmount =
                                          original.budgetMinAmount ?? 0;
                                      _budgetMaxAmount = originalBudgetMax;
                                      _budgetType = original.budgetType ?? 0;
                                    }
                                    if (original.quantityText != null) {
                                      if (original.quantityUnit != null) {
                                        _selectedQuantityPreset = 'カスタム';
                                        _customQuantityValue = original.quantityText!;
                                        _quantityUnit = original.quantityUnit!;
                                      } else {
                                        _selectedQuantityPreset = original.quantityText!;
                                      }
                                    }
                                  } else {
                                    // マスタデータ（MasterItem）の場合は初期状態に
                                    category = "指定なし";
                                    selectedCategoryId = null;
                                    _matchedImageUrl = null;
                                  }
                                  editNameController
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: editNameController.text.length,
                                    ),
                                  );
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  Text('条件の重要度', style: TextStyle(fontSize: 12)),
                  SegmentedButton<int>(
                    segments: prioritySegments,
                    selected: {selectedPriority},
                    onSelectionChanged: (newSelection) {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        selectedPriority = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSettingActionChip(
                                index: 0,
                                icon: Icons.category,
                                label: 'カテゴリ: $category',
                                hasContent: selectedCategoryId != null,
                              ),
                              const SizedBox(width: 8),
                              _buildSettingActionChip(
                                index: 1,
                                icon: Icons.straighten,
                                label: 'ほしい量',
                                hasContent: _selectedQuantityPreset != '未指定' || (_quantityCount != null && _quantityCount! > 0),
                              ),
                              const SizedBox(width: 8),
                              _buildSettingActionChip(
                                index: 2,
                                icon: Icons.payments,
                                label: '予算',
                                hasContent: _budgetMaxAmount > 0,
                              ),
                              const SizedBox(width: 8),
                              _buildSettingActionChip(
                                index: 3,
                                icon: Icons.camera_alt,
                                label: '写真で伝える',
                                hasContent: _selectedImage != null || _matchedImageUrl != null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: editNameController,
                        builder: (_, value, __) {
                          final canSubmit = value.text.trim().isNotEmpty;
                          return FilledButton(
                            onPressed: canSubmit ? _submitAdd : null,
                            child: const Text('追加'),
                          );
                        },
                      ),
                    ],
                  ),
                  if (showDetailPanel) ...[
                    const SizedBox(height: 8),
                    if (widget.isFullScreen)
                      // フルスクリーンモードでは固定高さを使わず、コンテンツを自然に展開
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: _buildActiveTabContent(categoryAsync),
                      )
                    else
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
