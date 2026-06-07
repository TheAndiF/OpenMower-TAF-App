import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_mower_app/controllers/robot_state_controller.dart';
import 'package:open_mower_app/controllers/settings_controller.dart';
import 'package:open_mower_app/screens/dashboard.dart';
import 'package:open_mower_app/screens/advanced_options.dart';
import 'package:open_mower_app/screens/sensor_values.dart';
import 'package:open_mower_app/screens/timetable.dart';
import 'package:open_mower_app/screens/mqtt_areas.dart';
import 'package:open_mower_app/screens/status_transition_log.dart';
import 'package:open_mower_app/screens/mower_logic_settings.dart';
import 'package:open_mower_app/screens/hardware_settings.dart';
import 'package:open_mower_app/screens/settings.dart';
import 'package:open_mower_app/views/logo_widget.dart';
import 'package:open_mower_app/views/logo_widget_drawer.dart';

const Color _kUiBlue = Color(0xFF36618E);
const Color _kUiBlueEdge = Color(0xFF274B70);

class MainScreen extends GetView<RobotStateController> {
  MainScreen({super.key});

  final widgetList = <Widget>[
    Dashboard(),
    AdvancedOptions(),
    const SensorValues(),
    const TimetableScreen(),
    const MqttAreasScreen(),
    const StatusTransitionLogScreen(),
    const HardwareSettingsScreen(),
    const MowerLogicSettingsScreen(),
    const Settings(),
  ];

  final _index = 0.obs;

  final pageTitles = const <String>[
    'Dashboard',
    'Advanced Options',
    'Sensor Values',
    'Timetable',
    'Flächen',
    'Protokoll',
    'Einstellungen Hardware',
    'Einstellungen Software',
    'Settings',
  ];

  final RobotStateController robotStateController = Get.find();
  final SettingsController settingsController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kUiBlue,
        surfaceTintColor: Colors.transparent,
        title: const LogoWidget(size: 200),
        titleSpacing: 0,
        elevation: 0,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kUiBlueEdge,
                  Color(0x88FFFFFF),
                  Colors.white,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Obx(() => ListView(
                    padding: EdgeInsets.zero,
                    children: buildDrawerList(),
                  )),
            ),
            Obx(() => Text(robotStateController.softwareVersion.value).paddingAll(10)),
          ],
        ),
      ),
      body: Obx(() {
        final selectedIndex = _index.value;
        final effectiveIndex =
            selectedIndex == 1 && !settingsController.expertModeEnabled.value
                ? 0
                : selectedIndex;

        return Column(
          children: [
            Expanded(
              child: _isAndroidApp
                  ? _buildSwipeablePage(effectiveIndex)
                  : widgetList[effectiveIndex],
            ),
            _buildCurrentPageStrip(effectiveIndex),
          ],
        );
      }),
    );
  }

  ListTile _buildDrawerTile({
    required Widget leading,
    required String title,
    required int index,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      onTap: () {
        Get.back();
        _index.value = index;
      },
    );
  }

  bool get _isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Widget _buildSwipeablePage(int effectiveIndex) {
    final page = widgetList[effectiveIndex];

    if (!_isSwipeEnabledOnPage(effectiveIndex)) {
      return page;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null || velocity.abs() < 250) return;

        if (velocity < 0) {
          _goToNextPage(effectiveIndex);
        } else {
          _goToPreviousPage(effectiveIndex);
        }
      },
      child: page,
    );
  }

  bool _isSwipeEnabledOnPage(int index) {
    // Die Flaechen-Seite nutzt eigene Gesten fuer Karte, Zoom und Editor.
    // Deshalb wird das Seiten-Swiping dort bewusst deaktiviert.
    return index != 4;
  }

  List<int> _availablePageIndexes() {
    return List<int>.generate(widgetList.length, (index) => index)
        .where(_isPageAvailable)
        .toList(growable: false);
  }

  bool _isPageAvailable(int index) {
    if (index == 1 && !settingsController.expertModeEnabled.value) {
      return false;
    }

    if (index == 8 && kReleaseMode && kIsWeb) {
      return false;
    }

    return true;
  }

  void _goToNextPage(int currentIndex) {
    final pages = _availablePageIndexes();
    final currentPosition = pages.indexOf(currentIndex);
    if (currentPosition < 0 || currentPosition >= pages.length - 1) return;
    _index.value = pages[currentPosition + 1];
  }

  void _goToPreviousPage(int currentIndex) {
    final pages = _availablePageIndexes();
    final currentPosition = pages.indexOf(currentIndex);
    if (currentPosition <= 0) return;
    _index.value = pages[currentPosition - 1];
  }

  Widget _buildCurrentPageStrip(int effectiveIndex) {
    final pages = _availablePageIndexes();
    final pageTitle = pageTitles[effectiveIndex];

    return Material(
      color: Colors.white,
      elevation: 6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Color(0x66FFFFFF),
                  _kUiBlueEdge,
                ],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),
          Container(
            height: _isAndroidApp ? 22 : 18,
            width: double.infinity,
            color: _kUiBlue,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 14),
                      child: Text(
                        pageTitle,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isAndroidApp) _buildPageDots(pages, effectiveIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageDots(List<int> pages, int effectiveIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: pages.map((pageIndex) {
        final isActive = pageIndex == effectiveIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: isActive ? 13 : 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }).toList(growable: false),
    );
  }

  List<Widget> buildDrawerList() {
    final drawerList = <Widget>[
      const DrawerHeader(
        decoration: BoxDecoration(
          color: _kUiBlue,
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: FittedBox(
            child: LogoWidgetDrawer(size: 0.2),
          ),
        ),
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.speed),
        title: 'Dashboard',
        index: 0,
      ),
      if (settingsController.expertModeEnabled.value)
        _buildDrawerTile(
          leading: n.Icon(Icons.settings_applications),
          title: 'Advanced Options',
          index: 1,
        ),
      _buildDrawerTile(
        leading: n.Icon(Icons.line_axis),
        title: 'Sensor Values',
        index: 2,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.event_note),
        title: 'Timetable',
        index: 3,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.grass),
        title: 'Flächen',
        index: 4,
      ),
      _buildDrawerTile(
        leading: n.Icon(Icons.receipt_long),
        title: 'Protokoll',
        index: 5,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(68, 2, 22, 2),
        child: Divider(height: 1),
      ),
      _buildDrawerTile(
        leading: const _HardwareSettingsDrawerIcon(),
        title: 'Einstellungen Hardware',
        index: 6,
      ),
      _buildDrawerTile(
        leading: const _SoftwareSettingsDrawerIcon(),
        title: 'Einstellungen Software',
        index: 7,
      ),
    ];

    if (!kReleaseMode || !kIsWeb) {
      drawerList.add(
        _buildDrawerTile(
          leading: n.Icon(Icons.settings),
          title: 'Settings',
          index: 8,
        ),
      );
    }

    return drawerList;
  }
}

class _HardwareSettingsDrawerIcon extends StatelessWidget {
  const _HardwareSettingsDrawerIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.grey;
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Icon(Icons.build, size: 25, color: color),
      ),
    );
  }
}

class _SoftwareSettingsDrawerIcon extends StatelessWidget {
  const _SoftwareSettingsDrawerIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.grey;
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        size: const Size(28, 28),
        painter: _SliderIconPainter(color),
      ),
    );
  }
}

class _SliderIconPainter extends CustomPainter {
  const _SliderIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final knob = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final y1 = size.height * 0.25;
    final y2 = size.height * 0.50;
    final y3 = size.height * 0.75;
    canvas.drawLine(Offset(size.width * 0.10, y1), Offset(size.width * 0.90, y1), line);
    canvas.drawLine(Offset(size.width * 0.10, y2), Offset(size.width * 0.90, y2), line);
    canvas.drawLine(Offset(size.width * 0.10, y3), Offset(size.width * 0.90, y3), line);
    canvas.drawCircle(Offset(size.width * 0.65, y1), 3.4, knob);
    canvas.drawCircle(Offset(size.width * 0.35, y2), 3.4, knob);
    canvas.drawCircle(Offset(size.width * 0.55, y3), 3.4, knob);
  }

  @override
  bool shouldRepaint(covariant _SliderIconPainter oldDelegate) => oldDelegate.color != color;
}
