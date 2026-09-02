import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/app_theme.dart';
import 'services/xtream_service.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const AssistifyApp());
}

class AssistifyApp extends StatelessWidget {
  const AssistifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final xtream = XtreamService();
    final storage = StorageService();

    return MaterialApp(
      title: 'Assistify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: LoginScreen(xtream: xtream, storage: storage),
    );
  }
}
