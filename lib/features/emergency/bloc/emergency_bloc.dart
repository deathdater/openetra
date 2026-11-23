import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/emergency_assistance_service.dart';
import '../domain/trusted_contact.dart';

abstract class EmergencyEvent extends Equatable {
  const EmergencyEvent();

  @override
  List<Object?> get props => [];
}

class LoadEmergencyConfig extends EmergencyEvent {
  const LoadEmergencyConfig();
}

class AddOrUpdateTrustedContact extends EmergencyEvent {
  const AddOrUpdateTrustedContact({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.makePrimary = false,
  });

  final String? id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final bool makePrimary;

  @override
  List<Object?> get props => [id, name, phoneNumber, relationship, makePrimary];
}

class SelectPrimaryTrustedContact extends EmergencyEvent {
  const SelectPrimaryTrustedContact(this.contactId);
  final String contactId;

  @override
  List<Object?> get props => [contactId];
}

class RemoveTrustedContact extends EmergencyEvent {
  const RemoveTrustedContact(this.contactId);
  final String contactId;

  @override
  List<Object?> get props => [contactId];
}

class UpdateEmergencyActionMode extends EmergencyEvent {
  const UpdateEmergencyActionMode(this.mode);
  final EmergencyActionMode mode;

  @override
  List<Object?> get props => [mode];
}

class RequestEmergencyInitiation extends EmergencyEvent {
  const RequestEmergencyInitiation({this.isDryRun = false});
  final bool isDryRun;

  @override
  List<Object?> get props => [isDryRun];
}

class ConfirmEmergencyInitiation extends EmergencyEvent {
  const ConfirmEmergencyInitiation();
}

class CancelEmergencyInitiation extends EmergencyEvent {
  const CancelEmergencyInitiation();
}

class EmergencyState extends Equatable {
  const EmergencyState({
    this.contacts = const [],
    this.actionMode = EmergencyActionMode.openDialer,
    this.capabilities = const EmergencyCapabilities(
      airplaneMode: false,
      dialerAvailable: true,
      telephonyAvailable: true,
    ),
    this.awaitingConfirmation = false,
    this.pendingIsDryRun = false,
    this.statusMessage,
    this.needsContactSetup = false,
  });

  final List<TrustedContact> contacts;
  final EmergencyActionMode actionMode;
  final EmergencyCapabilities capabilities;
  final bool awaitingConfirmation;
  final bool pendingIsDryRun;
  final String? statusMessage;
  final bool needsContactSetup;

  TrustedContact? get primaryContact {
    if (contacts.isEmpty) return null;
    return contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => contacts.first,
    );
  }

  EmergencyState copyWith({
    List<TrustedContact>? contacts,
    EmergencyActionMode? actionMode,
    EmergencyCapabilities? capabilities,
    bool? awaitingConfirmation,
    bool? pendingIsDryRun,
    String? statusMessage,
    bool? needsContactSetup,
  }) {
    return EmergencyState(
      contacts: contacts ?? this.contacts,
      actionMode: actionMode ?? this.actionMode,
      capabilities: capabilities ?? this.capabilities,
      awaitingConfirmation: awaitingConfirmation ?? this.awaitingConfirmation,
      pendingIsDryRun: pendingIsDryRun ?? this.pendingIsDryRun,
      statusMessage: statusMessage,
      needsContactSetup: needsContactSetup ?? this.needsContactSetup,
    );
  }

  @override
  List<Object?> get props => [
        contacts,
        actionMode,
        capabilities,
        awaitingConfirmation,
        pendingIsDryRun,
        statusMessage,
        needsContactSetup,
      ];
}

class EmergencyBloc extends Bloc<EmergencyEvent, EmergencyState> {
  EmergencyBloc({required this.service}) : super(const EmergencyState()) {
    on<LoadEmergencyConfig>(_onLoad);
    on<AddOrUpdateTrustedContact>(_onSaveContact);
    on<SelectPrimaryTrustedContact>(_onSelectPrimary);
    on<RemoveTrustedContact>(_onRemove);
    on<UpdateEmergencyActionMode>(_onUpdateMode);
    on<RequestEmergencyInitiation>(_onRequestInitiation);
    on<ConfirmEmergencyInitiation>(_onConfirm);
    on<CancelEmergencyInitiation>(_onCancel);
  }

  final EmergencyAssistanceService service;

  Future<void> _onLoad(
    LoadEmergencyConfig event,
    Emitter<EmergencyState> emit,
  ) async {
    try {
      final contacts = await service.loadContacts();
      final mode = await service.loadPreferredMode();
      final caps = await service.checkCapabilities();
      emit(state.copyWith(
        contacts: contacts,
        actionMode: mode,
        capabilities: caps,
        needsContactSetup: contacts.isEmpty,
      ));
    } catch (_) {
      emit(state.copyWith(
        statusMessage:
            'Protected contact storage could not be read; please add or re-verify emergency contacts.',
        needsContactSetup: true,
      ));
    }
  }

  Future<void> _onSaveContact(
    AddOrUpdateTrustedContact event,
    Emitter<EmergencyState> emit,
  ) async {
    try {
      final list = await service.addOrUpdateContact(
        id: event.id,
        name: event.name,
        phoneNumber: event.phoneNumber,
        relationship: event.relationship,
        makePrimary: event.makePrimary,
      );
      final primary = service.selectPrimaryContact(list);
      emit(state.copyWith(
        contacts: list,
        needsContactSetup: list.isEmpty,
        statusMessage: primary != null
            ? 'Saved trusted contact ${primary.name} (${primary.maskedPhone()}).'
            : 'Saved trusted contact.',
      ));
    } on FormatException catch (e) {
      emit(state.copyWith(statusMessage: e.message));
    }
  }

  Future<void> _onSelectPrimary(
    SelectPrimaryTrustedContact event,
    Emitter<EmergencyState> emit,
  ) async {
    final list = await service.setPrimaryContact(event.contactId);
    final primary = service.selectPrimaryContact(list);
    emit(state.copyWith(
      contacts: list,
      statusMessage: primary != null
          ? 'Primary contact set to ${primary.name} (${primary.maskedPhone()}).'
          : null,
    ));
  }

  Future<void> _onRemove(
    RemoveTrustedContact event,
    Emitter<EmergencyState> emit,
  ) async {
    final list = await service.removeContact(event.contactId);
    emit(state.copyWith(
      contacts: list,
      needsContactSetup: list.isEmpty,
      statusMessage: 'Trusted contact removed.',
    ));
  }

  Future<void> _onUpdateMode(
    UpdateEmergencyActionMode event,
    Emitter<EmergencyState> emit,
  ) async {
    await service.savePreferredMode(event.mode);
    emit(state.copyWith(
      actionMode: event.mode,
      statusMessage: event.mode == EmergencyActionMode.openDialer
          ? 'Emergency mode set to open Android dialer with confirmation.'
          : 'Emergency mode set to test verification only.',
    ));
  }

  Future<void> _onRequestInitiation(
    RequestEmergencyInitiation event,
    Emitter<EmergencyState> emit,
  ) async {
    final prep =
        await service.prepareConfirmationPrompt(isDryRun: event.isDryRun);
    if (!prep.success) {
      emit(state.copyWith(
        awaitingConfirmation: false,
        pendingIsDryRun: false,
        needsContactSetup: prep.requiresUserConfiguration,
        statusMessage: prep.spokenMessage,
      ));
      return;
    }
    emit(state.copyWith(
      awaitingConfirmation: true,
      pendingIsDryRun: event.isDryRun,
      needsContactSetup: false,
      statusMessage: prep.spokenMessage,
    ));
  }

  Future<void> _onConfirm(
    ConfirmEmergencyInitiation event,
    Emitter<EmergencyState> emit,
  ) async {
    final outcome = await service.executeConfirmedAction(
      isDryRun: state.pendingIsDryRun,
    );
    emit(state.copyWith(
      awaitingConfirmation: false,
      pendingIsDryRun: false,
      needsContactSetup: outcome.requiresUserConfiguration,
      statusMessage: outcome.spokenMessage,
    ));
  }

  void _onCancel(
    CancelEmergencyInitiation event,
    Emitter<EmergencyState> emit,
  ) {
    emit(state.copyWith(
      awaitingConfirmation: false,
      pendingIsDryRun: false,
      statusMessage: 'Emergency assistance cancelled. No call was placed.',
    ));
  }
}
