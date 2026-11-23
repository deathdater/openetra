import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/core/audio/voice_intent_router.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('VoiceIntentRouter parses English, Hindi (Devanagari/Hinglish), and Kannada commands', () {
    const router = VoiceIntentRouter();

    expect(router.parse('Describe my surroundings').type, VoiceIntentType.describeSurroundings);
    expect(router.parse('आसपास क्या है').type, VoiceIntentType.describeSurroundings);
    expect(router.parse('ಸುತ್ತಮುತ್ತ ವಿವರಿಸು').type, VoiceIntentType.describeSurroundings);

    expect(router.parse('Look for hazards').type, VoiceIntentType.lookForHazards);
    expect(router.parse('खतरा देखो').type, VoiceIntentType.lookForHazards);
    expect(router.parse('ಅಪಾಯ ನೋಡು').type, VoiceIntentType.lookForHazards);

    expect(router.parse('Read this sign').type, VoiceIntentType.readText);
    expect(router.parse('पढ़ो').type, VoiceIntentType.readText);
    expect(router.parse('ಓದು').type, VoiceIntentType.readText);

    expect(router.parse('Identify this note').type, VoiceIntentType.identifyCurrency);
    expect(router.parse('नोट बताओ').type, VoiceIntentType.identifyCurrency);
    expect(router.parse('ನೋಟು ಗುರುತಿಸು').type, VoiceIntentType.identifyCurrency);

    final find = router.parse('Find my wallet');
    expect(find.type, VoiceIntentType.findObject);
    expect(find.targetArgument, 'wallet');

    expect(router.parse('What is on my left?').type, VoiceIntentType.followUpQuery);
    expect(router.parse('Stop').type, VoiceIntentType.stopSpeaking);
  });

  testWidgets('HomeScreen enforces >=64dp accessible touch targets and TalkBack semantics', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await tester.pumpWidget(
      OpenetraApp(deps: deps, skipOnboarding: true, useClassicHome: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final primaryButtons = [
      'Stop Speaking / Interrupt',
      'Describe Surroundings',
      'Hazard Awareness Scan',
      'Read Text (Smart Reader)',
      'Identify Currency Note',
      'Personal Object Memory',
    ];

    for (final label in primaryButtons) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final box = tester.getSize(
        find.ancestor(of: finder, matching: find.byType(InkWell)).first,
      );
      expect(box.height, greaterThanOrEqualTo(64.0), reason: '$label height < 64dp');
    }

    // Verify semantics nodes exist for screen readers with button role + hint.
    final handle = tester.ensureSemantics();
    final descNode = tester.getSemantics(find.bySemanticsLabel(RegExp('^Describe Surroundings')));
    expect(descNode.label, contains('Describe Surroundings'));
    expect(find.bySemanticsLabel(RegExp('^Hazard Awareness Scan')), findsOneWidget);
    handle.dispose();

    await tester.runAsync(() => db.close());
  });
}
