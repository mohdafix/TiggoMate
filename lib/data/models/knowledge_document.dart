import 'package:flutter/foundation.dart';

/// Chunk from verified Tiggo 7 PHEV CSH documentation.
@immutable
class KnowledgeChunk {
  final String id;
  final String title;
  final String section;
  final String documentName;
  final int? pageNumber;
  final String market;
  final String content;
  final List<String> tags;
  final String? sourceUrl;

  const KnowledgeChunk({
    required this.id,
    required this.title,
    required this.section,
    required this.documentName,
    this.pageNumber,
    this.market = 'Malaysia',
    required this.content,
    this.tags = const [],
    this.sourceUrl,
  });

  factory KnowledgeChunk.fromMap(Map<String, dynamic> map) {
    return KnowledgeChunk(
      id: map['id'] as String,
      title: map['title'] as String,
      section: map['section'] as String? ?? 'General',
      documentName: map['documentName'] as String,
      pageNumber: (map['pageNumber'] as num?)?.toInt(),
      market: map['market'] as String? ?? 'Malaysia',
      content: map['content'] as String,
      tags:
          (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      sourceUrl: map['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'section': section,
    'documentName': documentName,
    'pageNumber': pageNumber,
    'market': market,
    'content': content,
    'tags': tags,
    'sourceUrl': sourceUrl,
  };

  DocumentCitation toCitation({String? matchedExcerpt}) {
    return DocumentCitation(
      documentTitle: documentName,
      section: section,
      pageNumber: pageNumber,
      topic: title,
      excerpt: matchedExcerpt ?? content,
    );
  }
}

/// Structured document citation for grounding AI answers.
@immutable
class DocumentCitation {
  final String documentTitle;
  final String section;
  final int? pageNumber;
  final String topic;
  final String excerpt;

  const DocumentCitation({
    required this.documentTitle,
    required this.section,
    this.pageNumber,
    required this.topic,
    required this.excerpt,
  });

  String get formattedReference {
    if (pageNumber != null) {
      return '$documentTitle, Page $pageNumber ($section)';
    }
    return '$documentTitle ($section)';
  }

  Map<String, dynamic> toMap() => {
    'documentTitle': documentTitle,
    'section': section,
    'pageNumber': pageNumber,
    'topic': topic,
    'excerpt': excerpt,
  };

  factory DocumentCitation.fromMap(Map<String, dynamic> map) =>
      DocumentCitation(
        documentTitle: map['documentTitle'] as String,
        section: map['section'] as String,
        pageNumber: (map['pageNumber'] as num?)?.toInt(),
        topic: map['topic'] as String,
        excerpt: map['excerpt'] as String,
      );
}
