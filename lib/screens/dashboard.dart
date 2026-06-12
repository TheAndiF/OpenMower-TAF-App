import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/mqtt_areas_controller.dart';
import 'package:open_mower_app/controllers/remote_controller.dart';
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/models/joystick_command.dart';
import 'package:open_mower_app/views/map_widget.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

const Color _kDashboardActionBlue = Color(0xFF617C98);

n.ButtonStyle _primaryActionButtonStyle() => n.ButtonStyle(
      backgroundColor: _kDashboardActionBlue,
      foregroundColor: Colors.white,
    );

class Dashboard extends GetView<RobotStateController> {
  Dashboard({super.key, required this.followRobot});

  final RxBool followRobot;

  final RemoteController remoteControl = Get.find();
  final MqttAreasController areasController = Get.find<MqttAreasController>();

  @override
  Widget build(BuildContext context) {
    return n.Column([
      const RobotStateWidget(),
      n.Stack([
        Obx(
          () {
            final currentState = controller.robotState.value.currentState;
            final followDashboardRobot =
                followRobot.value && currentState != 'AREA_RECORDING';

            return MapWidget(
              centerOnRobot: currentState == 'AREA_RECORDING' ||
                  followRobot.value,
              onManualInteraction: followDashboardRobot
                  ? () => followRobot.value = false
                  : null,
            );
          },
        ),
        n.Column([
          Card(
            elevation: 3,
            child: n.Column([
              'Current State:'.bodyLarge..m = 4,
              Obx(
                () => Text(
                  _dashboardStateText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ).niku
                  ..m = 4,
              ),
            ])
              ..p = 16
              ..mainAxisAlignment = MainAxisAlignment.start
              ..crossAxisAlignment = CrossAxisAlignment.start
              ..fullWidth,
          ),
        ])..p = 16,
        Obx(
          () => (controller.robotState.value.currentState == 'AREA_RECORDING')
              ? Container(
                  padding: const EdgeInsets.all(30.0),
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: 0.8,
                    child: Joystick(
                      base: JoystickBase(
                        decoration: JoystickBaseDecoration(
                          drawOuterCircle: false,
                        ),
                      ),
                      mode: JoystickMode.all,
                      onStickDragEnd: () {
                        remoteControl.sendMessage(0, 0);
                      },
                      listener: (details) {
                        remoteControl.joystickCommand.value = JoystickCommand(
                          -details.y * 1.0,
                          -details.x * 1.6,
                        );
                      },
                    ),
                  ),
                )
              : n.Row(const []),
        ),
      ])..expanded,
      Material(
        elevation: 5,
        color: Colors.white,
        child: Obx(() => getButtonPanel(context, controller)),
      ),
    ]);
  }


  String _dashboardStateText() {
    final state = controller.robotState.value.currentState;
    if (state.toUpperCase() != 'MOWING') {
      return state;
    }

    final areaName = _currentMowingAreaName();
    if (areaName == null || areaName.isEmpty) {
      return state;
    }

    return '$state · $areaName';
  }

  String? _currentMowingAreaName() {
    final areaId = _currentMowingAreaId();
    if (areaId.isEmpty) {
      return null;
    }

    final area = areasController.findAreaById(areaId);
    if (area == null) {
      return null;
    }

    final props = areasController.propertiesFor(area);
    final name = (props['name'] ?? area['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return null;
    }

    return name;
  }

  String _currentMowingAreaId() {
    final progressAreaId = controller.mowingProgress.value.currentAreaId.trim();
    if (progressAreaId.isNotEmpty) {
      return progressAreaId;
    }

    final currentAreaId = controller.robotState.value.currentAreaId.trim();
    if (currentAreaId.isNotEmpty) {
      return currentAreaId;
    }

    return controller.lastActiveMowingAreaId.value.trim();
  }

  Widget getButtonPanel(BuildContext context, RobotStateController controller) {
    if (controller.robotState.value.currentState != 'AREA_RECORDING') {
      return n.Row([
        !controller.hasAction('mower_logic:mowing/pause')
            ? (n.Button.elevatedIcon('Start'.n, n.Icon(Icons.play_arrow))
              ..enable =
                  (controller.hasAction('mower_logic:idle/start_mowing') ||
                      controller.hasAction('mower_logic:mowing/continue'))
              ..onPressed = () {
                if (controller.hasAction('mower_logic:idle/start_mowing')) {
                  remoteControl.callAction('mower_logic:idle/start_mowing');
                } else if (controller.hasAction(
                  'mower_logic:mowing/continue',
                )) {
                  remoteControl.callAction('mower_logic:mowing/continue');
                }
              }
              ..style = _primaryActionButtonStyle()
              ..expanded
              ..elevation = 2
              ..p = 16)
            : (n.Button.elevatedIcon('Pause'.n, n.Icon(Icons.pause))
              ..enable = controller.hasAction('mower_logic:mowing/pause')
              ..onPressed = () {
                remoteControl.callAction('mower_logic:mowing/pause');
              }
              ..style = _primaryActionButtonStyle()
              ..expanded
              ..elevation = 2
              ..p = 16),
        n.Button.elevatedIcon('Stop'.n, n.Icon(Icons.home))
          ..enable = controller.hasAction('mower_logic:mowing/abort_mowing')
          ..onPressed = () {
            remoteControl.callAction('mower_logic:mowing/abort_mowing');
          }
          ..elevation = 2
          ..p = 16,
        n.Button.elevatedIcon(
          'Area Recording'.n,
          n.Icon(Icons.fiber_manual_record),
        )
          ..enable =
              controller.hasAction('mower_logic:idle/start_area_recording')
          ..onPressed = () {
            remoteControl.callAction('mower_logic:idle/start_area_recording');
          }
          ..style = _primaryActionButtonStyle()
          ..elevation = 2
          ..p = 16,
      ])
        ..gap = 8
        ..p = 16;
    }

    return n.Column([
      n.Row([
        !controller.hasAction('mower_logic:area_recording/stop_recording')
            ? (n.Button.elevatedIcon(
                'Start Recording'.n,
                n.Icon(Icons.fiber_manual_record),
              )
              ..enable = controller.hasAction(
                'mower_logic:area_recording/start_recording',
              )
              ..onPressed = () {
                remoteControl.callAction(
                  'mower_logic:area_recording/start_recording',
                );
              }
              ..style = _primaryActionButtonStyle()
              ..expanded
              ..elevation = 2
              ..p = 16)
            : (n.Button.elevatedIcon(
                'Stop Recording'.n,
                n.Icon(Icons.fiber_manual_record),
              )
              ..visible = controller.hasAction(
                'mower_logic:area_recording/stop_recording',
              )
              ..onPressed = () {
                remoteControl.callAction(
                  'mower_logic:area_recording/stop_recording',
                );
              }
              ..style = n.ButtonStyle(backgroundColor: Colors.red)
              ..expanded
              ..elevation = 2
              ..p = 16),
        n.Button.elevatedIcon('Finish Area'.n, n.Icon(Icons.stop),
            onPressed: () {
          n.showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => buildSaveAreaDialog(),
          );
        })
          ..enable = controller.hasAnyAction([
            'mower_logic:area_recording/finish_navigation_area',
            'mower_logic:area_recording/finish_mowing_area',
            'mower_logic:area_recording/finish_discard',
          ])
          ..style = _primaryActionButtonStyle()
          ..elevation = 2
          ..p = 16,
      ])
        ..gap = 8
        ..px = 16
        ..py = 8,
      n.Row([
        n.Button.elevatedIcon('Record Docking'.n, n.Icon(Icons.home))
          ..enable = controller.hasAction(
            'mower_logic:area_recording/record_dock',
          )
          ..onPressed = () {
            remoteControl.callAction('mower_logic:area_recording/record_dock');
          }
          ..style = _primaryActionButtonStyle()
          ..elevation = 2
          ..expanded
          ..p = 16,
        n.Button.elevatedIcon(
          'Exit Recording Mode'.n,
          n.Icon(Icons.exit_to_app),
        )
          ..enable = controller.hasAction(
            'mower_logic:area_recording/exit_recording_mode',
          )
          ..onPressed = () {
            remoteControl.callAction(
              'mower_logic:area_recording/exit_recording_mode',
            );
          }
          ..style = _primaryActionButtonStyle()
          ..elevation = 2
          ..expanded
          ..p = 16,
      ])
        ..gap = 8
        ..px = 16
        ..py = 8,
      n.Row([
        controller.hasAction(
          'mower_logic:area_recording/auto_point_collecting_disable',
        )
            ? (n.Button.elevatedIcon(
                'Disable auto collecting'.n,
                n.Icon(Icons.route),
              )
              ..visible = controller.hasAction(
                'mower_logic:area_recording/auto_point_collecting_disable',
              )
              ..onPressed = () {
                remoteControl.callAction(
                  'mower_logic:area_recording/auto_point_collecting_disable',
                );
              }
              ..style = n.ButtonStyle(backgroundColor: Colors.orangeAccent)
              ..elevation = 2
              ..p = 16)
            : (n.Button.elevatedIcon(
                'Enable auto collecting'.n,
                n.Icon(Icons.route),
              )
              ..visible = controller.hasAction(
                'mower_logic:area_recording/auto_point_collecting_enable',
              )
              ..onPressed = () {
                remoteControl.callAction(
                  'mower_logic:area_recording/auto_point_collecting_enable',
                );
              }
              ..style = _primaryActionButtonStyle()
              ..elevation = 2
              ..p = 16),
        n.Button.elevatedIcon('Add point'.n, n.Icon(Icons.add_location))
          ..visible = controller.hasAction(
            'mower_logic:area_recording/collect_point',
          )
          ..onPressed = () {
            remoteControl.callAction('mower_logic:area_recording/collect_point');
          }
          ..style = n.ButtonStyle(backgroundColor: Colors.green)
          ..elevation = 2
          ..expanded
          ..p = 16,
      ])
        ..gap = 8
        ..px = 16
        ..py = 8,
    ])..py = 8;
  }

  Widget buildSaveAreaDialog() {
    return n.Alert.adaptive()
      ..title = 'Save Area'.n
      ..content = 'Save area as navigation area or as mowing area?'.n
      ..actions = [
        n.Button('Mowing Area'.n)
          ..onPressed = () {
            remoteControl.callAction(
              'mower_logic:area_recording/finish_mowing_area',
            );
            Get.back();
          }
          ..bold
          ..p = 24,
        n.Button('Navigation Area'.n)
          ..onPressed = () {
            remoteControl.callAction(
              'mower_logic:area_recording/finish_navigation_area',
            );
            Get.back();
          }
          ..bold
          ..p = 24,
        n.Button("Don't Save".n)
          ..onPressed = () {
            remoteControl.callAction('mower_logic:area_recording/finish_discard');
            Get.back();
          }
          ..bold
          ..color = Colors.red
          ..p = 24,
      ];
  }
}
