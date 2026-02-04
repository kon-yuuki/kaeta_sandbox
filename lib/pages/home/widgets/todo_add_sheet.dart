import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import 'todo_edit_sheet.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
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
  }

  @override
  void dispose() {
    // dispose時の値をキャプチャしてからコントローラーを破棄
    final draftName = editNameController.text;
    final draftPriority = selectedPriority;
    final draftCategoryId = selectedCategoryId;
    final draftCategoryName = category;
    editNameController.dispose();
    // ビルドフェーズ終了後にProviderを更新（ビルド中のstate変更を回避）
    Future.microtask(() {
      _container.read(addSheetDraftNameProvider.notifier).state = draftName;
      _container.read(addSheetDraftPriorityProvider.notifier).state = draftPriority;
      _container.read(addSheetDraftCategoryIdProvider.notifier).state = draftCategoryId;
      _container.read(addSheetDraftCategoryNameProvider.notifier).state = draftCategoryName;
    });
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

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
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                    segments: const [
                      ButtonSegment(value: 0, label: Text('目安でOK')),
                      ButtonSegment(value: 1, label: Text('必ず条件を守る')),
                    ],
                    selected: {selectedPriority},
                    onSelectionChanged: (newSelection) {
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
                  if (_selectedImage != null)
                    SizedBox(
                      height: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
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
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('写真から選択'),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('カメラで撮影'),
                      ),
                    ],
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
                          );
                      editNameController.clear();
                      // 追加成功したらドラフトをクリア
                      ref.read(addSheetDraftNameProvider.notifier).state = '';
                      ref.read(addSheetDraftPriorityProvider.notifier).state = 0;
                      ref.read(addSheetDraftCategoryIdProvider.notifier).state = null;
                      ref.read(addSheetDraftCategoryNameProvider.notifier).state = '指定なし';

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
