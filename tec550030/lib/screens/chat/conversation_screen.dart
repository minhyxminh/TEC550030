import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../services/chat_service.dart';
import '../../services/workflow_service.dart';
import '../../widgets/loading_view.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId, userId, title;
  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.title,
  });
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final _service = ChatService();
  final _text = TextEditingController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _fetching = false, _sending = false, _hasMore = false;
  String? _error, _pendingKey, _pendingText;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _refresh();
    }
  }

  void _merge(List<Map<String, dynamic>> page) {
    final byId = {for (final m in _messages) m['id']: m};
    for (final m in page) {
      byId[m['id']] = m;
    }
    _messages = byId.values.toList()
      ..sort((a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num));
  }

  Future<void> _refresh({bool older = false}) async {
    if (_fetching) return;
    setState(() => _fetching = true);
    try {
      final page = await _service.messages(
        widget.conversationId,
        before: older && _messages.isNotEmpty
            ? (_messages.first['sequence'] as num).toInt()
            : null,
      );
      if (!mounted) return;
      // Fill a gap when more than one page arrived while the app was backgrounded.
      final collected = [...page];
      if (!older && _messages.isNotEmpty && page.length == 50) {
        final previousLast = _messages.last['sequence'] as num;
        var cursor = (page.first['sequence'] as num).toInt();
        while (cursor > previousLast && mounted) {
          final gap = await _service.messages(
            widget.conversationId,
            before: cursor,
          );
          if (gap.isEmpty) break;
          collected.addAll(gap);
          cursor = (gap.first['sequence'] as num).toInt();
        }
      }
      if (!mounted) return;
      setState(() {
        if (_messages.isEmpty || older) _hasMore = page.length == 50;
        _merge(collected);
        _loading = false;
        _error = null;
      });
      if (_messages.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        await _service.read(
          widget.conversationId,
          (_messages.last['sequence'] as num).toInt(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (_sending || content.isEmpty) return;
    if (content.length > 2000) return;
    if (_pendingText != content) {
      _pendingText = content;
      _pendingKey = WorkflowService.requestKey();
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await _service.send(
        widget.conversationId,
        content,
        _pendingKey!,
      );
      if (!mounted) return;
      setState(() {
        _merge([message]);
        _text.clear();
        _pendingKey = null;
        _pendingText = null;
      });
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Chưa xác nhận gửi thành công. Bấm Gửi để thử lại. $e',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _fetching ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _messages.isEmpty
                ? const Center(
                    child: Text('Gửi lời chào để bắt đầu cuộc trò chuyện.'),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return TextButton(
                          onPressed: _fetching
                              ? null
                              : () => _refresh(older: true),
                          child: const Text('Tin nhắn trước'),
                        );
                      }
                      final message = _messages[_messages.length - 1 - index];
                      final mine = message['sender_id'] == widget.userId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.primaryOrange.withValues(
                                    alpha: 0.14,
                                  )
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['content'] as String),
                              const SizedBox(height: 6),
                              Text(
                                '${formatDateTime(DateTime.parse(message['created_at'] as String))}${mine && message['read_at'] != null ? ' · Đã đọc' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn…',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Gửi',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
