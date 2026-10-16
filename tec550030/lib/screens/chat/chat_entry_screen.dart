import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/user.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import 'conversation_screen.dart';

class ChatEntryScreen extends StatefulWidget {
  const ChatEntryScreen({super.key});
  @override
  State<ChatEntryScreen> createState() => _ChatEntryScreenState();
}

class _ChatEntryScreenState extends State<ChatEntryScreen>
    with WidgetsBindingObserver {
  final _service = ChatService();
  Timer? _timer;
  User? _user;
  String? _error;
  bool _loading = true, _busy = false, _hasMore = false;
  List<Map<String, dynamic>> _conversations = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false, bool more = false}) async {
    if (_busy) return;
    _busy = true;
    if (!silent && !more) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = _user ?? await AuthService().getCurrentUser();
      if (user.role != 'ADMIN') {
        final conversation = await _service.open();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              conversationId: conversation['id'] as String,
              userId: user.id,
              title: 'Chat với GymFlow',
            ),
          ),
        );
        return;
      }
      final page = await _service.inbox(
        offset: more ? _conversations.length : 0,
      );
      if (!mounted) return;
      setState(() {
        _user = user;
        if (silent && _conversations.length > 50) {
          final byId = {for (final c in _conversations) c['id']: c};
          for (final c in page) {
            byId[c['id']] = c;
          }
          _conversations = byId.values.toList()
            ..sort(
              (a, b) => (b['updated_at'] as String).compareTo(
                a['updated_at'] as String,
              ),
            );
        } else if (more) {
          final ids = _conversations.map((e) => e['id']).toSet();
          _conversations.addAll(page.where((e) => !ids.contains(e['id'])));
        } else {
          _conversations = page;
        }
        if (!silent || _conversations.length <= 50) {
          _hasMore = page.length == 50;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hộp thư hỗ trợ')),
    body: _loading
        ? const LoadingView()
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  ErrorState(message: _error!, onRetry: () => _load()),
                if (_conversations.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có hội thoại. Tin nhắn của hội viên sẽ xuất hiện tại đây.',
                    ),
                  ),
                ..._conversations.map(
                  (c) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(c['name'] as String? ?? 'Hội viên'),
                      subtitle: Text(
                        c['last_message'] as String? ?? 'Hội thoại mới',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: (c['unread'] as num? ?? 0) > 0
                          ? Badge(label: Text('${c['unread']}'))
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              conversationId: c['id'] as String,
                              userId: _user!.id,
                              title: c['name'] as String? ?? 'Hội viên',
                            ),
                          ),
                        );
                        if (mounted) _load(silent: true);
                      },
                    ),
                  ),
                ),
                if (_hasMore)
                  TextButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: const Text('Xem thêm hội thoại'),
                  ),
              ],
            ),
          ),
  );
}
