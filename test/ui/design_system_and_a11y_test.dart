import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/app/app.dart';
import 'package:openetra/app/theme.dart';
import 'package:openetra/core/storage/openetra_database.dart';
import 'package:openetra/features/dial/models/dial_menu_node.dart';
import 'package:openetra/features/dial/presentation/widgets/dial_center.dart';
import 'package:openetra/features/settings/bloc/settings_bloc.dart';
import 'package:openetra/features/settings/presentation/settings_screen.dart';
import 'package:openetra/shared/widgets/openetra_components.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

double _relativeLuminance(Color c) {
  double lin(int ch) {
    final s = ch / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue);
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('Dark and Light OpenetraPalettes satisfy WCAG AAA (>=7:1) body text and >=4.5:1 accent contrast', () {
    for (final p in const [OpenetraPalette.dark, OpenetraPalette.light]) {
      expect(_contrastRatio(p.textPrimary, p.background), greaterThanOrEqualTo(7.0));
      expect(_contrastRatio(p.textPrimary, p.surface), greaterThanOrEqualTo(7.0));
      expect(_contrastRatio(p.textPrimary, p.surfaceElevated), greaterThanOrEqualTo(7.0));
      expect(_contrastRatio(p.textSecondary, p.background), greaterThanOrEqualTo(7.0));
      expect(_contrastRatio(p.onAccent, p.secondary), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(p.onAccent, p.primary), greaterThanOrEqualTo(4.5));
    }
  });

  test('SettingsBloc persists ThemeMode offline in SQLite assistive_preferences', () async {
    final db = await OpenetraDatabase.open(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );

    final bloc1 = SettingsBloc(database: db)..add(const LoadSettings());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc1.state.themeMode, ThemeMode.dark);

    bloc1.add(const UpdateThemeMode(ThemeMode.light));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc1.state.themeMode, ThemeMode.light);
    await bloc1.close();

    // Reload from same DB -> Light mode persisted
    final bloc2 = SettingsBloc(database: db)..add(const LoadSettings());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc2.state.themeMode, ThemeMode.light);
    await bloc2.close();
    await db.close();
  });

  testWidgets('OpenetraApp switches live between Dark Aubergine and Warm White Light themes without overflow at 2.0x text scale', (tester) async {
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
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: OpenetraApp(deps: deps, skipOnboarding: true),
      ),
    );
    await tester.pumpAndSettle();

    // Default dark theme renders Offline Ready badge and dial cleanly at 2.0x text scale
    expect(find.text('Offline Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch to Warm White Light theme
    await tester.runAsync(() async {
      deps.settingsBloc.add(const UpdateThemeMode(ThemeMode.light));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final ctx = tester.element(find.byWidget(scaffold));
    expect(OpenetraTheme.paletteOf(ctx).background, OpenetraPalette.light.background);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() => db.close());
  });

  testWidgets('OpenetraMotion honors system disableAnimations and SettingsScreen renders Appearance + collapsible Language UX', (tester) async {
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
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: OpenetraTheme.buildLightTheme(),
          home: Builder(
            builder: (ctx) {
              expect(
                OpenetraMotion.resolve(ctx, OpenetraMotion.normal),
                Duration.zero,
              );
              return const Scaffold(
                body: Column(
                  children: [
                    OpenetraSectionHeader(title: 'Test Section'),
                    OpenetraStatusBadge(
                      label: 'Offline Ready',
                      icon: Icons.offline_pin_outlined,
                      tone: OpenetraBadgeTone.success,
                    ),
                    OpenetraEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Empty',
                      message: 'Nothing here yet.',
                    ),
                    DialCenter(
                      phase: DialLifecyclePhase.processing,
                      glyph: DialGlyphKind.eyeIris,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Test Section'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);

    // Verify SettingsScreen theme chips and collapsible language selector
    await tester.pumpWidget(
      OpenetraApp(deps: deps, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Warm White Light'), findsOneWidget);
    expect(find.text('Language: English (India)'), findsOneWidget);

    await tester.tap(find.text('Warm White Light'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(deps.settingsBloc.state.themeMode, ThemeMode.light);

    await tester.runAsync(() => db.close());
  });
}
