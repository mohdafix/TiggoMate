import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'knowledge_document.dart';

enum MessageRole { user, assistant, system }

@immutable
class ToolExecutionRecord {
  final String toolName;
  final Map<String, dynamic> arguments;
  final dynamic result;
  final bool isWriteOperation;

  const ToolExecutionRecord({
    required this.toolName,
    required this.arguments,
    required this.result,
    this.isWriteOperation = false,
  });

  Map<String, dynamic> toMap() => {
    'toolName': toolName,
    'arguments': arguments,
    'result': result,
    'isWriteOperation': isWriteOperation,
  };

  factory ToolExecutionRecord.fromMap(Map<String, dynamic> map) =>
      ToolExecutionRecord(
        toolName: map['toolName'] as String,
        arguments: Map<String, dynamic>.from(map['arguments'] as Map),
        result: map['result'],
        isWriteOperation: map['isWriteOperation'] as bool? ?? false,
      );
}

@immutable
class AssistantMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<DocumentCitation> citations;
  final List<ToolExecutionRecord> toolsExecuted;
  final List<String> suggestedFollowUps;
  final bool isError;
  final bool isLiveReadingDependent;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.citations = const [],
    this.toolsExecuted = const [],
    this.suggestedFollowUps = const [],
    this.isError = false,
    this.isLiveReadingDependent = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'citations': citations.map((e) => e.toMap()).toList(),
    'toolsExecuted': toolsExecuted.map((e) => e.toMap()).toList(),
    'suggestedFollowUps': suggestedFollowUps,
    'isError': isError,
    'isLiveReadingDependent': isLiveReadingDependent,
  };

  factory AssistantMessage.fromMap(
    Map<String, dynamic> map,
  ) => AssistantMessage(
    id: map['id'] as String,
    role: MessageRole.values.byName(map['role'] as String),
    content: map['content'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    citations:
        (map['citations'] as List<dynamic>?)
            ?.map((e) => DocumentCitation.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
    toolsExecuted:
        (map['toolsExecuted'] as List<dynamic>?)
            ?.map((e) => ToolExecutionRecord.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
    suggestedFollowUps:
        (map['suggestedFollowUps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    isError: map['isError'] as bool? ?? false,
    isLiveReadingDependent: map['isLiveReadingDependent'] as bool? ?? false,
  );
}

@immutable
class ConversationSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final List<AssistantMessage> messages;

  const ConversationSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.messages = const [],
  });

  ConversationSession copyWith({
    String? title,
    DateTime? lastUpdatedAt,
    List<AssistantMessage>? messages,
  }) {
    return ConversationSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    'messages': messages.map((e) => e.toMap()).toList(),
  };

  factory ConversationSession.fromMap(Map<String, dynamic> map) =>
      ConversationSession(
        id: map['id'] as String,
        title: map['title'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastUpdatedAt: DateTime.parse(map['lastUpdatedAt'] as String),
        messages:
            (map['messages'] as List<dynamic>?)
                ?.map(
                  (e) => AssistantMessage.fromMap(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
      );

  String toJson() => json.encode(toMap());

  factory ConversationSession.fromJson(String source) =>
      ConversationSession.fromMap(json.decode(source) as Map<String, dynamic>);
}
