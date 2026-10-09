import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../services/workflow_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/data_view.dart';
import '../../widgets/workflow_button.dart';
import '../../widgets/image_upload_field.dart';

const _tables = {
  'rewards': 'Phần quà',
  'memberships': 'Gói tập',
  'trainers': 'Huấn luyện viên',
};
const _labels = <String, String>{
  'name': 'Tên',
  'description': 'Mô tả',
  'points': 'Điểm đổi quà',
  'stock': 'Số lượng tồn',
  'image_url': 'URL ảnh (có thể để trống)',
  'price_vnd': 'Giá (VNĐ)',
  'duration_days': 'Số ngày',
  'points_per_checkin': 'Điểm mỗi check-in',
  'specialty': 'Chuyên môn',
  'experience_years': 'Số năm kinh nghiệm',
};
const _numeric = {
  'points',
  'stock',
  'price_vnd',
  'duration_days',
  'points_per_checkin',
  'experience_years',
};
const _fields = <String, List<String>>{
  'rewards': ['name', 'description', 'points', 'stock', 'image_url'],
  'memberships': [
    'name',
    'description',
    'price_vnd',
    'duration_days',
    'points_per_checkin',
  ],
  'trainers': [
    'name',
    'specialty',
    'experience_years',
    'description',
    'image_url',
  ],
};

class CatalogueAdminScreen extends StatefulWidget {
  const CatalogueAdminScreen({super.key});
  @override
  State<CatalogueAdminScreen> createState() => _CatalogueAdminScreenState();
}

class _CatalogueAdminScreenState extends State<CatalogueAdminScreen> {
  String _table = 'rewards';
  int _version = 0;
  int _pages = 1;
  void _reload() => setState(() => _version++);
  Future<void> _edit([Map<String, dynamic>? record]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CatalogueForm(table: _table, record: record),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<List<dynamic>> _load() async {
    final table = _table;
    final pages = _pages;
    final rows = <dynamic>[];
    for (var i = 0; i < pages; i++) {
      final batch = await ApiClient.getJson(
        '/admin/$table?limit=20&offset=${i * 20}',
      ) as List;
      rows.addAll(batch);
      if (batch.length < 20) break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý danh mục')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: _tables.entries
                .map(
                  (e) => ChoiceChip(
                    label: Text(e.value),
                    selected: _table == e.key,
                    onSelected: (_) => setState(() {
                      _table = e.key;
                      _pages = 1;
                      _version++;
                    }),
                  ),
                )
                .toList(),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: Text('Thêm ${_tables[_table]}'),
        ),
        Expanded(
          child: DataView<List<dynamic>>(
            key: ValueKey(_version),
            load: _load,
            builder: (context, rows) => [
              if (rows.isEmpty) const AppCard(child: Text('Chưa có dữ liệu.')),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          row['is_active'] == true ? 'Đang hiển thị' : 'Đã ẩn',
                        ),
                        TextButton(
                          onPressed: () =>
                              _edit(Map<String, dynamic>.from(row)),
                          child: const Text('Chỉnh sửa'),
                        ),
                        if (row['is_active'] == true)
                          WorkflowButton(
                            text: 'Ẩn khỏi danh mục',
                            confirmation: 'Ẩn mục này? Lịch sử đã phát sinh vẫn được giữ.',
                            action: () => ApiClient.postJson(
                              '/admin/$_table/${row['id']}/archive',
                              {},
                            ),
                            onSuccess: _reload,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (rows.length == _pages * 20)
                TextButton(
                  onPressed: () {
                    _pages++;
                    _reload();
                  },
                  child: const Text('Xem thêm'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CatalogueForm extends StatefulWidget {
  final String table;
  final Map<String, dynamic>? record;
  const _CatalogueForm({required this.table, this.record});
  @override
  State<_CatalogueForm> createState() => _CatalogueFormState();
}

class _CatalogueFormState extends State<_CatalogueForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late bool _active;
  bool _busy = false;
  String? _error;
  SelectedImage? _image;
  String? _uploadedUrl;
  @override
  void initState() {
    super.initState();
    _active = widget.record?['is_active'] ?? true;
    _controllers = {
      for (final field in _fields[widget.table]!)
        field: TextEditingController(
          text:
              '${widget.record?[field] ?? (_numeric.contains(field) ? 0 : '')}',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'is_active': _active,
      for (final e in _controllers.entries)
        e.key: _numeric.contains(e.key)
            ? int.parse(e.value.text)
            : e.value.text.trim(),
    };
    try {
      if (_image != null) {
        _uploadedUrl ??= (await _image!.upload(widget.table))['url'] as String;
        body['image_url'] = _uploadedUrl;
      }
      if (widget.record == null) {
        await ApiClient.postJson('/admin/${widget.table}', body);
      } else {
        await ApiClient.patchJson(
          '/admin/${widget.table}/${widget.record!['id']}',
          body,
        );
      }
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
    appBar: AppBar(
      title: Text(
        '${widget.record == null ? 'Thêm' : 'Sửa'} ${_tables[widget.table]}',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (widget.table != 'memberships') ...[
            ImageUploadField(
              label: 'Ảnh ${_tables[widget.table]}',
              url: widget.record?['image_url'],
              enabled: !_busy,
              onChanged: (image) {
                _image = image;
                _uploadedUrl = null;
              },
            ),
            const SizedBox(height: 24),
          ],
          ..._controllers.entries
              .where((e) => e.key != 'image_url')
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: e.value,
                    keyboardType: _numeric.contains(e.key)
                        ? TextInputType.number
                        : TextInputType.text,
                    maxLines: e.key == 'description' ? 4 : 1,
                    decoration: InputDecoration(labelText: _labels[e.key]),
                    validator: (value) {
                      if (e.key == 'name' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Vui lòng nhập tên';
                      }
                      if (e.key == 'name' && value!.trim().length > 100) {
                        return 'Tên tối đa 100 ký tự';
                      }
                      if (_numeric.contains(e.key)) {
                        final n = int.tryParse(value ?? '');
                        final positive = {
                          'points',
                          'duration_days',
                          'points_per_checkin',
                        }.contains(e.key);
                        if (n == null || n < (positive ? 1 : 0)) {
                          return positive
                              ? 'Nhập số nguyên lớn hơn 0'
                              : 'Nhập số nguyên không âm';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),
          SwitchListTile(
            title: const Text('Hiển thị trong danh mục'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    ),
  );
}
