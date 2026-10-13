import 'package:uuid/uuid.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/assistant_message.dart';

class AssistantRepository {
  final LocalStorageDataSource _storage;
  final _uuid = const Uuid();

  List<ConversationSession> _sessions = [];
  String? _activeSessionId;

  AssistantRepository(this._storage) {
    _sessions = _storage.loadConversations();
    if (_sessions.isEmpty) {
      _createNewSessionInitial();
    } else {
      _activeSessionId = _sessions.first.id;
    }
  }

  List<ConversationSession> get sessions => List.unmodifiable(_sessions);

  ConversationSession get activeSession {
    if (_activeSessionId == null || _sessions.isEmpty) {
      return _createNewSessionInitial();
    }
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
  }

  ConversationSession _createNewSessionInitial() {
    final newSession = ConversationSession(
      id: _uuid.v4(),
      title: 'Tiggo 7 Assistant',
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      messages: [
        AssistantMessage(
          id: _uuid.v4(),
          role: MessageRole.assistant,
          content:
              'Hello! I am **TiggoMate**, your personal AI assistant specifically designed for the **Chery Tiggo 7 PHEV CSH** (Malaysian market).\n\n'
              'I am grounded in official documentation for your hybrid powertrain, 3DHT transmission, maintenance intervals, and charging best practices.\n\n'
              '*How can I help you today?*',
          timestamp: DateTime.now(),
          suggestedFollowUps: [
            'Why hasn\'t my petrol engine started at this battery level?',
            'What does AUTO mode do?',
            'How should I manage the battery on a long journey?',
            'How much does it cost to drive 100 km using electricity versus petrol?',
          ],
        ),
      ],
    );
    _sessions = [newSession, ..._sessions];
    _activeSessionId = newSession.id;
    _storage.saveConversations(_sessions);
    return newSession;
  }

  Future<ConversationSession> createNewSession({String? title}) async {
    final newSession = ConversationSession(
      id: _uuid.v4(),
      title: title ?? 'New Conversation',
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      messages: [
        AssistantMessage(
          id: _uuid.v4(),
          role: MessageRole.assistant,
          content:
              'Hello! How can I assist you with your Chery Tiggo 7 PHEV today?',
          timestamp: DateTime.now(),
          suggestedFollowUps: [
            'What should I check before a long drive?',
            'What does AUTO mode do?',
            'When should the petrol engine operate?',
          ],
        ),
      ],
    );
    _sessions = [newSession, ..._sessions];
    _activeSessionId = newSession.id;
    await _storage.saveConversations(_sessions);
    return newSession;
  }

  void selectSession(String sessionId) {
    if (_sessions.any((s) => s.id == sessionId)) {
      _activeSessionId = sessionId;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_sessions.isEmpty) {
      _createNewSessionInitial();
    } else if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.first.id;
    }
    await _storage.saveConversations(_sessions);
  }

  Future<void> addMessageToActiveSession(AssistantMessage message) async {
    final current = activeSession;
    final updatedMessages = [...current.messages, message];

    // Update title from first user prompt if default title
    String newTitle = current.title;
    if (current.title == 'New Conversation' &&
        message.role == MessageRole.user &&
        message.content.trim().isNotEmpty) {
      newTitle = message.content.trim();
      if (newTitle.length > 28) {
        newTitle = '${newTitle.substring(0, 25)}...';
      }
    }

    final updatedSession = current.copyWith(
      title: newTitle,
      lastUpdatedAt: DateTime.now(),
      messages: updatedMessages,
    );

    final index = _sessions.indexWhere((s) => s.id == current.id);
    if (index != -1) {
      _sessions[index] = updatedSession;
    } else {
      _sessions.insert(0, updatedSession);
    }

    await _storage.saveConversations(_sessions);
  }
}
