import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();
  await Hive.openBox('homeCache');
  await Hive.openBox('tableConfig');
  await Hive.openBox('userPreferences');

  runApp(
    const ProviderScope(
      child: YangJiApp(),
    ),
  );
}
