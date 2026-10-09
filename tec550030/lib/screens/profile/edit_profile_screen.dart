import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../services/workflow_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/image_upload_field.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  const EditProfileScreen({super.key, required this.name, this.avatarUrl});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  bool _busy = false;
  String? _error;
  SelectedImage? _image;
  String? _uploadedPath;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_image != null && _uploadedPath == null) {
        _uploadedPath = (await _image!.upload('avatars'))['path'] as String;
      }
      await ApiClient.patchJson('/me', {
        'name': _name.text.trim(),
        if (_uploadedPath != null) 'avatar_path': _uploadedPath,
      });
      WorkflowService.revision.value++;
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ImageUploadField(
            label: 'Ảnh đại diện',
            url: widget.avatarUrl,
            enabled: !_busy,
            onChanged: (image) {
              _image = image;
              _uploadedPath = null;
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            maxLength: 100,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập họ tên'
                : null,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          AppButton(text: 'Lưu hồ sơ', isLoading: _busy, onPressed: _save),
        ],
      ),
    ),
  );
}
