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
  final TextEditingController editNameController = TextEditingController();
  int selectedPriority = 0;
  int selectedCategoryValue = 0;
  String category = "指定なし";
  String? selectedCategoryId;
  XFile? _selectedImage;
  String? _matchedImageUrl;
  String? selectedItemReading;
  List<dynamic> _suggestions = [];
  String _currentInputReading = "";

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
  void dispose() {
    editNameController.dispose();
    super.dispose();
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
  print('--- ログ開始 ---');
  print('入力値: "$value"');
  print('漢字検知: ${hasKanji ? "❌あり" : "✅なし"}');

  if (!hasKanji) {
    setState(() {
      _currentInputReading = value;
    });
    print('読みを更新: $_currentInputReading');
  } else {
    print('漢字が含まれるため、読みの更新をスキップしました');
  }
  print('現在の確定待ち伏せ値: $_currentInputReading');
  print('--- ログ終了 ---');
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

                                    // カテゴリの選択状態を更新
                                    categoryAsync.whenData((dbCategories) {
                                      final catIndex = dbCategories.indexWhere(
                                        (c) => c.id == original.categoryId,
                                      );
                                      setState(() {
                                        selectedCategoryValue = (catIndex != -1)
                                            ? catIndex + 1
                                            : 0;
                                      });
                                    });
                                  } else {
                                    // マスタデータ（MasterItem）の場合は初期状態に
                                    category = "指定なし";
                                    selectedCategoryId = null;
                                    _matchedImageUrl = null;
                                    selectedCategoryValue = 0;
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
                                selected: selectedCategoryValue == index,
                                onSelected: (bool selected) {
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
