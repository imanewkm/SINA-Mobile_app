// Spoken-sentence builders and string lookup/fallback (labels.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:sina_mobile/constants/labels.dart';

void main() {
  group('t() / pick() lookup and fallback', () {
    test('returns the requested language', () {
      expect(t('en', 'welcome'), isNotEmpty);
      expect(t('ar', 'camera_on'), isNotEmpty);
    });

    test('falls back to French for an unknown language', () {
      expect(t('zz', 'welcome'), t('fr', 'welcome'));
    });

    test('pick falls back to French when a language is missing', () {
      expect(pick({'fr': 'bonjour'}, 'en'), 'bonjour');
      expect(pick({'fr': 'x', 'en': 'y'}, 'en'), 'y');
    });
  });

  group('single-object spoken alerts', () {
    test('builds a sentence per language with distance + position', () {
      final s = buildSpoken('car', 'very_close', 'left');
      expect(s.keys, containsAll(['fr', 'en', 'ar']));
      expect(s['en'], contains('Car'));
      expect(s['en'], contains('very close'));
      expect(s['en'], contains('on your left'));
      expect(s['fr'], contains('très proche'));
    });

    test('distance tiers change the phrasing', () {
      expect(buildSpoken('person', 'very_close', 'center')['en'],
          contains('very close'));
      expect(buildSpoken('person', 'far', 'center')['en'],
          contains('far away'));
    });

    test('generic "object" label is announceable', () {
      expect(labels['object'], isNotNull);
      final s = buildSpoken('object', 'close', 'center');
      expect(s['en'], contains('Object'));
      expect(s['fr'], contains('Objet'));
    });
  });

  group('grouped / many / traffic-light builders', () {
    test('grouped alert lists the objects', () {
      final s = buildGroupedSpoken(['car', 'person'], 'very_close', 'left');
      expect(s['en'], contains('Car and Person'));
      expect(s['en'], contains('Multiple obstacles'));
    });

    test('many-obstacles summary', () {
      expect(buildManySpoken('very_close')['en'], contains('Many obstacles'));
      expect(buildManySpoken('far')['fr'], contains("d'obstacles"));
    });

    test('traffic-light colour messages', () {
      expect(buildTrafficLightSpoken('red')['en'], contains('Red light'));
      expect(buildTrafficLightSpoken('green')['en'], contains('Green light'));
      expect(buildTrafficLightSpoken('yellow')['en'], contains('Yellow light'));
    });
  });

  group('UI screen strings are fully localized', () {
    // Representative sample across every localized screen.
    final maps = <String, Map<String, String>>{
      'lblSettings': lblSettings,
      'lblFamily': lblFamily,
      'lblCamera': lblCamera,
      'lblOnline': lblOnline,
      'lblWaitingGps': lblWaitingGps,
      'lblAddContact': lblAddContact,
      'lblPhoneNumber': lblPhoneNumber,
      'hintOrbIdle': hintOrbIdle,
      'lblTestCall': lblTestCall,
      'descAbout': descAbout,
      'lblTapToConfirmSos': lblTapToConfirmSos,
      'lblConfirmEmergency': lblConfirmEmergency,
    };

    test('every key has a non-empty fr / en / ar value', () {
      for (final e in maps.entries) {
        for (final lang in kLangs) {
          expect(e.value[lang], isNotNull, reason: '${e.key} missing $lang');
          expect(e.value[lang], isNotEmpty, reason: '${e.key} empty in $lang');
        }
      }
    });

    test('pick returns the requested language for a UI label', () {
      expect(pick(lblSettings, 'fr'), 'Paramètres');
      expect(pick(lblSettings, 'en'), 'Settings');
      expect(pick(lblSettings, 'ar'), 'الإعدادات');
    });

    test('SOS-confirm countdown placeholder is substitutable', () {
      final s = pick(lblConfirmEmergency, 'en').replaceAll('{s}', '7');
      expect(s, contains('7 seconds'));
      expect(s, isNot(contains('{s}')));
    });
  });
}
