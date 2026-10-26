import 'package:dart_mappable/dart_mappable.dart';

part 'creator.mapper.dart';

/// An author/artist as returned by `/api/v1/creators`.
///
/// The `indexed`/`updated` timestamps are intentionally not modelled: nothing
/// in the UI needs them and they have been observed both as numbers and
/// strings across servers.
@MappableClass()
class Creator with CreatorMappable {
  const Creator({
    required this.id,
    required this.service,
    this.name,
    this.favorited = 0,
  });

  /// Server-specific creator ID.
  final String id;

  /// Service the creator belongs to, e.g. `fanbox` or `patreon`.
  final String service;

  final String? name;

  final int favorited;

  /// Name to show in listings, falling back to the ID.
  String get displayName {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? id : trimmed;
  }

  static const fromMap = CreatorMapper.fromMap;
  static const fromJson = CreatorMapper.fromJson;
}
