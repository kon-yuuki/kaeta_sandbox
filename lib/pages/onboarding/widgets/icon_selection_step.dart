import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../home/view/item_camera_capture_page.dart';
import '../providers/onboarding_provider.dart';

class IconSelectionStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const IconSelectionStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<IconSelectionStep> createState() => _IconSelectionStepState();
}

class _IconSelectionStepState extends ConsumerState<IconSelectionStep> {
  // メガネなしのベースプリセット
  static const List<String> _presetIcons = [
    'assets/icons/avatars/img_Men01.png',
    'assets/icons/avatars/img_Men02.png',
    'assets/icons/avatars/img_Men03.png',
    'assets/icons/avatars/img_Men04.png',
    'assets/icons/avatars/img_Men05.png',
    'assets/icons/avatars/img_Men06.png',
    'assets/icons/avatars/img_Women01.png',
    'assets/icons/avatars/img_Women02.png',
    'assets/icons/avatars/img_Women03.png',
    'assets/icons/avatars/img_Women04.png',
    'assets/icons/avatars/img_Women05.png',
    'assets/icons/avatars/img_Women06.png',
  ];

  String? _selectedPreset;
  String? _customImagePath;
  bool _withGlasses = false;

  @override
  void initState() {
    super.initState();
    final onboardingData = ref.read(onboardingDataProvider);
    _selectedPreset = onboardingData.avatarPreset;
    _customImagePath = onboardingData.avatarUrl;
    _withGlasses = _isGlassesPreset(onboardingData.avatarPreset);
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceSheet();
    if (!mounted || source == null) return;

    XFile? pickedFile;
    if (source == ImageSource.camera) {
      pickedFile = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const ItemCameraCapturePage()),
      );
    } else {
      final picker = ImagePicker();
      pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        requestFullMetadata: false,
      );
    }

    if (!mounted || pickedFile == null) return;

    final toolbarColor = Theme.of(context).primaryColor;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '切り抜き',
          toolbarColor: toolbarColor,
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
        _selectedPreset = null;
        _customImagePath = croppedFile.path;
      });
      ref.read(onboardingDataProvider.notifier).setAvatarUrl(croppedFile.path);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    final colors = AppColors.of(context);
    if (Platform.isIOS) {
      return showCupertinoModalPopup<ImageSource>(
        context: context,
        builder: (sheetContext) {
          return CupertinoActionSheet(
            title: const Text('写真から選ぶ'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
                child: Text(
                  'アルバムからアップロード',
                  style: TextStyle(color: colors.blue),
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
                child: Text('カメラで撮影', style: TextStyle(color: colors.blue)),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDestructiveAction: false,
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text('キャンセル', style: TextStyle(color: colors.blue)),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('撮影'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('メディアから選ぶ'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 4),
              ListTile(
                title: const Center(child: Text('キャンセル')),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectPreset(String basePreset) {
    final preset = _presetForToggle(basePreset, _withGlasses);
    setState(() {
      _selectedPreset = preset;
      _customImagePath = null;
    });
    ref.read(onboardingDataProvider.notifier).setAvatarPreset(preset);
  }

  ImageProvider? _selectedImageProvider() {
    if (_customImagePath != null && _customImagePath!.isNotEmpty) {
      return FileImage(File(_customImagePath!));
    }
    if (_selectedPreset != null && _selectedPreset!.isNotEmpty) {
      return AssetImage(_selectedPreset!);
    }
    return null;
  }

  bool _isGlassesPreset(String? preset) {
    return preset != null && preset.contains('_glasses');
  }

  String _toPlainPreset(String preset) {
    return preset.replaceFirst('_glasses', '');
  }

  String _toGlassesPreset(String preset) {
    if (preset.contains('_glasses')) return preset;
    return preset.replaceFirstMapped(
      RegExp(r'(\d+)\.png$'),
      (m) => '_glasses${m.group(1)}.png',
    );
  }

  String _presetForToggle(String basePreset, bool withGlasses) {
    final plain = _toPlainPreset(basePreset);
    return withGlasses ? _toGlassesPreset(plain) : plain;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final selectedImage = _selectedImageProvider();
    final hasSelectedAvatar =
        (_selectedPreset != null && _selectedPreset!.isNotEmpty) ||
        (_customImagePath != null && _customImagePath!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'アイコン',
                style: TextStyle(
                  color: colors.textLow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEBEF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '必須',
                  style: TextStyle(
                    color: colors.textAlert,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFD4DBE6),
                backgroundImage: selectedImage,
                child: selectedImage == null
                    ? const Icon(Icons.person, size: 68, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      side: BorderSide(color: colors.borderMedium),
                      backgroundColor: colors.surfaceHighOnInverse,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: colors.textMedium,
                      size: 18,
                    ),
                    label: Text(
                      '写真から選ぶ',
                      style: typography.std12B160.copyWith(
                        color: colors.textMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: colors.borderLow),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'メガネをかける',
                style: typography.std12B160.copyWith(color: colors.textMedium),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: _withGlasses,
                activeTrackColor: colors.accentPrimary,
                inactiveTrackColor: colors.surfaceSecondary,
                thumbColor: colors.surfaceHighOnInverse,
                onChanged: (value) {
                  setState(() {
                    _withGlasses = value;
                    if (_selectedPreset != null) {
                      _selectedPreset = _presetForToggle(
                        _selectedPreset!,
                        _withGlasses,
                      );
                    }
                  });
                  if (_selectedPreset != null) {
                    ref
                        .read(onboardingDataProvider.notifier)
                        .setAvatarPreset(_selectedPreset);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemCount: _presetIcons.length,
              itemBuilder: (context, index) {
                final basePreset = _presetIcons[index];
                final preset = _presetForToggle(basePreset, _withGlasses);
                final selected =
                    _selectedPreset == preset && _customImagePath == null;
                return GestureDetector(
                  onTap: () => _selectPreset(basePreset),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage(preset),
                        ),
                        if (selected)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: colors.accentPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surfaceHighOnInverse,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                color: colors.textHighOnInverse,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: hasSelectedAvatar ? widget.onNext : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('家族の招待へ進む', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          if (MediaQuery.of(context).padding.bottom > 0)
            SizedBox(height: MediaQuery.of(context).padding.bottom - 6),
        ],
      ),
    );
  }
}
