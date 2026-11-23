import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/openetra_database.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class UpdatePreferredLanguage extends SettingsEvent {
  const UpdatePreferredLanguage(this.locale);
  final String locale;

  @override
  List<Object?> get props => [locale];
}

class UpdateSpeechRate extends SettingsEvent {
  const UpdateSpeechRate(this.rate);
  final double rate;

  @override
  List<Object?> get props => [rate];
}

class CompleteOnboarding extends SettingsEvent {
  const CompleteOnboarding();
}

class DeleteAllUserDataRequested extends SettingsEvent {
  const DeleteAllUserDataRequested();
}

class UpdateThemeMode extends SettingsEvent {
  const UpdateThemeMode(this.themeMode);
  final ThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

class SettingsState extends Equatable {
  const SettingsState({
    this.preferences = const UserPreferencesRecord(),
    this.themeMode = ThemeMode.dark,
    this.isLoaded = false,
    this.statusMessage,
  });

  final UserPreferencesRecord preferences;
  final ThemeMode themeMode;
  final bool isLoaded;
  final String? statusMessage;

  @override
  List<Object?> get props => [preferences, themeMode, isLoaded, statusMessage];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String prefThemeModeKey = 'ui_theme_mode';

  SettingsBloc({
    required this.database,
    this.onClearProtectedStorage,
  }) : super(const SettingsState()) {
    on<LoadSettings>(_onLoad);
    on<UpdatePreferredLanguage>(_onUpdateLanguage);
    on<UpdateSpeechRate>(_onUpdateSpeechRate);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<CompleteOnboarding>(_onCompleteOnboarding);
    on<DeleteAllUserDataRequested>(_onDeleteAllData);
  }

  final OpenetraDatabase database;
  final Future<void> Function()? onClearProtectedStorage;

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> _onLoad(LoadSettings event, Emitter<SettingsState> emit) async {
    final prefs = await database.loadPreferences();
    final rawTheme = await database.getAssistivePreference(prefThemeModeKey);
    emit(SettingsState(
      preferences: prefs,
      themeMode: _parseThemeMode(rawTheme),
      isLoaded: true,
    ));
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    await database.setAssistivePreference(
      prefThemeModeKey,
      event.themeMode.name,
    );
    final label = switch (event.themeMode) {
      ThemeMode.dark => 'Dark Aubergine',
      ThemeMode.light => 'Warm White Light',
      ThemeMode.system => 'System Default',
    };
    emit(SettingsState(
      preferences: state.preferences,
      themeMode: event.themeMode,
      isLoaded: true,
      statusMessage: 'Theme switched to $label',
    ));
  }

  Future<void> _onUpdateLanguage(
    UpdatePreferredLanguage event,
    Emitter<SettingsState> emit,
  ) async {
    final next = state.preferences.copyWith(preferredLanguage: event.locale);
    await database.savePreferences(next);
    emit(SettingsState(
      preferences: next,
      themeMode: state.themeMode,
      isLoaded: true,
      statusMessage: 'Language switched to ${event.locale}',
    ));
  }

  Future<void> _onUpdateSpeechRate(
    UpdateSpeechRate event,
    Emitter<SettingsState> emit,
  ) async {
    final next = state.preferences.copyWith(speechRate: event.rate.clamp(0.35, 1.0));
    await database.savePreferences(next);
    emit(SettingsState(
      preferences: next,
      themeMode: state.themeMode,
      isLoaded: true,
      statusMessage: 'Speech speed updated',
    ));
  }

  Future<void> _onCompleteOnboarding(
    CompleteOnboarding event,
    Emitter<SettingsState> emit,
  ) async {
    final next = state.preferences.copyWith(
      onboardingCompleted: true,
      safetyDisclaimerAccepted: true,
    );
    await database.savePreferences(next);
    emit(SettingsState(
      preferences: next,
      themeMode: state.themeMode,
      isLoaded: true,
      statusMessage: 'Setup complete',
    ));
  }

  Future<void> _onDeleteAllData(
    DeleteAllUserDataRequested event,
    Emitter<SettingsState> emit,
  ) async {
    await database.deleteAllUserData();
    await onClearProtectedStorage?.call();
    emit(SettingsState(
      preferences: state.preferences,
      themeMode: ThemeMode.dark,
      isLoaded: true,
      statusMessage: 'All personal objects, scanned documents, history, and safety logs deleted.',
    ));
  }
}
