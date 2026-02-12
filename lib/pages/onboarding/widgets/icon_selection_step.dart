import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedPreset = null;
        _customImagePath = pickedFile.path;
      });
      ref.read(onboardingDataProvider.notifier).setAvatarUrl(pickedFile.path);
    }
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
    final selectedImage = _selectedImageProvider();
    final hasSelectedAvatar =
        (_selectedPreset != null && _selectedPreset!.isNotEmpty) ||
        (_customImagePath != null && _customImagePath!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          const SizedBox(height: 14),
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFFC2CAD6),
              backgroundImage: selectedImage,
              child: selectedImage == null
                  ? const Icon(Icons.person, size: 54, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'メガネをかける',
                style: TextStyle(
                  color: colors.textMedium,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _withGlasses,
                onChanged: (value) {
                  setState(() {
                    _withGlasses = value;
                    if (_selectedPreset != null) {
                      _selectedPreset =
                          _presetForToggle(_selectedPreset!, _withGlasses);
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
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _presetIcons.length,
            itemBuilder: (context, index) {
              final basePreset = _presetIcons[index];
              final preset = _presetForToggle(basePreset, _withGlasses);
              final selected = _selectedPreset == preset && _customImagePath == null;
              return GestureDetector(
                onTap: () => _selectPreset(basePreset),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(backgroundImage: AssetImage(preset)),
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
              );
            },
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.borderMedium),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: Icon(
                Icons.add_photo_alternate_outlined,
                color: colors.textMedium,
                size: 18,
              ),
              label: Text(
                '写真から選ぶ',
                style: TextStyle(
                  color: colors.textMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
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
