import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import 'category_edit_sheet.dart';
import '../../../data/providers/category_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

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
                      final matchedItem = await ref
                          .read(homeViewModelProvider)
                          .searchItemByReading(value);

                      if (matchedItem != null) {
                        // 2. 見つかったら、カテゴリや画像を自動セット
                        setState(() {
                          category = matchedItem.category;
                          selectedCategoryId = matchedItem.categoryId;
                          _matchedImageUrl =
                              matchedItem.imageUrl; // マスタにある画像のURL
                        });
                      } else {
                        // 見つからなかったらクリアするか、そのままにする（お好みで）
                        setState(() {
                          _matchedImageUrl = null;
                        });
                      }
                    },
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
                        child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                      ),
                    )
                  else if (_matchedImageUrl != null)
                    SizedBox(
                      height: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_matchedImageUrl!, fit: BoxFit.cover),
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
                      await ref
                          .read(homeViewModelProvider)
                          .addTodo(
                            text: editNameController.text,
                            category: category,
                            categoryId: selectedCategoryId,
                            priority: selectedPriority,
                            image: _selectedImage,
                          );
                      editNameController.clear();

                      if (mounted) Navigator.pop(context);
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
