import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/favourite.dart';

/// Persists the user's favourite post searches and authors.
abstract interface class FavouritesStore {
  Future<List<Favourite>> load();

  Future<void> save(List<Favourite> favourites);
}

/// Stores the favourites as a JSON list in the platform's shared preferences.
class SharedPreferencesFavouritesStore implements FavouritesStore {
  /// Versioned key; bump it if the serialized shape ever changes.
  @visibleForTesting
  static const String storageKey = 'favourites.v1';

  @override
  Future<List<Favourite>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final favourites = <Favourite>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final json = <String, Object?>{
          for (final mapEntry in entry.entries)
            '${mapEntry.key}': mapEntry.value,
        };
        final favourite = Favourite.fromJson(json);
        if (favourite == null || favourites.contains(favourite)) continue;
        favourites.add(favourite);
      }
      return favourites;
    } catch (error) {
      // A truncated or hand-edited value must not break the whole app.
      debugPrint('Could not read favourites: $error');
      return const [];
    }
  }

  @override
  Future<void> save(List<Favourite> favourites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final favourite in favourites) favourite.toJson()]),
    );
  }
}
