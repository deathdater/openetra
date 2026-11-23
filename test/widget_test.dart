import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('Openetra boots into accessible onboarding screen', (tester) async {
    late OpenetraDatabase db;
    late OpenetraDependencies deps;
    await tester.runAsync(() async {
      db = await OpenetraDatabase.open(
        factory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      deps = await OpenetraDependencies.bootstrap(
        database: db,
        enablePlatformTts: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(OpenetraApp(deps: deps));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome to Openetra'), findsOneWidget);
    expect(find.text('Accept Safety Notice & Start Openetra'), findsOneWidget);

    await tester.runAsync(() => db.close());
  });
}
