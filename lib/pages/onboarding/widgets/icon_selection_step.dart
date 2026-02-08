import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  // プリセットアイコンのアセットパス
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

  void _selectPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      _customImagePath = null;
    });
    ref.read(onboardingDataProvider.notifier).setAvatarPreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'アイコンを選択',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'プリセットから選ぶか、写真をアップロードしてください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // プリセットアイコングリッド
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _presetIcons.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // カスタム画像ボタン
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _customImagePath != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: _customImagePath != null ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _customImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                _customImagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add_photo_alternate,
                              size: 32,
                              color: Colors.grey,
                            ),
                    ),
                  );
                }

                final preset = _presetIcons[index - 1];
                final isSelected = _selectedPreset == preset;

                return GestureDetector(
                  onTap: () => _selectPreset(preset),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        preset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.outlined,
                  onPressed: widget.onBack,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('戻る', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  onPressed: widget.onNext,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _selectedPreset != null || _customImagePath != null
                          ? 'チーム招待へ'
                          : 'スキップしてチーム招待へ',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
