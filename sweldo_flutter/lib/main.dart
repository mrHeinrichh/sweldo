import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'core/config/app_config.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final store = await LocalStore.open();
  runApp(SweldoApp(dependencies: AppDependencies.create(config, store)));
}
