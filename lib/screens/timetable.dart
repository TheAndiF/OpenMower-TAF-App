import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_mower_app/controllers/timetable_controller.dart';
import 'package:open_mower_app/views/robot_state_widget.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TimetableController controller = Get.find<TimetableController>();
  bool _renewSent = false;
  bool _jsonExpanded = false;

  static const days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const endBehaviors = <String>[
    'return_to_dock',
    'finish_current_run',
    'pause',
    'stop',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_renewSent) {
        _renewSent = true;
        controller.requestTimetable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final data = controller.timetableData;
          final timetable = Map<String, dynamic>.from((data['timetable'] as Map?) ?? <String, dynamic>{});
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSuspensionSection(context),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.schedule,
                  title: 'Time Settings',
                  subtitle: 'Systemzeit anzeigen und aktualisieren',
                  initiallyExpanded: false,
                  child: _buildTimeSettingsCard(context),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Mähzeiten',
                  subtitle: 'Zeit-Einträge anzeigen, ändern, löschen und ergänzen',
                  child: _buildEntriesSection(context, timetable),
                ),
                const SizedBox(height: 16),
                _buildJsonSection(context),
              ],
            ),
          );
        }),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RobotStateWidget(),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool initiallyExpanded = true,
    required Widget child,
  }) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          backgroundColor: color.withOpacity(0.08),
          collapsedBackgroundColor: color.withOpacity(0.08),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(icon, color: color, size: 32),
          iconColor: color,
          collapsedIconColor: color,
          title: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        color: color.withOpacity(0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
                        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSettingsCard(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final source = controller.selectedTimeSource.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _timeSettingsBlock(
              context,
              label: 'Aktuelle Systemzeit',
              child: Text(
                controller.formattedSystemTime,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            _timeDivider(context),
            _timeSettingsBlock(
              context,
              label: 'Zeitzone',
              child: SizedBox(
                width: isMobile ? double.infinity : 420,
                child: DropdownButtonFormField<String>(
                  value: _safeValue(controller.selectedTimezone, TimetableController.availableTimezones),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                  items: TimetableController.availableTimezones
                      .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.timezoneController.text = value;
                      controller.updateTimezone(value);
                    }
                  },
                ),
              ),
            ),
            _timeDivider(context),
            _timeSettingsBlock(
              context,
              label: 'Zeit aktualisieren über',
              child: _timeSourceSelector(context, source: source, isMobile: isMobile),
            ),
            _timeDivider(context),
            _timeSettingsBlock(
              context,
              label: _timeSourceDetailTitle(source),
              child: _timeSourceDetails(context, source: source, isMobile: isMobile),
            ),
            _timeDivider(context),
            Align(
              alignment: isMobile ? Alignment.center : Alignment.centerLeft,
              child: SizedBox(
                width: isMobile ? double.infinity : 260,
                child: ElevatedButton.icon(
                  onPressed: controller.updateTimeSettingsNow,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Zeit aktualisieren'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(4),
                color: color.withOpacity(0.03),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Die ausgewählte Zeitquelle und Zeitzone werden erst beim Aktualisieren angewendet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 18, isMobile ? 16 : 24, 22),
          color: Theme.of(context).cardColor,
          child: content,
        );
      },
    );
  }

  Widget _timeSettingsBlock(BuildContext context, {required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _timeDivider(BuildContext context) {
    return Divider(height: 24, color: Theme.of(context).dividerColor.withOpacity(0.75));
  }

  Widget _timeSourceSelector(BuildContext context, {required String source, required bool isMobile}) {
    final entries = const <String>['system', 'ntp', 'gps', 'manual'];
    if (isMobile) {
      return Row(
        children: entries
            .map((entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _timeSourceButton(context, source: entry, active: source == entry, compact: true),
                  ),
                ))
            .toList(),
      );
    }

    return SizedBox(
      width: 760,
      child: Row(
        children: entries
            .map((entry) => Expanded(
                  child: _timeSourceButton(context, source: entry, active: source == entry, compact: false),
                ))
            .toList(),
      ),
    );
  }

  Widget _timeSourceButton(BuildContext context, {required String source, required bool active, required bool compact}) {
    final color = Theme.of(context).primaryColor;
    final label = TimetableController.timeSourceLabels[source] ?? source;
    return InkWell(
      onTap: () => controller.setSelectedTimeSource(source),
      child: Container(
        height: compact ? 46 : 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: active ? color : Theme.of(context).dividerColor),
          color: active ? color.withOpacity(0.08) : Theme.of(context).cardColor,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? color : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _timeSourceDetailTitle(String source) {
    switch (source) {
      case 'system':
        return 'Systemzeit verwenden';
      case 'gps':
        return 'GPS-Zeit verwenden';
      case 'manual':
        return 'Manuelle Zeit setzen';
      case 'ntp':
      default:
        return 'NTP-Server';
    }
  }

  Widget _timeSourceDetails(BuildContext context, {required String source, required bool isMobile}) {
    if (source == 'ntp') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 420,
            child: TextFormField(
              controller: controller.ntpServerController,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'pool.ntp.org',
              ),
              onChanged: controller.updateNtpServer,
            ),
          ),
          const SizedBox(height: 8),
          Text(controller.timeSourceDescription, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    if (source == 'manual') {
      final fields = <Widget>[
        SizedBox(
          width: isMobile ? double.infinity : 180,
          child: TextFormField(
            controller: controller.manualDateController,
            decoration: const InputDecoration(labelText: 'Datum', hintText: 'YYYY-MM-DD'),
            keyboardType: TextInputType.datetime,
            onChanged: (_) => controller.updateManualTimeFromFields(),
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 120,
          child: TextFormField(
            controller: controller.hourController,
            decoration: const InputDecoration(labelText: 'Stunden'),
            keyboardType: TextInputType.number,
            onChanged: (_) => controller.updateManualTimeFromFields(),
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 120,
          child: TextFormField(
            controller: controller.minuteController,
            decoration: const InputDecoration(labelText: 'Minuten'),
            keyboardType: TextInputType.number,
            onChanged: (_) => controller.updateManualTimeFromFields(),
          ),
        ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _withSpacing(fields, vertical: 8))
              : Wrap(spacing: 16, runSpacing: 8, children: fields),
          const SizedBox(height: 8),
          Text(controller.timeSourceDescription, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return Text(controller.timeSourceDescription, style: Theme.of(context).textTheme.bodyMedium);
  }

  List<Widget> _withSpacing(List<Widget> children, {double vertical = 8}) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) result.add(SizedBox(height: vertical));
      result.add(children[i]);
    }
    return result;
  }

  Widget _buildSuspensionSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                _headerStatusIcon(color: color, active: controller.isSuspended),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mähzeit aussetzen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mähbetrieb vorübergehend pausieren',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSuspensionCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspensionCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final state = controller.suspensionUiState;
    final active = state != SuspensionUiState.none;
    final oneDayActive = state == SuspensionUiState.oneDay;
    final threeDaysActive = state == SuspensionUiState.threeDays;
    final indefiniteActive = state == SuspensionUiState.indefinite;
    final until = _parseSuspensionDate(controller.autoMowSuspension);
    final headline = _suspensionHeadline(state);
    final dateText = _suspensionDetailText(state, until);
    final relativeText = (state == SuspensionUiState.oneDay || state == SuspensionUiState.threeDays || state == SuspensionUiState.customDate)
        ? _formatSuspensionRelative(until)
        : null;

    final actionButtons = <Widget>[
      _actionButton(
        context,
        label: '1 Tag aussetzen',
        active: oneDayActive,
        icon: Icons.calendar_today_outlined,
        onPressed: () => controller.toggleSuspensionDays(1),
      ),
      _actionButton(
        context,
        label: '3 Tage aussetzen',
        active: threeDaysActive,
        icon: Icons.date_range_outlined,
        onPressed: () => controller.toggleSuspensionDays(3),
      ),
      _actionButton(
        context,
        label: 'Unbestimmt aussetzen',
        active: indefiniteActive,
        icon: Icons.all_inclusive,
        onPressed: controller.toggleSuspensionIndefinite,
      ),
      if (active)
        _actionButton(
          context,
          label: 'Aufheben',
          active: false,
          icon: Icons.play_arrow,
          danger: true,
          onPressed: controller.clearSuspension,
        ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _bodyStatusIcon(context, state: state)),
          const SizedBox(height: 18),
          Text(headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Text(
            dateText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (relativeText != null && relativeText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(relativeText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
          ],
          const SizedBox(height: 20),
          for (final button in actionButtons) ...[
            SizedBox(height: 56, child: button),
            if (button != actionButtons.last) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _bodyStatusIcon(context, state: state),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              Text(
                dateText,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (relativeText != null && relativeText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(relativeText, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: actionButtons
                .map((button) => SizedBox(
                      width: 220,
                      height: 56,
                      child: button,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  String _suspensionHeadline(SuspensionUiState state) {
    switch (state) {
      case SuspensionUiState.none:
        return 'Keine Aussetzung aktiv';
      case SuspensionUiState.indefinite:
        return 'AutoMow ist unbestimmt pausiert';
      case SuspensionUiState.oneDay:
      case SuspensionUiState.threeDays:
      case SuspensionUiState.customDate:
        return 'AutoMow pausiert bis';
    }
  }

  String _suspensionDetailText(SuspensionUiState state, DateTime? until) {
    switch (state) {
      case SuspensionUiState.none:
        return 'AutoMow mäht nach Zeitplan.';
      case SuspensionUiState.indefinite:
        return 'Der Mähbetrieb startet erst wieder nach dem Aufheben.';
      case SuspensionUiState.oneDay:
      case SuspensionUiState.threeDays:
      case SuspensionUiState.customDate:
        return until == null ? controller.autoMowSuspension.toString() : _formatSuspensionDate(until);
    }
  }

  Widget _headerStatusIcon({required Color color, required bool active}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.65), width: 2),
      ),
      child: Icon(Icons.nights_stay_outlined, color: color, size: 24),
    );
  }

  Widget _bodyStatusIcon(BuildContext context, {required SuspensionUiState state}) {
    final color = Theme.of(context).primaryColor;
    final isNone = state == SuspensionUiState.none;
    IconData icon;
    switch (state) {
      case SuspensionUiState.none:
        icon = Icons.check;
        break;
      case SuspensionUiState.indefinite:
        icon = Icons.all_inclusive;
        break;
      case SuspensionUiState.oneDay:
      case SuspensionUiState.threeDays:
      case SuspensionUiState.customDate:
        icon = Icons.pause;
        break;
    }
    final bgColor = isNone ? Colors.green.withOpacity(0.10) : color.withOpacity(0.10);
    final iconColor = isNone ? Colors.green : color;
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Icon(icon, color: iconColor, size: 64),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback? onPressed,
    IconData? icon,
    bool danger = false,
  }) {
    final childLabel = Text(
      active ? '✓ $label' : label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final child = icon == null
        ? childLabel
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: childLabel),
            ],
          );

    if (active) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? Colors.red : null,
        side: danger ? const BorderSide(color: Colors.red) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: child,
    );
  }

  DateTime? _parseSuspensionDate(dynamic value) {
    if (value == null || value == 0 || value.toString() == '0' || value.toString().trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatSuspensionDate(DateTime date) {
    const weekdays = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
    final weekday = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$weekday, $day.$month.$year · $hour:$minute Uhr';
  }

  String _formatSuspensionRelative(DateTime? until) {
    if (until == null) return '';
    var diff = until.difference(DateTime.now());
    if (diff.isNegative) diff = Duration.zero;
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days ${days == 1 ? 'Tag' : 'Tagen'}');
    if (hours > 0) parts.add('$hours ${hours == 1 ? 'Stunde' : 'Stunden'}');
    if (days == 0 && hours == 0) parts.add('$minutes ${minutes == 1 ? 'Minute' : 'Minuten'}');
    return '(in ${parts.join(', ')})';
  }

  Widget _toggleButton(BuildContext context, {required bool active, required IconData icon, required String label, required VoidCallback onPressed}) {
    return active
        ? ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text('✓ $label'))
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
  }

  Widget _buildSourceRow(
    BuildContext context, {
    required bool selected,
    required bool selectable,
    required String label,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    final color = Theme.of(context).primaryColor;
    final labelBox = Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
        color: selectable ? Colors.white : Colors.grey.shade100,
      ),
      child: Text(label, style: TextStyle(color: selected ? color : null)),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: selected ? Icon(Icons.check, color: color, size: 22) : const SizedBox.shrink(),
        ),
        labelBox,
        const SizedBox(width: 16),
        Flexible(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ),
      ],
    );

    if (!selectable) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }

  Widget _buildEntriesSection(BuildContext context, Map<String, dynamic> timetable) {
    final entries = timetable.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Die technische ID wird automatisch erzeugt, intern als Key unter timetable verwendet und nicht angezeigt.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Noch keine Mähzeiten vorhanden.', style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          ...entries.map((entry) {
            final item = Map<String, dynamic>.from((entry.value as Map?) ?? <String, dynamic>{});
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEntryRow(context, entry.key, item),
            );
          }),
        Text('Neuer Eintrag', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildNewEntryRow(context),
      ],
    );
  }

  Widget _buildEntryRow(BuildContext context, String id, Map<String, dynamic> item) {
    final editing = controller.isEntryEditing(id);
    final isCurrent = controller.isCurrentMowEntry(id);
    final color = Theme.of(context).primaryColor;
    final borderColor = isCurrent ? color : Theme.of(context).dividerColor;
    final backgroundColor = isCurrent ? color.withOpacity(0.08) : Theme.of(context).cardColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCurrent) ...[
            _currentEntryBanner(context),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _entryDayDropdown(id, item, enabled: editing),
              _entryTimeField(context, id, item, 'start', 'Start', enabled: editing, width: 120),
              _entryTimeField(context, id, item, 'end', 'Ende', enabled: editing, width: 120),
              _entryEndBehaviorDropdown(id, item, enabled: editing),
              _fieldsButton(context, id, item),
              _boolSwitch('Aktiv', item['enabled'] == true, editing ? (value) => controller.updateEntry(id, 'enabled', value) : null),
              _boolSwitch('Auto-Start', item['auto_start'] == true, editing ? (value) => controller.updateEntry(id, 'auto_start', value) : null),
              SizedBox(
                width: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Eintrag löschen',
                      onPressed: () => _confirmRemoveEntry(context, id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: editing ? 'Eintrag speichern' : 'Eintrag ändern',
                      onPressed: () => controller.toggleEditEntry(id),
                      icon: Icon(editing ? Icons.save_outlined : Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currentEntryBanner(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Aktuell abgearbeiteter Mähzeit-Eintrag',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveEntry(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mähzeit löschen?'),
        content: const Text('Der Timeslot wird lokal aus der JSON entfernt. Übertragen wird erst mit Speichern.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              controller.removeEntry(id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewEntryRow(BuildContext context) {
    final draft = controller.newEntryDraft;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _safeValue((draft['day'] ?? 'Sunday').toString(), days),
              decoration: const InputDecoration(labelText: 'Tag'),
              items: days.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) controller.updateNewEntry('day', value);
              },
            ),
          ),
          _newEntryTimeField(context, 'start', 'Start', width: 120),
          _newEntryTimeField(context, 'end', 'Ende', width: 120),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _safeValue((draft['end_behavior'] ?? 'return_to_dock').toString(), endBehaviors),
              decoration: const InputDecoration(labelText: 'Verhalten bei Ende'),
              items: endBehaviors.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) controller.updateNewEntry('end_behavior', value);
              },
            ),
          ),
          OutlinedButton(
            onPressed: null,
            child: const Text('0 Felder'),
          ),
          _boolSwitch('Aktiv', draft['enabled'] == true, (value) => controller.updateNewEntry('enabled', value)),
          _boolSwitch('Auto-Start', draft['auto_start'] == true, (value) => controller.updateNewEntry('auto_start', value)),
          SizedBox(
            width: 56,
            child: IconButton(
              tooltip: 'Eintrag hinzufügen',
              onPressed: () => controller.addEntryFromDraft(),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryDayDropdown(String id, Map<String, dynamic> item, {bool enabled = true}) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        value: _safeValue((item['day'] ?? 'Monday').toString(), days),
        decoration: const InputDecoration(labelText: 'Tag'),
        items: days.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) controller.updateEntry(id, 'day', value);
              }
            : null,
      ),
    );
  }

  Widget _entryEndBehaviorDropdown(String id, Map<String, dynamic> item, {bool enabled = true}) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: _safeValue((item['end_behavior'] ?? 'return_to_dock').toString(), endBehaviors),
        decoration: const InputDecoration(labelText: 'Verhalten bei Ende'),
        items: endBehaviors.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) controller.updateEntry(id, 'end_behavior', value);
              }
            : null,
      ),
    );
  }

  Widget _entryTimeField(
    BuildContext context,
    String id,
    Map<String, dynamic> item,
    String field,
    String label, {
    double width = 120,
    bool enabled = true,
  }) {
    final value = (item[field] ?? '').toString();
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('timetable-$id-$field'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'HH:MM',
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        keyboardType: TextInputType.datetime,
        inputFormatters: _timeInputFormatters,
        readOnly: true,
        enabled: enabled,
        onTap: enabled ? () => _pickEntryTime(context, id, item, field) : null,
      ),
    );
  }

  Widget _newEntryTimeField(BuildContext context, String field, String label, {double width = 120}) {
    final value = (controller.newEntryDraft[field] ?? '').toString();
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('new-entry-$field'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'HH:MM',
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        keyboardType: TextInputType.datetime,
        inputFormatters: _timeInputFormatters,
        readOnly: true,
        onTap: () => _pickNewEntryTime(context, field),
      ),
    );
  }

  List<TextInputFormatter> get _timeInputFormatters => [
        LengthLimitingTextInputFormatter(5),
      ];

  Future<void> _pickEntryTime(BuildContext context, String id, Map<String, dynamic> item, String field) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay((item[field] ?? '').toString()) ?? const TimeOfDay(hour: 0, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      controller.updateEntry(id, field, _formatTimeOfDay(picked));
    }
  }

  Future<void> _pickNewEntryTime(BuildContext context, String field) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay((controller.newEntryDraft[field] ?? '').toString()) ?? const TimeOfDay(hour: 0, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      controller.updateNewEntry(field, _formatTimeOfDay(picked));
    }
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _fieldsButton(BuildContext context, String id, Map<String, dynamic> item) {
    final count = controller.extraFieldsCount(item);
    return OutlinedButton(
      onPressed: () => _showExtraFieldsDialog(context, id, item),
      child: Text('$count Felder'),
    );
  }

  void _showExtraFieldsDialog(BuildContext context, String id, Map<String, dynamic> item) {
    final extra = controller.extraFieldsFor(item);
    final textController = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(extra));
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Zusätzliche Felder'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: textController,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Zusätzliche Felder als JSON',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                if (controller.updateExtraFieldsFromJson(id, textController.text)) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    ).whenComplete(textController.dispose);
  }

  Widget _boolSwitch(String label, bool value, ValueChanged<bool>? onChanged) {
    return SizedBox(
      width: 150,
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildJsonSection(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        return Card(
          margin: EdgeInsets.zero,
          child: Container(
            color: color.withOpacity(0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 12, isMobile ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.code, color: color, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JSON-Ansicht',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Timetable-Konfiguration anzeigen, importieren und speichern',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile) _jsonActionButtons(context, isMobile: false),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: _jsonExpanded ? 'JSON-Ansicht einklappen' : 'JSON-Ansicht ausklappen',
                            onPressed: () => setState(() => _jsonExpanded = !_jsonExpanded),
                            icon: Icon(_jsonExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: color),
                          ),
                        ],
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 12),
                        _jsonActionButtons(context, isMobile: true),
                      ],
                    ],
                  ),
                ),
                if (_jsonExpanded)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusCard(context),
                        const SizedBox(height: 12),
                        _buildJsonEditorCard(context, isMobile: isMobile),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _jsonActionButtons(BuildContext context, {required bool isMobile}) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: _downloadJsonFile,
        icon: const Icon(Icons.download),
        label: Text(isMobile ? 'Herunterladen' : 'Download'),
      ),
      OutlinedButton.icon(
        onPressed: _uploadJsonFile,
        icon: const Icon(Icons.upload),
        label: Text(isMobile ? 'Hochladen' : 'Upload'),
      ),
      ElevatedButton.icon(
        onPressed: controller.hasData ? controller.sendTimetable : null,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Speichern'),
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: buttons[i]),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final ok = controller.lastStatusOk.value;
    final topic = controller.lastTopic.value;
    final updated = controller.lastUpdated.value;
    final remarks = controller.lastRemarks;

    final Color accent;
    final Color background;
    final IconData icon;
    final String headline;
    if (ok == true) {
      accent = Colors.green.shade700;
      background = Colors.green.shade50;
      icon = Icons.check_circle_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Timetable vom Server empfangen.' : controller.lastStatus.value;
    } else if (ok == false) {
      accent = Colors.red.shade700;
      background = Colors.red.shade50;
      icon = Icons.error_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Aktion fehlgeschlagen.' : controller.lastStatus.value;
    } else if (controller.waitingForResponse.value) {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.06);
      icon = Icons.sync;
      headline = controller.lastStatus.value.isEmpty ? 'Warte auf Serverantwort ...' : controller.lastStatus.value;
    } else {
      accent = Theme.of(context).primaryColor;
      background = accent.withOpacity(0.04);
      icon = Icons.info_outline;
      headline = controller.lastStatus.value.isEmpty ? 'Noch keine Rückmeldung.' : controller.lastStatus.value;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: accent.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (topic.isNotEmpty || updated != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (topic.isNotEmpty)
                        Text('Topic: $topic', style: Theme.of(context).textTheme.bodySmall),
                      if (updated != null)
                        Text('Zeit: ${_formatTime(updated)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Server-Hinweise', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  ...remarks.map((remark) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('• $remark', style: Theme.of(context).textTheme.bodySmall),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonEditorCard(BuildContext context, {required bool isMobile}) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _jsonEditorTitle(context),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copyJsonToClipboard(context),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Kopieren'),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _jsonEditorTitle(context)),
                    OutlinedButton.icon(
                      onPressed: () => _copyJsonToClipboard(context),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Kopieren'),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.rawJsonController,
            minLines: 10,
            maxLines: 22,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'timetable.json',
              alignLabelWithHint: true,
              helperText: 'Änderungen im Editor werden erst mit „Speichern“ an MQTT gesendet.',
              helperStyle: TextStyle(color: color.withOpacity(0.9)),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _jsonEditorTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JSON-Inhalt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          'Lokale Timetable-Konfiguration. Upload übernimmt lokal, Speichern sendet an timetable/set/json.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _copyJsonToClipboard(BuildContext context) {
    _copyTextToClipboard(controller.rawJsonController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON wurde in die Zwischenablage kopiert.')),
    );
  }


  void _copyTextToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _downloadJsonFile() {
    final jsonText = controller.exportJsonString();
    final bytes = utf8.encode(jsonText);
    final blob = html.Blob(<Object>[bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final now = DateTime.now();
    final filename = 'openmower_timetable_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  void _uploadJsonFile() {
    final input = html.FileUploadInputElement()..accept = '.json,application/json';
    input.click();
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          controller.importJsonString(result, filename: file.name);
        } else {
          controller.setError('Datei konnte nicht als Text gelesen werden.', topic: 'local/upload');
        }
      });
      reader.readAsText(file);
    });
  }

  bool _suspensionLooksLikeDays(int days) {
    final value = controller.autoMowSuspension;
    if (value == null || value == 0) return false;
    final until = DateTime.tryParse(value.toString());
    if (until == null) return false;
    final diffHours = until.difference(DateTime.now()).inHours;
    if (days == 1) return diffHours <= 48;
    if (days == 3) return diffHours > 48;
    return false;
  }

  String _safeValue(String value, List<String> allowed) => allowed.contains(value) ? value : allowed.first;

  String _currentTimeText() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
