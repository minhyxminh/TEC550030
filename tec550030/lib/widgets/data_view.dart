import 'package:material_ui/material_ui.dart';

import 'error_state.dart';
import 'loading_view.dart';
import '../services/workflow_service.dart';

// All data screens share refresh, retry, readable widths and lifecycle handling.
class DataView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext, T) builder;
  const DataView({super.key, required this.load, required this.builder});
  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  T? _data;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _reload();
    WorkflowService.revision.addListener(_reload);
  }

  @override
  void dispose() {
    WorkflowService.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: _error != null
                    ? [
                        SizedBox(
                          height: (constraints.maxHeight - 40).clamp(
                            280.0,
                            double.infinity,
                          ),
                          child: ErrorState(message: _error!, onRetry: _reload),
                        ),
                      ]
                    : widget.builder(context, _data as T),
              ),
            ),
          ),
        );
      },
    );
  }
}
