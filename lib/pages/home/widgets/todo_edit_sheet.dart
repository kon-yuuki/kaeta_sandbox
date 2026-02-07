import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import 'budget_section.dart';
import 'quantity_section.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

class TodoEditSheet extends ConsumerStatefulWidget {
  final TodoItem item;
  final String? imageUrl;
  const TodoEditSheet({super.key, required this.item, this.imageUrl});

  @override
  ConsumerState<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends ConsumerState<TodoEditSheet> {
  late TextEditingController editNameController;
  late ScrollController scrollController;
  late int selectedPriority;
  int selectedCategoryValue = 0;
  String category = "指定なし";
  String? selectedCategoryId;
  bool _hasScrolled = false;
  final GlobalKey selectedCategoryKey = GlobalKey();
  XFile? _selectedImage;
  late String? _currentImageUrl;
  bool _imageRemoved = false;
  int? _activeConditionTab; // 0=写真, 1=ほしい量, 2=予算
  int _budgetMinAmount = 0;
  int _budgetMaxAmount = 0;
  int _budgetType = 0;
  String _selectedQuantityPreset = '未指定';
  String _customQuantityValue = '';
  int _quantityUnit = 0;
  int? _quantityCount;
  bool _allowPop = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    editNameController = TextEditingController(text: widget.item.name);
    editNameController.addListener(_onNameChanged);
    scrollController = ScrollController();
    final initialCategoryId = widget.item.categoryId?.trim();
    selectedCategoryId = (initialCategoryId == null || initialCategoryId.isEmpty)
        ? null
        : initialCategoryId;
    final initialCategoryName = widget.item.category.trim();
    category = initialCategoryName.isEmpty ? "指定なし" : initialCategoryName;
    selectedPriority = widget.item.priority;
    _currentImageUrl = widget.imageUrl;
    _budgetMinAmount = widget.item.budgetMinAmount ?? 0;
    _budgetMaxAmount = widget.item.budgetMaxAmount ?? 0;
    _budgetType = widget.item.budgetType ?? 0;
    final qText = widget.item.quantityText;
    final qUnit = widget.item.quantityUnit;
    if (qText != null && qUnit != null) {
      _selectedQuantityPreset = 'カスタム';
      _customQuantityValue = qText;
      _quantityUnit = qUnit;
    } else if (qText != null) {
      _selectedQuantityPreset = qText;
    }
    _quantityCount = widget.item.quantityCount;
  }

  @override
  void dispose() {
    editNameController.removeListener(_onNameChanged);
    editNameController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!mounted) return;
    // PopScope の canPop 判定を最新化するために再ビルドする
    setState(() {});
  }

  String? _normalizeCategoryId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _hasUnsavedChanges() {
    final currentName = editNameController.text.trim();
    final initialName = widget.item.name.trim();
    if (currentName != initialName) return true;

    if (selectedPriority != widget.item.priority) return true;

    final currentCategoryId = _normalizeCategoryId(selectedCategoryId);
    final initialCategoryId = _normalizeCategoryId(widget.item.categoryId);
    if (currentCategoryId != initialCategoryId) return true;
    if (currentCategoryId == null &&
        category.trim() != widget.item.category.trim()) {
      return true;
    }

    final currentBudgetMinAmount = _budgetMinAmount;
    final currentBudgetMaxAmount = _budgetMaxAmount;
    final currentBudgetType = _budgetType;
    final initialBudgetMinAmount = widget.item.budgetMinAmount ?? 0;
    final initialBudgetMaxAmount = widget.item.budgetMaxAmount ?? 0;
    final initialBudgetType = widget.item.budgetType ?? 0;
    if (currentBudgetMinAmount != initialBudgetMinAmount ||
        currentBudgetMaxAmount != initialBudgetMaxAmount ||
        currentBudgetType != initialBudgetType) {
      return true;
    }

    final String? currentQText = _selectedQuantityPreset == 'カスタム'
        ? (_customQuantityValue.isNotEmpty ? _customQuantityValue : null)
        : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null);
    final int? currentQUnit =
        _selectedQuantityPreset == 'カスタム' && _customQuantityValue.isNotEmpty
            ? _quantityUnit
            : null;
    if (currentQText != widget.item.quantityText) return true;
    if (currentQUnit != widget.item.quantityUnit) return true;
    if (_quantityCount != widget.item.quantityCount) return true;

    if (_selectedImage != null || _imageRemoved) return true;

    return false;
  }

  Widget _buildSettingActionChip({
    required int index,
    required IconData icon,
    required String label,
    bool hasContent = false,
  }) {
    final appColors = AppColors.of(context);
    final isSelected = _activeConditionTab == index;

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

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );

    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '切り抜き',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '切り抜き',
          aspectRatioLockEnabled: true,
          resetButtonHidden: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedImage = XFile(croppedFile.path);
        _imageRemoved = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);
    final hasCategoryContent =
        (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) ||
        category != '指定なし';
    final hasCustomQuantity = _selectedQuantityPreset == 'カスタム' &&
        _customQuantityValue.trim().isNotEmpty;
    final hasQuantityContent = hasCustomQuantity ||
        (_selectedQuantityPreset != '未指定' &&
            _selectedQuantityPreset != 'カスタム') ||
        (_quantityCount != null && _quantityCount! > 0);
    final canPopRoute = _allowPop || _isSaving || !_hasUnsavedChanges();
    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || canPopRoute) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('入力を破棄しますか？'),
            content: const Text('編集内容は保存されません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(labelText: '名前を編集'),
              autofocus: true,
            ),

            const SizedBox(height: 20),

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
            const SizedBox(height: 16),
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
                          hasContent: hasCategoryContent,
                        ),
                        const SizedBox(width: 8),
                        _buildSettingActionChip(
                          index: 1,
                          icon: Icons.straighten,
                          label: 'ほしい量',
                          hasContent: hasQuantityContent,
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
                          hasContent: _selectedImage != null ||
                              (!_imageRemoved &&
                                  _currentImageUrl != null &&
                                  _currentImageUrl!.isNotEmpty),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: editNameController,
                  builder: (_, value, __) {
                    final canSave = value.text.trim().isNotEmpty;
                    return FilledButton(
                      onPressed: canSave
                          ? () async {
                              setState(() => _isSaving = true);
                              final bool wasBudgetEnabled =
                                  (widget.item.budgetMaxAmount ?? 0) > 0;
                              final bool wasQuantitySet =
                                  widget.item.quantityText != null;
                              final String? finalQText =
                                  _selectedQuantityPreset == 'カスタム'
                                      ? (_customQuantityValue.isNotEmpty
                                          ? _customQuantityValue
                                          : null)
                                      : (_selectedQuantityPreset != '未指定'
                                          ? _selectedQuantityPreset
                                          : null);
                              final int? finalQUnit = _selectedQuantityPreset == 'カスタム' &&
                                      _customQuantityValue.isNotEmpty
                                  ? _quantityUnit
                                  : null;
                              final bool budgetSet = _budgetMaxAmount > 0;
                              final bool wasQuantityCountSet =
                                  widget.item.quantityCount != null;
                              final bool quantityHasValue = finalQText != null ||
                                  (_quantityCount != null && _quantityCount! > 0);
                              try {
                                await ref.read(homeViewModelProvider).updateTodo(
                                      widget.item,
                                      category,
                                      selectedCategoryId,
                                      editNameController.text,
                                      selectedPriority,
                                      image: _selectedImage,
                                      removeImage:
                                          _imageRemoved && _selectedImage == null,
                                      budgetMinAmount:
                                          budgetSet ? _budgetMinAmount : null,
                                      budgetMaxAmount:
                                          budgetSet ? _budgetMaxAmount : null,
                                      budgetType: budgetSet ? _budgetType : null,
                                      removeBudget:
                                          wasBudgetEnabled && !budgetSet,
                                      quantityText: finalQText,
                                      quantityUnit: finalQUnit,
                                      quantityCount: _quantityCount,
                                      removeQuantity:
                                          (wasQuantitySet || wasQuantityCountSet) &&
                                              !quantityHasValue,
                                    );
                                if (mounted) {
                                  setState(() => _allowPop = true);
                                  Navigator.pop(context);
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isSaving = false);
                                }
                              }
                            }
                          : null,
                      child: const Text('保存'),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_activeConditionTab == 0) ...[
              Row(
                children: [
                  Text('カテゴリ'),
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        isScrollControlled: true,
                        showDragHandle: true,
                        context: context,
                        builder: (context) => const CategoryEditSheet(),
                      );
                    },
                    icon: Icon(Icons.edit),
                  ),
                ],
              ),
              categoryAsync.when(
                data: (dbCategories) {
                  if (selectedCategoryId == null) {
                    final byNameIndex =
                        category == '指定なし'
                            ? -1
                            : dbCategories.indexWhere((c) => c.name == category);
                    if (byNameIndex != -1) {
                      selectedCategoryValue = byNameIndex + 1;
                      selectedCategoryId = dbCategories[byNameIndex].id;
                      category = dbCategories[byNameIndex].name;
                    } else {
                      selectedCategoryValue = 0;
                      if (category.trim().isEmpty) {
                        category = "指定なし";
                      }
                    }
                  } else {
                    final index =
                        dbCategories.indexWhere((c) => c.id == selectedCategoryId);
                    selectedCategoryValue = index != -1 ? index + 1 : 0;
                    if (index != -1) {
                      category = dbCategories[index].name;
                    } else if (category.trim().isEmpty) {
                      category = "指定なし";
                    }
                  }

                    if (!_hasScrolled) {
                      _hasScrolled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final chipContext = selectedCategoryKey.currentContext;
                        if (chipContext != null) {
                          Scrollable.ensureVisible(
                            chipContext,
                            alignment: 0.5,
                            duration: const Duration(milliseconds: 300),
                          );
  }
                      });
                    }

                  return SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dbCategories.length + 1,
                      controller: scrollController,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: Text(
                              index == 0 ? "指定なし" : dbCategories[index - 1].name,
                            ),
                            selected: selectedCategoryValue == index,
                            onSelected: (bool selected) {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                selectedCategoryValue = index;
                                category = index == 0
                                    ? "指定なし"
                                    : dbCategories[index - 1].name;
                                selectedCategoryId = index == 0
                                    ? null
                                    : dbCategories[index - 1].id;
                              });
                            },
                            key:index == selectedCategoryValue ? selectedCategoryKey : null,
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
            if (_activeConditionTab == 3) ...[
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
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _imageRemoved = true;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white70,
                      ),
                    ),
                  ],
                )
              else if (!_imageRemoved && _currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    SizedBox(
                      height: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentImageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _imageRemoved = true;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white70,
                      ),
                    ),
                  ],
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
            if (_activeConditionTab == 1)
              QuantitySection(
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
              ),
            if (_activeConditionTab == 2)
              BudgetSection(
                minAmount: _budgetMinAmount,
                maxAmount: _budgetMaxAmount,
                type: _budgetType,
                onRangeChanged: (range) => setState(() {
                  _budgetMinAmount = range.min;
                  _budgetMaxAmount = range.max;
                }),
                onTypeChanged: (value) => setState(() => _budgetType = value),
              ),
          ],
        ),
      ),
    );
  }
}
