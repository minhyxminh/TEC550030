import 'package:material_ui/material_ui.dart';

import 'app_button.dart';
import '../services/workflow_service.dart';

class RequestButton extends StatefulWidget {
  final String path;
  final Map<String, dynamic> body;
  final String text;
  final String confirmation;
  final String success;
  final VoidCallback? onSuccess;
  const RequestButton({
    super.key,
    required this.path,
    required this.body,
    required this.text,
    required this.confirmation,
    required this.success,
    this.onSuccess,
  });
  @override
  State<RequestButton> createState() => _RequestButtonState();
}

class _RequestButtonState extends State<RequestButton> {
  final _key = WorkflowService.requestKey();
  @override
  Widget build(BuildContext context) => WorkflowButton(
    text: widget.text,
    confirmation: widget.confirmation,
    success: widget.success,
    onSuccess: widget.onSuccess,
    action: () => WorkflowService().send(widget.path, {
      ...widget.body,
      'idempotency_key': _key,
    }),
  );
}

/// Keeps a request key in the parent closure across retries after a network error.
class WorkflowButton extends StatefulWidget {
  final String text;
  final String confirmation;
  final String success;
  final Future<dynamic> Function() action;
  final VoidCallback? onSuccess;
  const WorkflowButton({
    super.key,
    required this.text,
    required this.confirmation,
    required this.action,
    this.success = 'Thao tác thành công.',
    this.onSuccess,
  });
  @override
  State<WorkflowButton> createState() => _WorkflowButtonState();
}

class _WorkflowButtonState extends State<WorkflowButton> {
  bool _busy = false;
  bool _done = false;
  String? _error;
  Future<void> _submit() async {
    if (_busy || _done) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.text),
        content: Text(widget.confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.action();
      if (!mounted) return;
      setState(() => _done = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.success)));
      widget.onSuccess?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      AppButton(
        text: _done ? 'Đã hoàn tất' : widget.text,
        isLoading: _busy,
        onPressed: _done ? null : _submit,
      ),
    ],
  );
}
