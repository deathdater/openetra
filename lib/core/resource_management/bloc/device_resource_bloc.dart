import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/entities.dart';
import '../device_resource_manager.dart';

abstract class DeviceResourceEvent extends Equatable {
  const DeviceResourceEvent();

  @override
  List<Object?> get props => [];
}

class RefreshDeviceResources extends DeviceResourceEvent {
  const RefreshDeviceResources();
}

class ChangeOperatingMode extends DeviceResourceEvent {
  const ChangeOperatingMode(this.mode);
  final OperatingMode mode;

  @override
  List<Object?> get props => [mode];
}

class DeviceResourceBlocState extends Equatable {
  const DeviceResourceBlocState({
    required this.resourceState,
    this.offlineVoiceSupport = const {},
  });

  final DeviceResourceState resourceState;
  final Map<String, bool> offlineVoiceSupport;

  @override
  List<Object?> get props => [resourceState, offlineVoiceSupport];
}

class DeviceResourceBloc
    extends Bloc<DeviceResourceEvent, DeviceResourceBlocState> {
  DeviceResourceBloc({required this.resourceManager})
      : super(DeviceResourceBlocState(resourceState: resourceManager.currentState)) {
    on<RefreshDeviceResources>(_onRefresh);
    on<ChangeOperatingMode>(_onChangeMode);
  }

  final DeviceResourceManager resourceManager;

  Future<void> _onRefresh(
    RefreshDeviceResources event,
    Emitter<DeviceResourceBlocState> emit,
  ) async {
    final next = await resourceManager.refreshTelemetry();
    final voices = await resourceManager.checkOfflineVoiceAvailability(
      const ['en-IN', 'hi-IN', 'kn-IN', 'ta-IN', 'te-IN', 'ml-IN', 'mr-IN', 'bn-IN'],
    );
    emit(DeviceResourceBlocState(
      resourceState: next,
      offlineVoiceSupport: voices,
    ));
  }

  void _onChangeMode(
    ChangeOperatingMode event,
    Emitter<DeviceResourceBlocState> emit,
  ) {
    final next = resourceManager.setOperatingMode(event.mode);
    emit(DeviceResourceBlocState(
      resourceState: next,
      offlineVoiceSupport: state.offlineVoiceSupport,
    ));
  }
}
