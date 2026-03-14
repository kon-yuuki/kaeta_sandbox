import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class ItemCameraCapturePage extends StatefulWidget {
  const ItemCameraCapturePage({super.key});

  @override
  State<ItemCameraCapturePage> createState() => _ItemCameraCapturePageState();
}

class _ItemCameraCapturePageState extends State<ItemCameraCapturePage> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _isCapturing = false;
  Uint8List? _latestPhotoBytes;
  bool _isLoadingLatestPhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializeCamera();
    _loadLatestGalleryPhoto();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('利用可能なカメラが見つかりません');
    }

    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<XFile>(image);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('撮影に失敗しました')));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (!mounted || image == null) return;
    Navigator.of(context).pop<XFile>(image);
  }

  Future<void> _loadLatestGalleryPhoto() async {
    setState(() => _isLoadingLatestPhoto = true);
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        if (!mounted) return;
        setState(() {
          _latestPhotoBytes = null;
          _isLoadingLatestPhoto = false;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _latestPhotoBytes = null;
          _isLoadingLatestPhoto = false;
        });
        return;
      }

      final assets = await albums.first.getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) {
        if (!mounted) return;
        setState(() {
          _latestPhotoBytes = null;
          _isLoadingLatestPhoto = false;
        });
        return;
      }

      final bytes = await assets.first.thumbnailDataWithSize(
        const ThumbnailSize(120, 120),
      );
      if (!mounted) return;
      setState(() {
        _latestPhotoBytes = bytes;
        _isLoadingLatestPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _latestPhotoBytes = null;
        _isLoadingLatestPhoto = false;
      });
    }
  }

  Widget _buildGalleryButton() {
    final thumbnail = _latestPhotoBytes;

    return InkWell(
      onTap: _pickFromGallery,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: thumbnail != null
            ? Image.memory(thumbnail, fit: BoxFit.cover)
            : _isLoadingLatestPhoto
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_library_outlined),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || _controller == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('カメラを起動できませんでした'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _pickFromGallery,
                        child: const Text('ライブラリから追加'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final controller = _controller!;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                      const Expanded(
                        child: Text(
                          '写真で伝える',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFD9D9D9),
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize!.height,
                        height: controller.value.previewSize!.width,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGalleryButton(),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF334155),
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 52, height: 52),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
