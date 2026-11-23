import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/storage/openetra_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await OpenetraDatabase.open();
  final deps = await OpenetraDependencies.bootstrap(database: database);
  runApp(OpenetraApp(deps: deps));
}
