import 'package:flutter/material.dart';

import 'data/repositories/kemono_repository.dart';
import 'data/services/kemono_api_service.dart';
import 'ui/features/search/views/search_page.dart';

class KemoShowApp extends StatefulWidget {
  const KemoShowApp({super.key});

  @override
  State<KemoShowApp> createState() => _KemoShowAppState();
}

class _KemoShowAppState extends State<KemoShowApp> {
  late final KemonoRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = KemonoRepository(KemonoApiService());
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF7A45),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'KemoShow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
      home: SearchPage(repository: _repository),
    );
  }
}
