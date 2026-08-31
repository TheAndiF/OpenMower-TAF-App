import 'package:flutter_test/flutter_test.dart';
import 'package:open_mower_app/controllers/messenger_settings_controller.dart';

Map<String, dynamic> botSnapshot() => <String, dynamic>{
      'namespace': 'messenger_bot',
      'schema': 'bot_v1',
      'schema_version': '1.0',
      'status': <String, dynamic>{'state': 'running', 'ready': true},
      'meta': <String, dynamic>{
        'groups': <dynamic>[
          <String, dynamic>{'key': 'general', 'label': 'Allgemein', 'order': 100},
          <String, dynamic>{'key': 'messenger', 'label': 'Messenger', 'order': 200},
        ],
      },
      'settings': <String, dynamic>{
        'enabled': <String, dynamic>{
          'label': 'Bot aktiviert',
          'group': 'general',
          'order': 10,
          'type': 'bool',
          'value': true,
          'active': true,
          'persistent': true,
          'session_apply_supported': true,
        },
        'group': <String, dynamic>{
          'label': 'Gruppe',
          'group': 'messenger',
          'order': 10,
          'type': 'string',
          'value': 'g001',
          'active': 'g001',
          'persistent': 'g001',
          'options': <dynamic>[
            <String, dynamic>{'value': 'g001', 'label': 'OpenMower'},
            <String, dynamic>{'value': 'g014', 'label': 'Garten'},
          ],
          'session_apply_supported': true,
        },
      },
      'flows': <String, dynamic>{
        'gps_details': <String, dynamic>{
          'label': 'GPS details',
          'type': 'bool',
          'value': true,
          'active': true,
          'persistent': true,
          'show': true,
          'readonly': false,
          'session_apply_supported': true,
        },
      },
    };

Map<String, dynamic> wahaSnapshot({String? qr}) => <String, dynamic>{
      'namespace': 'messenger_waha',
      'schema': 'waha_v1',
      'schema_version': '1.0',
      'status': <String, dynamic>{
        'state': qr == null ? 'WORKING' : 'SCAN_QR_CODE',
        'ready': qr == null,
        'connected': qr == null,
        'authentication_required': qr != null,
        'qr_code_available': qr != null,
        'QR_Code_Data': qr,
      },
      'meta': <String, dynamic>{},
      'settings': <String, dynamic>{
        'watchdog_seconds': <String, dynamic>{
          'label': 'Watchdog',
          'group': 'repair',
          'type': 'int',
          'value': 60,
          'active': 60,
          'persistent': 60,
          'min': 30,
          'session_apply_supported': true,
          'expert': true,
        },
      },
    };

void main() {
  test('accepts bot_v1 and renders dynamic flows without a fixed flow list', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(MessengerSurface.bot, botSnapshot(), topic: 'messenger/bot/json');

    expect(controller.botState, 'running');
    expect(controller.flowsForBot().keys, contains('gps_details'));
    expect(controller.groupLabel(MessengerSurface.bot, 'messenger'), 'Messenger');
  });

  test('rejects an incompatible schema without replacing the current snapshot', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(MessengerSurface.bot, botSnapshot(), topic: 'messenger/bot/json');
    final invalid = botSnapshot()..['schema_version'] = '2.0';

    controller.setSnapshot(MessengerSurface.bot, invalid, topic: 'messenger/bot/json');

    expect(controller.botSnapshot['schema_version'], '1.0');
    expect(controller.lastStatus.value, contains('Nicht unterstütztes Messenger-Schema'));
  });

  test('writes canonical value objects and only flow activation', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(MessengerSurface.bot, botSnapshot(), topic: 'messenger/bot/json');
    controller.updateSettingDraft(MessengerSurface.bot, 'group', 'g014');
    controller.updateFlowDraft('gps_details', false);

    final payload = controller.buildWritePayload(
      MessengerSurface.bot,
      session: false,
      includeFlows: true,
    );

    expect(payload['settings']['group'], <String, dynamic>{'value': 'g014'});
    expect(payload['flows']['gps_details'], <String, dynamic>{'value': false});
    expect(payload['flows']['gps_details'].keys, isNot(contains('label')));
  });

  test('rejects group values that are not in the current dynamic options', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(MessengerSurface.bot, botSnapshot(), topic: 'messenger/bot/json');
    controller.updateSettingDraft(MessengerSurface.bot, 'group', 'unknown');

    expect(controller.validationErrorFor(MessengerSurface.bot, 'group'), isNotNull);
    expect(
      controller.buildWritePayload(MessengerSurface.bot, session: false),
      isEmpty,
    );
  });

  test('keeps accepted fields and rejected fields separable on partial validation', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(MessengerSurface.bot, botSnapshot(), topic: 'messenger/bot/json');
    controller.updateSettingDraft(MessengerSurface.bot, 'group', 'g014');
    controller.updateFlowDraft('gps_details', false);

    controller.setValidation(
      MessengerSurface.bot,
      <String, dynamic>{
        'valid': false,
        'ok': false,
        'mode': 'persistent',
        'accepted': <String, dynamic>{
          'settings': <String, dynamic>{'group': <String>['value']},
        },
        'rejected': <String, dynamic>{
          'flows': <String, dynamic>{'gps_details': 'read-only'},
        },
        'remarks': <String>['Teilweise übernommen'],
      },
      topic: 'messenger/bot/validation/json',
    );

    expect(controller.botDirtySettings, isNot(contains('group')));
    expect(controller.botDirtyFlows, contains('gps_details'));
  });

  test('QR data is transiently available only while authentication is required and is redacted from diagnostics', () {
    final controller = MessengerSettingsController();
    controller.setSnapshot(
      MessengerSurface.waha,
      wahaSnapshot(qr: '2@example-qr-data'),
      topic: 'messenger/waha/json',
    );

    expect(controller.qrCodeData, '2@example-qr-data');
    expect(controller.prettyJsonSafe(controller.wahaSnapshot), isNot(contains('2@example-qr-data')));
    expect(controller.prettyJsonSafe(controller.wahaSnapshot), contains('<redacted>'));

    controller.setSnapshot(MessengerSurface.waha, wahaSnapshot(), topic: 'messenger/waha/json');
    expect(controller.qrCodeData, isNull);
  });

  test('unknown WAHA state strings remain visible', () {
    final controller = MessengerSettingsController();
    final snapshot = wahaSnapshot()..['status'] = <String, dynamic>{
        'state': 'FUTURE_STATE',
        'ready': false,
        'connected': false,
        'authentication_required': false,
        'qr_code_available': false,
        'QR_Code_Data': null,
      };

    controller.setSnapshot(MessengerSurface.waha, snapshot, topic: 'messenger/waha/json');
    expect(controller.wahaState, 'FUTURE_STATE');
  });

  test('respects readonly and session_apply_supported metadata', () {
    final controller = MessengerSettingsController();
    final snapshot = botSnapshot();
    (snapshot['settings'] as Map<String, dynamic>)['enabled'] = <String, dynamic>{
      'label': 'Bot aktiviert',
      'group': 'general',
      'type': 'bool',
      'value': true,
      'active': true,
      'persistent': true,
      'session_apply_supported': false,
    };
    ((snapshot['flows'] as Map<String, dynamic>)['gps_details'] as Map<String, dynamic>)['readonly'] = true;
    controller.setSnapshot(MessengerSurface.bot, snapshot, topic: 'messenger/bot/json');
    controller.updateSettingDraft(MessengerSurface.bot, 'enabled', false);
    controller.updateFlowDraft('gps_details', false);

    expect(
      controller.buildWritePayload(MessengerSurface.bot, session: true, includeFlows: true),
      isEmpty,
    );
    expect(controller.isFlowDirty('gps_details'), isFalse);
    expect(
      controller.buildWritePayload(MessengerSurface.bot, session: false, includeFlows: true)['settings']['enabled'],
      <String, dynamic>{'value': false},
    );
  });

}
