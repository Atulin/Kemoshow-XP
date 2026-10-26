import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Required by package:media_kit before any Player is created.
  MediaKit.ensureInitialized();
  runApp(const KemoShowApp());
}
