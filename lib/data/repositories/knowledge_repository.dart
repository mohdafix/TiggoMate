import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/knowledge_document.dart';

class KnowledgeSearchResult {
  final KnowledgeChunk chunk;
  final double score;
  final String matchedSnippet;

  const KnowledgeSearchResult({
    required this.chunk,
    required this.score,
    required this.matchedSnippet,
  });
}

class KnowledgeBaseStatus {
  final int totalChunks;
  final String market;
  final String documentTitle;
  final bool isIndexed;
  final List<String> availableTopics;

  const KnowledgeBaseStatus({
    required this.totalChunks,
    required this.market,
    required this.documentTitle,
    required this.isIndexed,
    required this.availableTopics,
  });
}

class KnowledgeRepository {
  List<KnowledgeChunk> _chunks = [];
  bool _isInitialized = false;

  KnowledgeRepository();

  bool get isInitialized => _isInitialized;

  /// Ingests documents from Flutter assets bundle.
  Future<void> initialize({
    String assetPath = 'assets/knowledge/tiggo7_phev_knowledge.json',
  }) async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final list = json.decode(jsonString) as List<dynamic>;
      _chunks = list
          .map((item) => KnowledgeChunk.fromMap(item as Map<String, dynamic>))
          .toList();
      _isInitialized = true;
    } catch (e) {
      // Fallback in test environments or if assets fail
      _chunks = _buildFallbackChunks();
      _isInitialized = true;
    }
  }

  void loadDirectChunks(List<KnowledgeChunk> chunks) {
    _chunks = chunks;
    _isInitialized = true;
  }

  KnowledgeBaseStatus getStatus() {
    return KnowledgeBaseStatus(
      totalChunks: _chunks.length,
      market: 'Malaysia',
      documentTitle:
          'Chery Tiggo 7 PHEV Malaysian Market Guide & Owner\'s Handbook',
      isIndexed: _isInitialized,
      availableTopics: _chunks.map((c) => c.title).toList(),
    );
  }

  /// Ranks and retrieves the most relevant documentation chunks for a query.
  List<KnowledgeSearchResult> search(String query, {int limit = 3}) {
    if (_chunks.isEmpty || query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase();
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();

    final results = <KnowledgeSearchResult>[];

    for (final chunk in _chunks) {
      double score = 0.0;
      final titleLower = chunk.title.toLowerCase();
      final contentLower = chunk.content.toLowerCase();
      final tagsLower = chunk.tags.map((t) => t.toLowerCase()).toList();

      // Exact phrase match in title
      if (titleLower.contains(normalizedQuery)) {
        score += 5.0;
      }

      // Exact phrase match in content
      if (contentLower.contains(normalizedQuery)) {
        score += 3.0;
      }

      // Token matching
      for (final token in tokens) {
        if (titleLower.contains(token)) score += 2.0;
        if (tagsLower.any((t) => t.contains(token))) score += 2.5;
        if (contentLower.contains(token)) score += 1.0;
      }

      if (score > 0) {
        // Extract snippet
        String snippet = chunk.content;
        final firstMatchIdx = contentLower.indexOf(
          tokens.isNotEmpty ? tokens.first : '',
        );
        if (firstMatchIdx != -1 && snippet.length > 150) {
          final start = (firstMatchIdx - 40).clamp(0, snippet.length);
          final end = (firstMatchIdx + 110).clamp(0, snippet.length);
          snippet = '...${snippet.substring(start, end)}...';
        }

        results.add(
          KnowledgeSearchResult(
            chunk: chunk,
            score: score,
            matchedSnippet: snippet,
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  List<KnowledgeChunk> _buildFallbackChunks() {
    return const [
      KnowledgeChunk(
        id: 'csh_powertrain_fallback',
        title: 'Chery Tiggo 7 PHEV CSH Powertrain & Architecture',
        section: 'Powertrain & Specifications',
        documentName:
            'Chery Tiggo 7 PHEV Malaysian Market Guide & Owner\'s Handbook',
        pageNumber: 12,
        market: 'Malaysia',
        content:
            'The Malaysian Chery Tiggo 7 PHEV CSH features a 1.5L TCI turbo hybrid engine (156 PS / 230 Nm) and dual electric motors via 3DHT transmission. Battery capacity is 19.27 kWh giving ~80-100 km EV range. Total output is 326 PS / 545 Nm.',
        tags: [
          'powertrain',
          'engine',
          'electric motor',
          'battery',
          'range',
          'specifications',
          '3dht',
        ],
      ),
      KnowledgeChunk(
        id: 'auto_mode_fallback',
        title: 'Hybrid Driving Modes: AUTO, EV, and HEV Operation',
        section: 'Driving & Operating Modes',
        documentName:
            'Chery Tiggo 7 PHEV Malaysian Market Guide & Owner\'s Handbook',
        pageNumber: 28,
        market: 'Malaysia',
        content:
            'In AUTO mode, the car intelligently manages the 1.5T engine and dual electric motors. The petrol engine stays off at low speeds and moderate load when battery SOC is adequate (>20-25%). Engine start triggers on high throttle, low SOC, steep climbs, or AC heating demand.',
        tags: [
          'auto mode',
          'ev mode',
          'hev mode',
          'driving mode',
          'engine start',
          'battery level',
        ],
      ),
    ];
  }
}
