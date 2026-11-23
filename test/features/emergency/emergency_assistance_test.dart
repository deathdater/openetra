import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/audio/voice_intent_router.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/emergency/bloc/emergency_bloc.dart';
import 'package:openetra/features/emergency/data/protected_contact_store.dart';
import 'package:openetra/features/emergency/domain/emergency_assistance_service.dart';
import 'package:openetra/features/emergency/domain/trusted_contact.dart';
import 'package:openetra/features/emergency/presentation/emergency_assistance_screen.dart';
import 'package:openetra/features/settings/bloc/settings_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('TrustedContact redacts full phone numbers in maskedPhone() and toString()', () {
    const c1 = TrustedContact(
      id: 'c1',
      name: 'Anita',
      phoneNumber: '+919876543210',
      relationship: 'Sister',
      isPrimary: true,
    );
    expect(c1.maskedPhone(), '***3210');
    expect(c1.toString(), isNot(contains('+919876543210')));
    expect(c1.toString(), isNot(contains('98765432')));
    expect(c1.toString(), contains('***3210'));

    const cShort = TrustedContact(
      id: 'c2',
      name: 'Helpdesk',
      phoneNumber: '112',
    );
    expect(cShort.maskedPhone(), '****');
    expect(cShort.toString(), isNot(contains('112')));
  });

  test('EmergencyAssistanceService validates numbers, manages primary contact, and clears via SettingsBloc', () async {
    final tempDir = Directory.systemTemp.createTempSync('openetra_emerg_test_');
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: p.join(tempDir.path, 'openetra.db'),
    );
    addTearDown(() async {
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final store = InMemoryProtectedContactStore();
    final service = EmergencyAssistanceService(store: store, database: db);

    await expectLater(
      service.addOrUpdateContact(name: '  ', phoneNumber: '+919876543210'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.addOrUpdateContact(name: 'Invalid', phoneNumber: '12'),
      throwsA(isA<FormatException>()),
    );

    final list1 = await service.addOrUpdateContact(
      name: 'Anita',
      phoneNumber: '+91 98765-43210',
      relationship: 'Sister',
    );
    expect(list1.single.isPrimary, isTrue);
    expect(list1.single.phoneNumber, '+919876543210');

    final list2 = await service.addOrUpdateContact(
      name: 'Ramesh',
      phoneNumber: '+919900112233',
      makePrimary: true,
    );
    expect(list2.length, 2);
    expect(list2.firstWhere((c) => c.name == 'Anita').isPrimary, isFalse);
    expect(list2.firstWhere((c) => c.name == 'Ramesh').isPrimary, isTrue);

    final firstId = list2.firstWhere((c) => c.name == 'Anita').id;
    final switched = await service.setPrimaryContact(firstId);
    expect(switched.firstWhere((c) => c.id == firstId).isPrimary, isTrue);

    final afterRemove = await service.removeContact(firstId);
    expect(afterRemove.single.name, 'Ramesh');
    expect(afterRemove.single.isPrimary, isTrue);

    final emergBloc = EmergencyBloc(service: service);
    addTearDown(emergBloc.close);
    final settingsBloc = SettingsBloc(
      database: db,
      onClearProtectedStorage: () async {
        await service.clearAllContacts();
        emergBloc.add(const LoadEmergencyConfig());
      },
    );
    addTearDown(settingsBloc.close);

    settingsBloc.add(const DeleteAllUserDataRequested());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await service.loadContacts(), isEmpty);
  });

  test('EmergencyBloc enforces explicit confirmation, supports dry-run test, and degrades honestly', () async {
    final store = InMemoryProtectedContactStore();
    final service = EmergencyAssistanceService(store: store);
    final bloc = EmergencyBloc(service: service);
    addTearDown(bloc.close);

    // 1. Unconfigured contacts -> prompts setup, never opens dialer.
    bloc.add(const LoadEmergencyConfig());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    bloc.add(const RequestEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.needsContactSetup, isTrue);
    expect(bloc.state.awaitingConfirmation, isFalse);
    expect(store.dialerLaunchCount, 0);

    // 2. Add contact -> RequestEmergencyInitiation enters confirmation, does NOT dial yet.
    bloc.add(const AddOrUpdateTrustedContact(
      name: 'Caregiver',
      phoneNumber: '+919811223344',
      makePrimary: true,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    bloc.add(const RequestEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.awaitingConfirmation, isTrue);
    expect(bloc.state.statusMessage, contains('***3344'));
    expect(store.dialerLaunchCount, 0);

    // 3. Cancel aborts immediately with 0 dialer launches.
    bloc.add(const CancelEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.awaitingConfirmation, isFalse);
    expect(store.dialerLaunchCount, 0);

    // 4. Dry-run verification mode exercises flow without opening dialer.
    bloc.add(const RequestEmergencyInitiation(isDryRun: true));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.awaitingConfirmation, isTrue);
    expect(bloc.state.pendingIsDryRun, isTrue);
    bloc.add(const ConfirmEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.awaitingConfirmation, isFalse);
    expect(bloc.state.statusMessage, contains('No call was placed'));
    expect(store.dialerLaunchCount, 0);

    // 5. Airplane mode warning surfaced honestly while still handing off to dialer on confirm.
    store.capabilities = const EmergencyCapabilities(
      airplaneMode: true,
      dialerAvailable: true,
      telephonyAvailable: false,
    );
    bloc.add(const RequestEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.statusMessage, contains('Airplane mode'));
    bloc.add(const ConfirmEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(store.dialerLaunchCount, 1);
    expect(store.lastDialedNumber, '+919811223344');

    // 6. Missing dialer refuses gracefully without erroring or counting a launch.
    store.capabilities = const EmergencyCapabilities(
      airplaneMode: false,
      dialerAvailable: false,
      telephonyAvailable: false,
    );
    bloc.add(const RequestEmergencyInitiation());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.awaitingConfirmation, isFalse);
    expect(bloc.state.needsContactSetup, isTrue);
    expect(store.dialerLaunchCount, 1);
  });

  test('VoiceIntentRouter parses English and Hindi emergency & flashlight phrases', () {
    const router = VoiceIntentRouter();
    expect(router.parse('emergency help please').type, VoiceIntentType.emergencyAssistance);
    expect(router.parse('आपातकाल मदद').type, VoiceIntentType.emergencyAssistance);
    expect(router.parse('turn flashlight on').type, VoiceIntentType.toggleFlashlight);
    expect(router.parse('टॉर्च चालू करो').type, VoiceIntentType.toggleFlashlight);
  });

  testWidgets('EmergencyAssistanceScreen + EmergencyContactsScreen support accessible contact setup and confirmed dialer flow', (tester) async {
    final store = InMemoryProtectedContactStore();
    final service = EmergencyAssistanceService(store: store);
    final bloc = EmergencyBloc(service: service)..add(const LoadEmergencyConfig());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider<EmergencyBloc>.value(
        value: bloc,
        child: const MaterialApp(
          home: EmergencyAssistanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No trusted emergency contact configured'), findsOneWidget);

    await tester.ensureVisible(find.text('Configure Trusted Contacts'));
    await tester.tap(find.text('Configure Trusted Contacts'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Meera');
    await tester.enterText(find.byType(TextField).at(1), '+919800001122');
    await tester.ensureVisible(find.text('Save Trusted Contact'));
    await tester.tap(find.text('Save Trusted Contact'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Saved Contacts (1)'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.textContaining('Saved Contacts (1)'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test Emergency Flow (No Real Call)'));
    await tester.tap(find.text('Test Emergency Flow (No Real Call)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Safe Test (No Call Placed)'));
    await tester.pumpAndSettle();
    expect(store.dialerLaunchCount, 0);

    await tester.tap(find.text('Call Trusted Contact (Open Dialer)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm: Open Phone Dialer Now'));
    await tester.pumpAndSettle();
    expect(store.dialerLaunchCount, 1);
    expect(store.lastDialedNumber, '+919800001122');
  });
}
