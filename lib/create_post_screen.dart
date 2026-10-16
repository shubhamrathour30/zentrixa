import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Naya post banana: Post (caption + photo + anonymous option) ya Reel (video).
/// Post hone par `true` ke saath wapas jaata hai.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxVideoBytes = 12 * 1024 * 1024;

  final TextEditingController _caption = TextEditingController();
  final TextEditingController _place = TextEditingController();
  int _mode = 0; // 0 = post, 1 = reel
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String _videoName = '';
  bool _anon = false;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    _place.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        _snack('Photo must be smaller than 8 MB'.tr);
        return;
      }
      setState(() => _imageBytes = bytes);
    } catch (e) {
      _snack(tx("Couldn't pick the photo: {err}".tr, {'err': e}));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (file == null) return;
      final size = await file.length();
      if (size > _maxVideoBytes) {
        _snack('Video must be smaller than 12 MB (about 15-20 seconds). Please pick a shorter video.'.tr);
        return;
      }
      final bytes = await file.readAsBytes();
      setState(() {
        _videoBytes = bytes;
        _videoName = file.name;
      });
    } catch (e) {
      _snack(tx("Couldn't pick the video: {err}".tr, {'err': e}));
    }
  }

  Future<void> _post() async {
    if (_mode == 1) {
      if (_videoBytes == null) {
        _snack('Please choose a video first'.tr);
        return;
      }
    } else if (_caption.text.trim().isEmpty && _imageBytes == null) {
      _snack('Write something or choose a photo'.tr);
      return;
    }
    setState(() => _posting = true);
    final res = await ZxApi.post('/api/posts', {
      'caption': _caption.text.trim(),
      'place': _place.text.trim(),
      if (_mode == 0 && _imageBytes != null) 'image': base64Encode(_imageBytes!),
      if (_mode == 1 && _videoBytes != null) 'video': base64Encode(_videoBytes!),
      if (_mode == 0 && _anon) 'anon': true,
    });
    if (!mounted) return;
    setState(() => _posting = false);

    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      _snack(res.message);
    }
  }

  Widget _modeChip(String label, IconData icon, int value) {
    final sel = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = value),
        child: Container(
          height: 46,
          margin: EdgeInsets.only(right: value == 0 ? 10 : 0),
          decoration: BoxDecoration(
            color: sel ? ZX.coral : ZX.coralSoft,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: sel ? ZX.border : Colors.transparent, width: ZX.borderWidth),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: sel ? Colors.white : const Color(0xFFC25A00)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : const Color(0xFFC25A00),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 240,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 28),
        child: _imageBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 48, color: ZX.coral),
                  SizedBox(height: 8),
                  Text('Choose a photo (optional)'.tr, style: TextStyle(color: ZX.muted, fontSize: 15)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageBytes = null),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration:
                            BoxDecoration(color: ZX.ink.withOpacity(0.7), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _videoBox() {
    final has = _videoBytes != null;
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(has ? Icons.check_circle : Icons.video_call_outlined, size: 52, color: ZX.coral),
            const SizedBox(height: 8),
            Text(
              has ? _videoName : 'Choose a video'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ZX.ink, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              has
                  ? tx('{size} MB · tap to change'.tr, {'size': (_videoBytes!.length / (1024 * 1024)).toStringAsFixed(1)})
                  : 'MP4 or WEBM, max 12 MB (about 15-20 seconds)'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZX.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: ZX.cardDecoration(radius: 23, shadow: false),
                      child: const Icon(Icons.close, color: ZX.ink, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _mode == 0 ? 'New post'.tr : 'New reel'.tr,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: ZX.ink),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _modeChip('Post'.tr, Icons.edit_outlined, 0),
                  _modeChip('Reel'.tr, Icons.movie_outlined, 1),
                ],
              ),
              const SizedBox(height: 18),
              if (_mode == 0) _photoBox() else _videoBox(),
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                maxLines: 4,
                maxLength: 2000,
                style: const TextStyle(color: ZX.ink),
                decoration: ZX
                    .input(_mode == 0 ? "What's on your mind?".tr : 'Reel caption (optional)'.tr)
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _place,
                maxLength: 80,
                style: const TextStyle(color: ZX.ink),
                decoration:
                    ZX.input('Place (optional)'.tr, icon: Icons.place_outlined).copyWith(counterText: ''),
              ),
              if (_mode == 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: ZX.cardDecoration(
                    color: _anon ? ZX.coralSoft : Colors.white,
                    radius: 22,
                    shadow: false,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined, color: ZX.coral),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Anonymous (Confession)'.tr,
                                style: TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                            Text('Your name will not be shown to anyone'.tr,
                                style: TextStyle(color: ZX.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _anon,
                        onChanged: (v) => setState(() => _anon = v),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ZxButton(
                _posting ? 'Posting...'.tr : (_mode == 0 ? 'Post'.tr : 'Upload reel'.tr),
                onPressed: _posting ? null : _post,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
