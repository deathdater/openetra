import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/openetra_coordinator.dart';
import '../../../../shared/widgets/accessible_action_tile.dart';
import '../../../../shared/widgets/openetra_components.dart';
import '../../../emergency/presentation/emergency_assistance_screen.dart';
import '../../../flashlight/presentation/flashlight_settings_screen.dart';
import '../../../floating_companion/presentation/floating_widget_settings_screen.dart';
import '../../../gestures/presentation/gesture_automation_screen.dart';
import '../../../model_manager/presentation/model_manager_screen.dart';
import '../../../object_memory/presentation/object_memory_screen.dart';
import '../../../scene_understanding/presentation/scene_memory_screen.dart';
import '../../../settings/bloc/settings_bloc.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../../shopping/presentation/shopping_screen.dart';
import '../../../voice_assistant/presentation/home_screen.dart';
import '../../bloc/assistive_dial_bloc.dart';
import '../../models/dial_menu_node.dart';
import '../widgets/assistive_dial.dart';

/// Primary Openetra experience powered by the Intelligent Assistive Dial.
/// Preserves access to every dedicated Openetra configuration and workflow
/// screen while keeping the home canvas calm, focused, and audio-first.
class AssistiveDialPage extends StatefulWidget {
  const AssistiveDialPage({
    super.key,
    required this.coordinator,
  });

  final OpenetraCoordinator coordinator;

  @override
  State<AssistiveDialPage> createState() => _AssistiveDialPageState();
}

class _AssistiveDialPageState extends State<AssistiveDialPage> {
  @override
  void initState() {
    super.initState();
    final locale =
        context.read<SettingsBloc>().state.preferences.preferredLanguage;
    final dialBloc = context.read<AssistiveDialBloc>();
    if (dialBloc.state.phase == DialLifecyclePhase.initializing) {
      dialBloc.add(DialInitialized(locale: locale));
    }
  }

  void _openDedicatedRoute(BuildContext context, DialScreenRoute route) {
    final coord = widget.coordinator;
    final locale =
        context.read<SettingsBloc>().state.preferences.preferredLanguage;
    Widget? destination;

    switch (route) {
      case DialScreenRoute.settings:
        destination = SettingsScreen(
          coordinator: coord,
          flashlightController: coord.flashlightController,
          emergencyBloc: coord.emergencyBloc,
          gestureBloc: coord.gestureBloc,
          floatingCompanionBloc: coord.floatingCompanionBloc,
          dialBloc: context.read<AssistiveDialBloc>(),
        );
      case DialScreenRoute.emergencyAssistance:
        if (coord.emergencyBloc != null) {
          destination = BlocProvider.value(
            value: coord.emergencyBloc!,
            child: EmergencyAssistanceScreen(
              audioArbitrator: coord.audioArbitrator,
              locale: locale,
            ),
          );
        }
      case DialScreenRoute.objectMemory:
        destination = ObjectMemoryScreen(
          onFindObjectRequested: coord.runFindObject,
          onCaptureAndSaveRequested: coord.registerPersonalObjectWithCamera,
        );
      case DialScreenRoute.sceneMemory:
        destination = SceneMemoryScreen(coordinator: coord);
      case DialScreenRoute.shoppingAssistant:
        destination = ShoppingScreen(
          coordinator: coord,
          database: coord.database,
        );
      case DialScreenRoute.flashlightSettings:
        if (coord.flashlightController != null) {
          destination = FlashlightSettingsScreen(
            controller: coord.flashlightController!,
          );
        }
      case DialScreenRoute.gestureAutomation:
        if (coord.gestureBloc != null) {
          destination = BlocProvider.value(
            value: coord.gestureBloc!,
            child: const GestureAutomationScreen(),
          );
        }
      case DialScreenRoute.floatingCompanion:
        if (coord.floatingCompanionBloc != null) {
          destination = BlocProvider.value(
            value: coord.floatingCompanionBloc!,
            child: const FloatingWidgetSettingsScreen(),
          );
        }
      case DialScreenRoute.modelManager:
        destination = const ModelManagerScreen();
      case DialScreenRoute.classicListHome:
        destination = HomeScreen(coordinator: coord);
    }

    if (destination != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => destination!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Openetra'),
        actions: [
          Semantics(
            button: true,
            label: 'Classic List View',
            hint: 'Open classic vertical list of all Openetra actions',
            child: IconButton(
              icon: const Icon(Icons.view_list_outlined, size: 26),
              tooltip: 'Classic List View',
              onPressed: () =>
                  _openDedicatedRoute(context, DialScreenRoute.classicListHome),
            ),
          ),
          Semantics(
            button: true,
            label: 'Settings',
            hint: 'Open Openetra settings and configuration',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, size: 26),
              tooltip: 'Settings',
              onPressed: () =>
                  _openDedicatedRoute(context, DialScreenRoute.settings),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<AssistiveDialBloc, AssistiveDialState>(
          listener: (context, state) {
            if (state.pendingScreenRoute != null) {
              final route = state.pendingScreenRoute!;
              context
                  .read<AssistiveDialBloc>()
                  .add(const DialNavigationRouteHandled());
              _openDedicatedRoute(context, route);
            } else if (state.phase == DialLifecyclePhase.exiting) {
              SystemNavigator.pop();
            }
          },
          builder: (context, state) {
            final bloc = context.read<AssistiveDialBloc>();
            final activeLang =
                context.watch<SettingsBloc>().state.preferences.preferredLanguage;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const OpenetraStatusBadge(
                            label: 'Offline Ready',
                            icon: Icons.offline_pin_outlined,
                            tone: OpenetraBadgeTone.success,
                            semanticLabel: 'Openetra is ready offline on device',
                          ),
                          OpenetraStatusBadge(
                            label: activeLang,
                            icon: Icons.translate_outlined,
                            tone: OpenetraBadgeTone.info,
                            semanticLabel: 'Active voice language $activeLang',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SpokenStatusBanner(
                        statusText: state.statusAnnouncement,
                        isDegraded: state.phase == DialLifecyclePhase.failed ||
                            state.phase == DialLifecyclePhase.exitArmed,
                        isBusy: state.isBusy,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AssistiveDial(
                      menu: bloc.currentMenu,
                      focusedIndex: state.focusedIndex,
                      phase: state.phase,
                      activeOperationTitle: state.activeOperationTitle,
                      reducedMotion: state.reducedMotion,
                      onBrowsePrevious: () =>
                          bloc.add(const DialBrowsePrevious()),
                      onBrowseNext: () => bloc.add(const DialBrowseNext()),
                      onSlideUp: () => bloc.add(const DialSlideUpRequested()),
                      onSlideDown: () =>
                          bloc.add(const DialSlideDownRequested()),
                      onRepeat: () =>
                          bloc.add(const DialRepeatCurrentAnnouncement()),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
