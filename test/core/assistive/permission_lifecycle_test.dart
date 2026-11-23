import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/assistive/permission_coordinator.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TrackingPermissionGateway implements PermissionGateway {
  _TrackingPermissionGateway(this.states);

  final Map<OpenetraPermission, PermissionGrantState> states;
  final List<OpenetraPermission> requested = [];
  int openSettingsCount = 0;

  @override
  Future<PermissionGrantState> check(OpenetraPermission permission) async =>
      states[permission] ?? PermissionGrantState.denied;

  @override
  Future<PermissionGrantState> request(OpenetraPermission permission) async {
    requested.add(permission);
    states[permission] = PermissionGrantState.granted;
    return PermissionGrantState.granted;
  }

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCount++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'OpenetraApp checks permissions on start, explains why they are required, requests them, and re-checks on resume',
    (tester) async {
      late OpenetraDatabase db;
      late OpenetraDependencies deps;
      final gateway = _TrackingPermissionGateway({
        OpenetraPermission.camera: PermissionGrantState.denied,
        OpenetraPermission.microphone: PermissionGrantState.denied,
        OpenetraPermission.notifications: PermissionGrantState.granted,
      });

      await tester.runAsync(() async {
        db = await OpenetraDatabase.open(
          factory: databaseFactoryFfi,
          dbPath: inMemoryDatabasePath,
        );
        deps = await OpenetraDependencies.bootstrap(
          database: db,
          permissionGateway: gateway,
          enablePlatformTts: false,
        );
      });

      await tester.pumpWidget(OpenetraApp(deps: deps, skipOnboarding: true));
      await tester.pumpAndSettle();

      // Startup dialog appears explaining missing Camera and Microphone permissions
      expect(find.text('Permissions Required'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);
      expect(
        find.text(PermissionCoordinator.explanationFor(OpenetraPermission.camera)),
        findsOneWidget,
      );
      expect(
        find.text(PermissionCoordinator.explanationFor(OpenetraPermission.microphone)),
        findsOneWidget,
      );
      // Notifications was already granted, so not listed
      expect(find.text('Notifications'), findsNothing);

      // User taps Allow Permissions -> requests Camera and Microphone
      await tester.tap(find.text('Allow Permissions'));
      await tester.pumpAndSettle();

      expect(
        gateway.requested,
        containsAll([OpenetraPermission.camera, OpenetraPermission.microphone]),
      );
      expect(find.text('Permissions Required'), findsNothing);

      // Simulate user revoking Camera in Android Settings (permanently denied)
      // and returning to the app after the debounce window.
      gateway.states[OpenetraPermission.camera] =
          PermissionGrantState.permanentlyDenied;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1600));
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Permissions Required'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(gateway.openSettingsCount, 1);

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await db.close();
      });
    },
  );

  testWidgets(
    'OpenetraApp shows no permission dialog when all core permissions are already granted',
    (tester) async {
      late OpenetraDatabase db;
      late OpenetraDependencies deps;
      final gateway = _TrackingPermissionGateway({
        OpenetraPermission.camera: PermissionGrantState.granted,
        OpenetraPermission.microphone: PermissionGrantState.granted,
        OpenetraPermission.notifications: PermissionGrantState.granted,
      });

      await tester.runAsync(() async {
        db = await OpenetraDatabase.open(
          factory: databaseFactoryFfi,
          dbPath: inMemoryDatabasePath,
        );
        deps = await OpenetraDependencies.bootstrap(
          database: db,
          permissionGateway: gateway,
          enablePlatformTts: false,
        );
      });

      await tester.pumpWidget(OpenetraApp(deps: deps, skipOnboarding: true));
      await tester.pumpAndSettle();

      expect(find.text('Permissions Required'), findsNothing);
      expect(gateway.requested, isEmpty);

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await db.close();
      });
    },
  );
}
