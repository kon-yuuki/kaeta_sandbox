import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import 'budget_section.dart';
import 'quantity_section.dart';
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
  int _budgetAmount = 0;
  int _budgetType = 0;
  String _selectedQuantityPreset = '未指定';
  String _customQuantityValue = '';
  int _quantityUnit = 0;

  @override
  void initState() {
    super.initState();
    editNameController = TextEditingController(text: widget.item.name);
    scrollController = ScrollController();
    selectedCategoryId = widget.item.categoryId;
    selectedPriority = widget.item.priority;
    _currentImageUrl = widget.imageUrl;
    _budgetAmount = widget.item.budgetAmount ?? 0;
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
  }

  @override
  void dispose() {
    editNameController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Widget _buildConditionTab(int index, IconData icon, String label) {
    final isSelected = _activeConditionTab == index;
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) {
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
    return SingleChildScrollView(
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
                    selectedCategoryValue = 0;
                    category = "指定なし";
                  } else {
                    final index = dbCategories.indexWhere((c) => c.id == selectedCategoryId);
                    selectedCategoryValue = index != -1 ? index + 1 : 0;
                    if (index != -1) {
                        category = dbCategories[index].name;
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildConditionTab(0, Icons.camera_alt, '写真で伝える'),
                _buildConditionTab(1, Icons.straighten, 'ほしい量'),
                _buildConditionTab(2, Icons.payments, '予算'),
              ],
            ),
            const SizedBox(height: 8),
            if (_activeConditionTab == 0) ...[
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
              ),
            if (_activeConditionTab == 2)
              BudgetSection(
                amount: _budgetAmount,
                type: _budgetType,
                onAmountChanged: (value) => setState(() => _budgetAmount = value),
                onTypeChanged: (value) => setState(() => _budgetType = value),
              ),
            ElevatedButton(
              onPressed: () async {
                final bool wasBudgetEnabled = (widget.item.budgetAmount ?? 0) > 0;
                final bool wasQuantitySet = widget.item.quantityText != null;
                final String? finalQText = _selectedQuantityPreset == 'カスタム'
                    ? (_customQuantityValue.isNotEmpty ? _customQuantityValue : null)
                    : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null);
                final int? finalQUnit = _selectedQuantityPreset == 'カスタム' && _customQuantityValue.isNotEmpty
                    ? _quantityUnit
                    : null;
                final bool budgetSet = _budgetAmount > 0;
                await ref
                    .read(homeViewModelProvider)
                    .updateTodo(
                      widget.item,
                      category,
                      selectedCategoryId,
                      editNameController.text,
                      selectedPriority,
                      image: _selectedImage,
                      removeImage: _imageRemoved && _selectedImage == null,
                      budgetAmount: budgetSet ? _budgetAmount : null,
                      budgetType: budgetSet ? _budgetType : null,
                      removeBudget: wasBudgetEnabled && !budgetSet,
                      quantityText: finalQText,
                      quantityUnit: finalQUnit,
                      removeQuantity: wasQuantitySet && finalQText == null,
                    );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
        ],
      ),
    );
  }
}
