import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_client.dart';

class SelectedImage {
  final Uint8List bytes;
  final String mime;
  const SelectedImage(this.bytes, this.mime);
  Future<Map<String, dynamic>> upload(String kind) =>
      ApiClient.uploadImage(kind, bytes, mime);
}

class ImageUploadField extends StatefulWidget {
  @visibleForTesting
  static Future<XFile?> Function() pickGallery = () => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  final String label;
  final String? url;
  final bool enabled;
  final ValueChanged<SelectedImage?> onChanged;
  const ImageUploadField({
    super.key,
    required this.label,
    this.url,
    this.enabled = true,
    required this.onChanged,
  });
  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  SelectedImage? _selected;
  bool _picking = false;
  String? _error;
  Future<void> _pick() async {
    if (_picking || !widget.enabled) return;
    setState(() => _picking = true);
    try {
      final file = await ImageUploadField.pickGallery();
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        throw const ApiException('Chọn ảnh tối đa 3 MB.');
      }
      String? mime;
      if (bytes.length >= 4 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        mime = 'image/jpeg';
      }
      if (bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        mime = 'image/png';
      }
      if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        mime = 'image/webp';
      }
      if (mime == null) {
        throw const ApiException('Chọn ảnh JPG, PNG hoặc WebP.');
      }
      if (!mounted || !widget.enabled) return;
      final image = SelectedImage(bytes, mime);
      setState(() {
        _selected = image;
        _error = null;
      });
      widget.onChanged(image);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException ? error.message : 'Không thể chọn ảnh. Kiểm tra quyền thư viện ảnh hoặc chọn ảnh khác.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 160,
          child: _selected != null
              ? Image.memory(_selected!.bytes, fit: BoxFit.contain)
              : (widget.url?.isNotEmpty ?? false)
              ? Image.network(
                  widget.url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.image_outlined, size: 56),
                )
              : const ColoredBox(
                  color: Color(0xFFFFEFE0),
                  child: Icon(Icons.add_photo_alternate_outlined, size: 56),
                ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: widget.enabled && !_picking ? _pick : null,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(_picking ? 'Đang mở thư viện…' : 'Chọn ảnh từ thiết bị'),
      ),
      const Text(
        'JPG, PNG hoặc WebP · tối đa 3 MB',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.red)),
    ],
  );
}
