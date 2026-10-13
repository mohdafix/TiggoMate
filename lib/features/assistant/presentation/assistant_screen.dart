import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/assistant_message.dart';
import '../../../data/models/knowledge_document.dart';
import '../../../data/repositories/assistant_repository.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTtsActive = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? text]) {
    final query = text ?? _textController.text;
    if (query.trim().isEmpty) return;

    ref.read(chatProvider.notifier).sendUserQuery(query.trim());
    _textController.clear();
    _scrollToBottom();
  }

  void _handleVoiceInput() async {
    final voice = ref.read(voiceServiceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listening for speech... (Tap prompt to send)'),
        duration: Duration(seconds: 2),
      ),
    );
    final spoken = await voice.listenForSpeech();
    if (spoken != null && spoken.isNotEmpty) {
      _sendMessage(spoken);
    } else {
      // Graceful Android speech fallback prompt
      if (!mounted) return;
      _showVoiceFallbackDialog();
    }
  }

  void _showVoiceFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voice Assistant Fallback'),
        content: const Text(
          'Microphone input is unavailable on this device or permission is pending. '
          'You can speak using the Android Gboard voice button or select from suggested Tiggo 7 questions below:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendMessage('What does AUTO mode do?');
            },
            child: const Text('Ask: What does AUTO mode do?'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final assistantRepo = ref.watch(assistantRepositoryProvider);
    final messages = chatState.session.messages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TiggoMate AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              chatState.session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          // TTS toggle
          IconButton(
            icon: Icon(
              _isTtsActive ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isTtsActive ? AppTheme.primaryTeal : Colors.grey,
            ),
            tooltip: _isTtsActive ? 'TTS Voice Enabled' : 'TTS Voice Muted',
            onPressed: () {
              setState(() {
                _isTtsActive = !_isTtsActive;
                ref.read(voiceServiceProvider).toggleTts(_isTtsActive);
              });
            },
          ),
          // Session menu (New conversation / Delete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'new') {
                ref.read(chatProvider.notifier).createNewSession();
              } else if (val == 'delete') {
                ref.read(chatProvider.notifier).deleteCurrentSession();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('New Conversation'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildConversationDrawer(assistantRepo),
      body: Column(
        children: [
          // Chat message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageItem(context, message);
              },
            ),
          ),

          // Loading / streaming indicator
          if (chatState.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Grounding answer with Tiggo 7 PHEV manuals & tools...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryTeal.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

          // Error indicator with retry
          if (chatState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chatState.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final lastUser = messages.reversed
                          .where((m) => m.role == MessageRole.user)
                          .firstOrNull;
                      if (lastUser != null) {
                        _sendMessage(lastUser.content);
                      }
                    },
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildConversationDrawer(AssistantRepository repo) {
    final sessions = repo.sessions;
    final active = repo.activeSession;

    return Drawer(
      backgroundColor: AppTheme.surfaceCarbon,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chat History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'New Conversation',
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(chatProvider.notifier).createNewSession();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (ctx, idx) {
                  final s = sessions[idx];
                  final isSelected = s.id == active.id;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryTeal.withValues(
                      alpha: 0.15,
                    ),
                    leading: const Icon(Icons.chat_bubble_outline, size: 18),
                    title: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryTeal : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '${s.messages.length} messages',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(chatProvider.notifier).selectSession(s.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, AssistantMessage message) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
              child: const Icon(
                Icons.smart_toy,
                color: AppTheme.primaryTeal,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryTeal.withValues(alpha: 0.2)
                    : AppTheme.elevatedCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppTheme.primaryTeal.withValues(alpha: 0.4)
                      : const Color(0xFF334155),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Executed Tools pill
                  if (message.toolsExecuted.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: message.toolsExecuted.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF475569),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.handyman_outlined,
                                size: 11,
                                color: AppTheme.accentCyan,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.toolName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFCBD5E1),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Markdown Content
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: const TextStyle(fontSize: 14, height: 1.45),
                          code: const TextStyle(
                            fontFamily: 'monospace',
                            backgroundColor: Color(0xFF1E293B),
                            fontSize: 12,
                          ),
                        ),
                  ),

                  // Citations and Document References
                  if (message.citations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCitationsSection(context, message.citations),
                  ],

                  // Suggested Follow-up Questions
                  if (message.suggestedFollowUps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Suggested Follow-ups:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.suggestedFollowUps.map((q) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.surfaceCarbon,
                          side: const BorderSide(color: Color(0xFF334155)),
                          label: Text(
                            q,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          onPressed: () => _sendMessage(q),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
              child: const Icon(
                Icons.person,
                color: AppTheme.accentCyan,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationsSection(
    BuildContext context,
    List<DocumentCitation> citations,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: AppTheme.primaryTeal,
              ),
              SizedBox(width: 6),
              Text(
                'VERIFIED SOURCE CITATIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...citations.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF94A3B8))),
                  Expanded(
                    child: Text(
                      c.formattedReference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCarbon,
        border: const Border(top: BorderSide(color: Color(0xFF263238))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: AppTheme.primaryTeal),
              tooltip: 'Voice Input',
              onPressed: _handleVoiceInput,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask TiggoMate about your Tiggo 7 PHEV...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppTheme.elevatedCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppTheme.primaryTeal),
              onPressed: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}
