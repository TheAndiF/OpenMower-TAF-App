import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import 'package:open_mower_app/screens/area_editor.dart';
import 'package:open_mower_app/screens/mower_logic_settings.dart';
import 'package:open_mower_app/screens/hardware_settings.dart';
import 'package:open_mower_app/screens/settings.dart';
import 'package:open_mower_app/views/logo_widget.dart';
import 'package:open_mower_app/views/logo_widget_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kUiBlue = Color(0xFF36618E);
const Color _kUiBlueEdge = Color(0xFF274B70);

class MainScreen extends GetView<RobotStateController> {
  MainScreen({super.key}) {
    widgetList = <Widget>[
      Dashboard(followRobot: _dashboardFollowRobot),
      AdvancedOptions(),
      const SensorValues(),
      const TimetableScreen(),
      MqttAreasScreen(onOpenEditor: () => _index.value = 9),
      const StatusTransitionLogScreen(),
      const HardwareSettingsScreen(),
      const MowerLogicSettingsScreen(),
      const Settings(),
      const AreaEditorScreen(),
    ];
  }

  final _index = 0.obs;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _dashboardFollowRobot = false.obs;

  Offset? _cornerGestureStart;
  bool _cornerGestureTriggered = false;

  Offset? _pageSwipeStart;
  DateTime? _pageSwipeStartTime;
  int _activePagePointers = 0;
  bool _pageSwipeCancelled = false;


  late final List<Widget> widgetList;

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
    'Flächeneditor',
  ];

  static final Uri _manualUri = Uri.parse('https://theandif.github.io/OpenMower-TAF-App/bedienungsanleitung/');

  final RobotStateController robotStateController = Get.find();
  final SettingsController settingsController = Get.find();

  Future<void> _openManual() async {
    final opened = await launchUrl(
      _manualUri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );

    if (!opened) {
      Get.snackbar(
        'Bedienungsanleitung',
        'Die Bedienungsanleitung konnte nicht geöffnet werden.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: _kUiBlue,
        surfaceTintColor: Colors.transparent,
        title: InkWell(
          onTap: _openManual,
          borderRadius: BorderRadius.circular(8),
          child: const Tooltip(
            message: 'Bedienungsanleitung öffnen',
            child: LogoWidget(size: 200),
          ),
        ),
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
      body: SafeArea(
        top: false,
        bottom: true,
        child: Obx(() {
          final selectedIndex = _index.value;
          final effectiveIndex =
              selectedIndex == 1 && !settingsController.expertModeEnabled.value
                  ? 0
                  : selectedIndex;

          final content = Column(
            children: [
              Expanded(
                child: _isAndroidApp
                    ? _buildSwipeablePage(effectiveIndex)
                    : widgetList[effectiveIndex],
              ),
              _buildCurrentPageStrip(effectiveIndex),
            ],
          );

          return _isAndroidApp ? _buildCornerGestures(context, content) : content;
        }),
      ),
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

  Widget _buildCornerGestures(BuildContext context, Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _cornerGestureStart = event.position;
        _cornerGestureTriggered = false;
      },
      onPointerMove: (event) {
        final start = _cornerGestureStart;
        if (start == null || _cornerGestureTriggered) return;

        final screenSize = MediaQuery.of(context).size;
        // Die Eckgesten duerfen nicht ueber dem Buttonbereich starten,
        // damit Start/Stop/Area-Recording normale Touch-Eingaben behalten.
        final startsAboveDashboardButtons = start.dy < screenSize.height - 170;
        final startsInLowerLeft = startsAboveDashboardButtons &&
            start.dx <= screenSize.width * 0.28 &&
            start.dy >= screenSize.height * 0.62;
        final startsInLowerRight = startsAboveDashboardButtons &&
            start.dx >= screenSize.width * 0.72 &&
            start.dy >= screenSize.height * 0.62;
        if (!startsInLowerLeft && !startsInLowerRight) return;

        final delta = event.position - start;
        final verticalDistance = delta.dy.abs();
        if (verticalDistance == 0) return;

        final diagonalRatio = delta.dx.abs() / verticalDistance;
        final isDiagonalToCenter = delta.dy <= -80 &&
            delta.dx.abs() >= 80 &&
            diagonalRatio >= 0.55 &&
            diagonalRatio <= 2.4;
        if (!isDiagonalToCenter) return;

        if (startsInLowerLeft && delta.dx > 0) {
          _cornerGestureTriggered = true;
          _scaffoldKey.currentState?.openDrawer();
        } else if (startsInLowerRight && delta.dx < 0) {
          _cornerGestureTriggered = true;
          _index.value = 0;
          _dashboardFollowRobot.value = true;
        }
      },
      onPointerUp: (_) => _cornerGestureStart = null,
      onPointerCancel: (_) => _cornerGestureStart = null,
      child: child,
    );
  }

  Widget _buildSwipeablePage(int effectiveIndex) {
    final page = widgetList[effectiveIndex];

    if (!_isSwipeEnabledOnPage(effectiveIndex)) {
      return page;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        _activePagePointers += 1;
        if (_activePagePointers == 1) {
          _pageSwipeStart = event.position;
          _pageSwipeStartTime = DateTime.now();
          _pageSwipeCancelled = false;
        } else {
          // Mehrfinger-Gesten, z. B. Pinch-Zoom auf der Karte, duerfen
          // keinen Seitenwechsel ausloesen.
          _pageSwipeCancelled = true;
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (_activePagePointers <= 1) {
          _finishPageSwipe(event.position, effectiveIndex);
          _activePagePointers = 0;
        } else {
          _activePagePointers -= 1;
        }
      },
      onPointerCancel: (_) {
        _activePagePointers = 0;
        _pageSwipeStart = null;
        _pageSwipeStartTime = null;
        _pageSwipeCancelled = false;
      },
      child: page,
    );
  }

  void _finishPageSwipe(Offset endPosition, int effectiveIndex) {
    final start = _pageSwipeStart;
    final startTime = _pageSwipeStartTime;
    _pageSwipeStart = null;
    _pageSwipeStartTime = null;

    if (start == null || startTime == null || _pageSwipeCancelled) return;

    final delta = endPosition - start;
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds.clamp(1, 10000);
    final horizontalSpeed = delta.dx.abs() / elapsedMs * 1000;

    final isClearHorizontalSwipe = delta.dx.abs() >= 110 &&
        delta.dy.abs() <= 90 &&
        horizontalSpeed >= 360;
    if (!isClearHorizontalSwipe) return;

    if (delta.dx < 0) {
      _goToNextPage(effectiveIndex);
    } else {
      _goToPreviousPage(effectiveIndex);
    }
  }

  bool _isSwipeEnabledOnPage(int index) {
    return _swipePageIndexes().contains(index);
  }

  List<int> _swipePageIndexes() {
    // Nur diese Hauptseiten werden in der Android-App per Swipe durchlaufen:
    // Dashboard -> Advanced Options -> Sensor Values -> Timetable -> Flächen -> Protokoll.
    // Der Flächeneditor bleibt eine eigene Unterseite und wird nicht per Swipe durchlaufen.
    return const <int>[0, 1, 2, 3, 4, 5]
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
    final pages = _swipePageIndexes();
    final currentPosition = pages.indexOf(currentIndex);
    if (currentPosition < 0 || currentPosition >= pages.length - 1) return;
    _index.value = pages[currentPosition + 1];
  }

  void _goToPreviousPage(int currentIndex) {
    final pages = _swipePageIndexes();
    final currentPosition = pages.indexOf(currentIndex);
    if (currentPosition <= 0) return;
    _index.value = pages[currentPosition - 1];
  }

  Widget _buildCurrentPageStrip(int effectiveIndex) {
    final pages = _swipePageIndexes();
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
                if (_isAndroidApp && pages.contains(effectiveIndex)) _buildPageDots(pages, effectiveIndex),
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
      DrawerHeader(
        decoration: const BoxDecoration(
          color: _kUiBlue,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: InkWell(
            onTap: () async {
              Get.back();
              await _openManual();
            },
            borderRadius: BorderRadius.circular(8),
            child: const Tooltip(
              message: 'Bedienungsanleitung öffnen',
              child: FittedBox(
                child: LogoWidgetDrawer(size: 0.2),
              ),
            ),
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
      _buildDrawerTile(
        leading: n.Icon(Icons.edit_location_alt_outlined),
        title: 'Flächeneditor',
        index: 9,
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
