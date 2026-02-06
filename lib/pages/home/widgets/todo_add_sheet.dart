import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import 'todo_edit_sheet.dart';
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
  const TodoAddSheet({super.key});

  @override
  ConsumerState<TodoAddSheet> createState() => _TodoAddSheetState();
}

class _TodoAddSheetState extends ConsumerState<TodoAddSheet> {
  late TextEditingController editNameController;
  int selectedPriority = 0;
  String category = "指定なし";
  String? selectedCategoryId;
  XFile? _selectedImage;
  String? _matchedImageUrl;
  String? selectedItemReading;
  List<dynamic> _suggestions = [];
  String _currentInputReading = "";
  int? _activeConditionTab; // 0=写真, 1=ほしい量, 2=予算
  int _budgetAmount = 0;
  int _budgetType = 0;
  String _selectedQuantityPreset = '未指定';
  String _customQuantityValue = '';
  int _quantityUnit = 0;

  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    // initState時にcontainerへの参照を保存（dispose時にcontextが使えないため）
    _container = ProviderScope.containerOf(context, listen: false);
    // Providerからドラフトを復元
    final draftName = _container.read(addSheetDraftNameProvider);
    editNameController = TextEditingController(text: draftName);
    selectedPriority = _container.read(addSheetDraftPriorityProvider);
    selectedCategoryId = _container.read(addSheetDraftCategoryIdProvider);
    category = _container.read(addSheetDraftCategoryNameProvider);
    _budgetAmount = _container.read(addSheetDraftBudgetAmountProvider);
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
  }

  @override
  void dispose() {
    // dispose時の値をキャプチャしてからコントローラーを破棄
    final draftName = editNameController.text;
    final draftPriority = selectedPriority;
    final draftCategoryId = selectedCategoryId;
    final draftCategoryName = category;
    final draftBudgetAmount = _budgetAmount;
    final draftBudgetType = _budgetType;
    final draftQText = _selectedQuantityPreset == 'カスタム'
        ? _customQuantityValue
        : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null);
    final draftQUnit = _selectedQuantityPreset == 'カスタム' ? _quantityUnit : null;
    editNameController.dispose();
    // ビルドフェーズ終了後にProviderを更新（ビルド中のstate変更を回避）
    Future.microtask(() {
      _container.read(addSheetDraftNameProvider.notifier).state = draftName;
      _container.read(addSheetDraftPriorityProvider.notifier).state = draftPriority;
      _container.read(addSheetDraftCategoryIdProvider.notifier).state = draftCategoryId;
      _container.read(addSheetDraftCategoryNameProvider.notifier).state = draftCategoryName;
      _container.read(addSheetDraftBudgetAmountProvider.notifier).state = draftBudgetAmount;
      _container.read(addSheetDraftBudgetTypeProvider.notifier).state = draftBudgetType;
      _container.read(addSheetDraftQuantityTextProvider.notifier).state = draftQText;
      _container.read(addSheetDraftQuantityUnitProvider.notifier).state = draftQUnit;
    });
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

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryListProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: editNameController,
                    decoration: const InputDecoration(labelText: '買うものをを入力…'),
                    autofocus: true,
                    onChanged: (value) async {
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

                      final matchedItem = await ref
                          .read(homeViewModelProvider)
                          .searchItemByReading(value);

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
                    },
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
                                    if (original.budgetAmount != null && original.budgetAmount! > 0) {
                                      _budgetAmount = original.budgetAmount!;
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

                  const SizedBox(height: 20),

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
                      return SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dbCategories.length + 1,
                          itemBuilder: (BuildContext context, int index) {
                            return Padding(
                              padding: EdgeInsets.all(4.0),
                              child: ChoiceChip(
                                label: Text(
                                  index == 0
                                      ? "指定なし"
                                      : dbCategories[index - 1].name,
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
                      final finalReading = (selectedItemReading != null && selectedItemReading!.isNotEmpty)
      ? selectedItemReading!
      : (_currentInputReading.isNotEmpty ? _currentInputReading : editNameController.text);
                      final result = await ref
                          .read(homeViewModelProvider)
                          .addTodo(
                            text: editNameController.text,
                            category: category,
                            categoryId: selectedCategoryId,
                            priority: selectedPriority,
                            reading: finalReading,
                            image: _selectedImage,
                            budgetAmount: _budgetAmount > 0 ? _budgetAmount : null,
                            budgetType: _budgetAmount > 0 ? _budgetType : null,
                            quantityText: _selectedQuantityPreset == 'カスタム'
                                ? (_customQuantityValue.isNotEmpty ? _customQuantityValue : null)
                                : (_selectedQuantityPreset != '未指定' ? _selectedQuantityPreset : null),
                            quantityUnit: _selectedQuantityPreset == 'カスタム' && _customQuantityValue.isNotEmpty
                                ? _quantityUnit
                                : null,
                          );
                      editNameController.clear();
                      // 追加成功したらドラフトをクリア
                      ref.read(addSheetDraftNameProvider.notifier).state = '';
                      ref.read(addSheetDraftPriorityProvider.notifier).state = 0;
                      ref.read(addSheetDraftCategoryIdProvider.notifier).state = null;
                      ref.read(addSheetDraftCategoryNameProvider.notifier).state = '指定なし';
                      ref.read(addSheetDraftBudgetAmountProvider.notifier).state = 0;
                      ref.read(addSheetDraftBudgetTypeProvider.notifier).state = 0;
                      ref.read(addSheetDraftQuantityTextProvider.notifier).state = null;
                      ref.read(addSheetDraftQuantityUnitProvider.notifier).state = null;

                      if (mounted) {
                        // pop前にSnackBarを表示（contextが有効な間にOverlayに追加）
                        // OverlayエントリはルートOverlayに追加されるのでpop後も残る
                        final currentContext = context;
                        if (result != null) {
                          showTopSnackBar(
                            currentContext,
                            result.message,
                            actionLabel: result.todoItem != null ? '編集' : null,
                            onAction: result.todoItem != null
                                ? (snackBarContext) {
                                    showModalBottomSheet(
                                      context: snackBarContext,
                                      isScrollControlled: true,
                                      builder: (_) => TodoEditSheet(item: result.todoItem!),
                                    );
                                  }
                                : null,
                          );
                        }
                        Navigator.pop(currentContext);
                      }
                    },
                    child: const Text('リストに追加する'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
