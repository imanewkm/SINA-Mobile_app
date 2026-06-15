// Voice-command matching: priorities, disambiguation, noise tolerance, and the
// short-word safety guards. Pure logic — no Flutter bindings required.

// flutter_test re-exports matcher, which also defines `isNegative`; hide it so
// the name resolves to our command helper.
import 'package:flutter_test/flutter_test.dart' hide isNegative;
import 'package:sina_mobile/constants/commands.dart';

void main() {
  group('matchCommand — priorities & core commands', () {
    test('SOS always wins (all languages)', () {
      expect(matchCommand('au secours', 'fr'), 'sos');
      expect(matchCommand('aide moi', 'fr'), 'sos');
      expect(matchCommand('help me', 'en'), 'sos');
      expect(matchCommand('there is danger', 'en'), 'sos');
      expect(matchCommand('مساعدة', 'ar'), 'sos');
    });

    test('camera on/off and bare "stop"', () {
      expect(matchCommand('ouvre la caméra', 'fr'), 'camera_on');
      expect(matchCommand('open camera', 'en'), 'camera_on');
      expect(matchCommand('ferme la caméra', 'fr'), 'camera_off');
      expect(matchCommand('stop camera', 'en'), 'camera_off');
      // A bare stop/off with no noun stops the camera (the common case).
      expect(matchCommand('stop', 'en'), 'camera_off');
    });

    test('description and read-text', () {
      expect(matchCommand("qu'est-ce que tu vois", 'fr'), 'what_see');
      expect(matchCommand('what do you see', 'en'), 'what_see');
      expect(matchCommand('lis le texte', 'fr'), 'read_text');
      expect(matchCommand('read the text', 'en'), 'read_text');
    });

    test('settings, language switch, status, help', () {
      expect(matchCommand('ouvre les paramètres', 'fr'), 'settings');
      expect(matchCommand('open settings', 'en'), 'settings');
      expect(matchCommand('parle anglais', 'fr'), 'lang_en');
      expect(matchCommand('switch to arabic', 'en'), 'lang_ar');
      expect(matchCommand('état du système', 'fr'), 'status');
      expect(matchCommand('list my commands', 'en'), 'help');
    });

    test('volume up/down (direction-aware)', () {
      expect(matchCommand('monte le volume', 'fr'), 'volume_up');
      expect(matchCommand('baisse le son', 'fr'), 'volume_down');
      expect(matchCommand('volume up', 'en'), 'volume_up');
      expect(matchCommand('turn it lower', 'en'), 'volume_down');
    });

    test('GPS toggle vs location query', () {
      expect(matchCommand('active le gps', 'fr'), 'gps_on');
      expect(matchCommand('stop gps', 'en'), 'gps_off');
      // "where am I" must not flip location sharing.
      expect(matchCommand('où suis-je', 'fr'), 'where_am_i');
      expect(matchCommand('where am i', 'en'), 'where_am_i');
    });

    test('emergency-contact management (noun-anchored)', () {
      expect(matchCommand('ajoute un contact', 'fr'), 'add_contact');
      expect(matchCommand('liste mes contacts', 'fr'), 'list_contacts');
      expect(matchCommand('supprime les contacts', 'fr'), 'remove_contacts');
      expect(matchCommand('add a contact', 'en'), 'add_contact');
    });

    test('unrecognized phrases return null', () {
      expect(matchCommand('xyz abc', 'en'), isNull);
      expect(matchCommand('blabla', 'fr'), isNull);
    });
  });

  group('matchCommand — noise tolerance (fuzzy auto-fill)', () {
    test('recovers near-miss transcriptions', () {
      expect(matchCommand('ouvre la camra', 'fr'), 'camera_on'); // caméra
      expect(matchCommand('au secour', 'fr'), 'sos'); // secours
      expect(matchCommand('reglagee', 'fr'), 'settings'); // réglage(s)
      expect(matchCommand('open camra', 'en'), 'camera_on'); // camera
    });

    test('dropped accents still match whole words', () {
      expect(matchCommand('ouvre la camera', 'fr'), 'camera_on');
      expect(matchCommand('etat du systeme', 'fr'), 'status');
    });
  });

  group('matchCommand — safety guards (no false positives)', () {
    test('noise cannot false-fire SOS (short words are exact-only)', () {
      expect(matchCommand('sas', 'en'), isNot('sos'));
      expect(matchCommand('boss', 'en'), isNot('sos'));
      expect(matchCommand('say something', 'en'), isNot('sos'));
    });

    test('regression: "où" must not match inside "ouvre"', () {
      // Folding "où"->"ou" once made this resolve to where_am_i.
      expect(matchCommand('ouvre la caméra', 'fr'), 'camera_on');
      expect(matchCommand('ouvre la caméra', 'fr'), isNot('where_am_i'));
    });
  });

  group('yes / no / cancel answers', () {
    test('affirmative', () {
      expect(isAffirmative('oui', 'fr'), isTrue);
      expect(isAffirmative('yes please', 'en'), isTrue);
      expect(isAffirmative('نعم', 'ar'), isTrue);
      expect(isAffirmative('non', 'fr'), isFalse);
    });

    test('negative', () {
      expect(isNegative('non', 'fr'), isTrue);
      expect(isNegative('no thanks', 'en'), isTrue);
      expect(isNegative('oui', 'fr'), isFalse);
    });

    test('cancel', () {
      expect(isCancel('annule', 'fr'), isTrue);
      expect(isCancel('never mind', 'en'), isTrue);
      expect(isCancel('continue', 'en'), isFalse);
    });
  });

  group('parseSpokenDigits', () {
    test('maps spoken digit words', () {
      expect(parseSpokenDigits('zero six one two three', 'en'), '06123');
      expect(parseSpokenDigits('deux trois quatre', 'fr'), '234');
    });

    test('keeps literal digits and strips separators', () {
      expect(parseSpokenDigits('06 12 34', 'fr'), '061234');
    });

    test('preserves a leading plus', () {
      expect(parseSpokenDigits('plus deux trois', 'fr'), '+23');
      expect(parseSpokenDigits('plus six one', 'en'), '+61');
    });

    test('ignores non-digit words', () {
      expect(parseSpokenDigits('appelle deux quatre', 'fr'), '24');
    });
  });
}
