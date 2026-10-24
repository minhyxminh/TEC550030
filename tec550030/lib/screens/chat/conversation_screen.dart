import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/chat_service.dart';
import '../../services/workflow_service.dart';
import '../../widgets/brand.dart';
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
      backgroundColor: Colors.white,
      toolbarHeight: 76,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      elevation: 6,
      shadowColor: AppColors.ink.withValues(alpha: 0.12),
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: AppColors.peach,
              shape: BoxShape.circle,
            ),
            child: const TigerHead(size: 34),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.title,
              style: AppTextStyles.heading2.copyWith(fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lavender,
              foregroundColor: AppColors.ink,
              fixedSize: const Size(44, 44),
            ),
            tooltip: 'Làm mới',
            onPressed: _fetching ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.primaryOrange
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(mine ? 20 : 6),
                              bottomRight: Radius.circular(mine ? 6 : 20),
                            ),
                            boxShadow: mine ? null : AppShadows.soft,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['content'] as String,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatDateTime(DateTime.parse(message['created_at'] as String))}${mine && message['read_at'] != null ? ' · Đã đọc' : ''}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: mine
                                      ? AppColors.ink
                                      : AppColors.secondaryText,
                                  fontWeight: mine
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: AppShadows.soft,
            ),
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
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(54, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  tooltip: 'Gửi',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
