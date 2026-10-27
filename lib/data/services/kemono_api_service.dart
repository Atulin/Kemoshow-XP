import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/kemono_server.dart';
import '../models/creator.dart';
import '../models/post.dart';

/// Thrown for any non-successful interaction with the Kemono API.
class KemonoApiException implements Exception {
  const KemonoApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin, stateless wrapper around the Kemono HTTP API.
///
/// Only the endpoints needed by the slideshow are implemented.
class KemonoApiService {
  KemonoApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.parseCreatorsInIsolate = true,
  }) : _client = client ?? http.Client();

  /// The API enforces an offset step of 50 for post listings.
  static const int pageSize = 50;

  final http.Client _client;
  final Duration timeout;

  /// Whether the creator directory is JSON-decoded on a background isolate.
  /// Disabled in tests to keep them synchronous.
  final bool parseCreatorsInIsolate;

  /// Lists recent posts, optionally filtered by a search [query].
  Future<List<Post>> fetchPosts({
    required KemonoServer server,
    required String query,
    required int offset,
  }) async {
    final uri = Uri.https(server.host, '/api/v1/posts', {
      'q': query,
      'o': '$offset',
    });
    final body = await _getBody(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    final decoded = _decodeJson(body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PostMapper.fromMap)
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      return PostSearchResponseMapper.fromMap(decoded).posts;
    }
    throw const KemonoApiException('Unexpected response for post search.');
  }

  /// Lists all posts of a creator. [service] is the creator's service (e.g.
  /// `fanbox`), not the server host.
  Future<List<Post>> fetchCreatorPosts({
    required KemonoServer server,
    required String service,
    required String creatorId,
    required int offset,
  }) async {
    final uri = Uri.https(
      server.host,
      '/api/v1/$service/user/$creatorId/posts',
      {'o': '$offset'},
    );
    final body = await _getBody(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    final decoded = _decodeJson(body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PostMapper.fromMap)
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      return CreatorPostsResponseMapper.fromMap(decoded).results;
    }
    throw const KemonoApiException('Unexpected response for creator posts.');
  }

  /// Fetches a single post, including its body.
  ///
  /// Post listings omit the body, so post searches need this endpoint before
  /// the slideshow can show it.
  Future<Post?> fetchPost({
    required KemonoServer server,
    required String service,
    required String creatorId,
    required String postId,
  }) async {
    final uri = Uri.https(
      server.host,
      '/api/v1/$service/user/$creatorId/post/$postId',
    );
    final body = await _getBody(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    final decoded = _decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw const KemonoApiException('Unexpected response for a post.');
    }

    // Older API versions wrap the post in a `post` key.
    final wrapped = decoded['post'];
    final map = wrapped is Map<String, dynamic> ? wrapped : decoded;
    if (map['id'] is! String) return null;
    return PostMapper.fromMap(map);
  }

  /// Fetches the full creator directory.
  ///
  /// The endpoint has legacy `.txt` semantics: it only serves JSON when the
  /// request asks for CSS.
  Future<List<Creator>> fetchCreators({required KemonoServer server}) async {
    final uri = Uri.https(server.host, '/api/v1/creators');
    final body = await _getBody(uri, headers: const {'Accept': 'text/css'});

    final Object? decoded;
    try {
      // Decoding a multi-megabyte list is best done off the UI isolate.
      decoded = parseCreatorsInIsolate
          ? await compute<String, Object?>(jsonDecode, body)
          : jsonDecode(body);
    } on FormatException {
      throw const KemonoApiException(
        'The creator directory is not valid JSON.',
      );
    }
    if (decoded is! List) {
      throw const KemonoApiException('Unexpected creator directory format.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CreatorMapper.fromMap)
        .toList();
  }

  /// Releases the underlying HTTP connections.
  void close() => _client.close();

  Future<String> _getBody(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(timeout);
    } on TimeoutException {
      throw KemonoApiException('Request to ${uri.host} timed out.');
    } on http.ClientException catch (error) {
      throw KemonoApiException('Could not reach ${uri.host}: ${error.message}');
    }

    if (response.statusCode != 200) {
      throw KemonoApiException(
        '${uri.host} returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const KemonoApiException('The server returned invalid JSON.');
    }
  }
}
