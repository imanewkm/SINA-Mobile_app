/// Voice command keyword tables and matcher.
///
/// Matching is `contains()` on the lowercased transcript, against the current
/// language only. The on/off-style toggles (camera, GPS, volume) are resolved
/// separately in [matchCommand] so a shared noun like "camera" or "gps" — or a
/// shared verb like "stop" — can never fire the wrong direction.
///
/// Matching is **fuzzy**: a transcript token within a small edit distance of a
/// keyword still matches (so "camra"→"caméra", "secour"→"secours"). Short words
/// (≤4 chars) match exactly only, to avoid noisy false positives.
library;

import 'dart:math' as math;

/// Keyword tables for the straightforward (non-toggle) commands.
const Map<String, Map<String, List<String>>> commands = {
  'sos': {
    'fr': ['aide', 'secours', 'danger', 'sos', 'urgence', 'maman'],
    'en': ['help', 'sos', 'danger', 'emergency'],
    'ar': ['مساعدة', 'نجدة', 'خطر', 'sos', 'ساعدني'],
  },
  'what_see': {
    'fr': ['vois', 'voit', 'regarde', 'décris', 'description'],
    'en': ['see', 'describe', 'description', 'look'],
    'ar': ['أرى', 'ترى', 'انظر', 'اوصف', 'وصف'],
  },
  'read_text': {
    'fr': ['lis', 'lire', 'lecture', 'texte', 'écrit'],
    'en': ['read', 'text'],
    'ar': ['اقرأ', 'قراءة', 'نص', 'مكتوب'],
  },
  'settings': {
    'fr': ['paramètres', 'paramètre', 'parametre', 'réglages', 'réglage'],
    'en': ['settings', 'preferences', 'parameters'],
    'ar': ['إعدادات', 'تفضيلات', 'خيارات'],
  },
  'lang_fr': {
    'fr': ['français'],
    'en': ['french'],
    'ar': ['فرنسية', 'فرنسي'],
  },
  'lang_en': {
    'fr': ['anglais'],
    'en': ['english'],
    'ar': ['إنجليزية', 'إنجليزي'],
  },
  'lang_ar': {
    'fr': ['arabe'],
    'en': ['arabic'],
    'ar': ['عربية', 'عربي'],
  },
  'status': {
    'fr': ['status', 'état', 'comment', 'ça va'],
    'en': ['status', 'state', 'system'],
    'ar': ['الحالة', 'النظام', 'كيف'],
  },
  // "help" here = "list my commands". The natural word "help"/"aide" is
  // intentionally reserved for SOS (above), so this is matched only by the
  // explicit "commands" phrasing.
  'help': {
    'fr': ['commande', 'commandes'],
    'en': ['command', 'commands'],
    'ar': ['أوامر', 'الأوامر'],
  },
};

/// Resolution order for the table-driven commands above (after the toggles).
const List<String> _tableOrder = [
  'what_see',
  'read_text',
  'settings',
  'lang_fr',
  'lang_en',
  'lang_ar',
  'status',
  'help',
];

// ── Toggle / direction words (resolved by [matchCommand], not the table) ──────

/// Words that mean "turn off / stop" for a toggle command.
const Map<String, List<String>> _offWords = {
  'fr': [
    'arrête', 'arrete', 'ferme', 'fermer', 'désactive', 'desactive',
    'coupe', 'éteins', 'eteins', 'stop', 'off'
  ],
  'en': ['stop', 'close', 'off', 'disable', 'end'],
  'ar': ['أوقف', 'وقف', 'أغلق', 'عطل', 'إيقاف'],
};

/// Camera triggers (nouns + "detect/obstacle" verbs, since the welcome prompt
/// teaches "open camera" / "detect obstacles").
const Map<String, List<String>> _cameraWords = {
  'fr': ['caméra', 'camera', 'détecter', 'détecte', 'detecter', 'obstacle'],
  'en': ['camera', 'detect', 'obstacle'],
  'ar': ['كاميرا', 'كشف', 'عوائق'],
};

/// Emergency-contact noun + the verbs that pick add / remove / list.
const Map<String, List<String>> _contactWords = {
  'fr': ['contact', 'contacts'],
  'en': ['contact', 'contacts'],
  'ar': ['جهة', 'جهات'],
};
const Map<String, List<String>> _addWords = {
  'fr': ['ajoute', 'ajouter', 'nouveau', 'nouvelle', 'enregistre', 'enregistrer'],
  'en': ['add', 'new', 'save', 'create'],
  'ar': ['أضف', 'إضافة', 'جديد'],
};
const Map<String, List<String>> _removeWords = {
  'fr': ['supprime', 'supprimer', 'efface', 'effacer', 'enlève', 'retire'],
  'en': ['remove', 'delete', 'clear', 'erase'],
  'ar': ['احذف', 'حذف', 'امسح', 'إزالة'],
};

/// GPS / location-sharing nouns.
const Map<String, List<String>> _gpsWords = {
  'fr': ['gps', 'localisation', 'partage'],
  'en': ['gps', 'location', 'sharing', 'share', 'tracking'],
  'ar': ['موقع', 'مشاركة', 'تتبع'],
};

/// "Where am I" interrogatives (checked before the GPS toggle so a location
/// *query* never flips location *sharing*).
const Map<String, List<String>> _whereWords = {
  'fr': ['où', 'suis-je', 'suis je'],
  'en': ['where'],
  'ar': ['أين'],
};

const Map<String, List<String>> _volumeNouns = {
  'fr': ['volume', 'son'],
  'en': ['volume', 'sound'],
  'ar': ['صوت', 'مستوى'],
};
const Map<String, List<String>> _volumeUp = {
  'fr': ['monte', 'augmente', 'augmenter', 'fort'],
  'en': ['up', 'louder', 'higher', 'increase'],
  'ar': ['أعلى', 'ارفع', 'أكثر'],
};
const Map<String, List<String>> _volumeDown = {
  'fr': ['baisse', 'moins', 'silence', 'bas', 'diminue', 'réduis', 'reduis'],
  'en': ['down', 'lower', 'softer', 'quiet', 'decrease'],
  'ar': ['أخفض', 'اخفض', 'أقل', 'هادئ'],
};

/// Yes/no answers to a spoken prompt (e.g. the recurring SOS check-in).
const Map<String, List<String>> _affirmative = {
  'fr': ['oui', 'ouais', 'd\'accord', 'envoie', 'envoyer', 'vas-y', 'ok', 'okay'],
  'en': ['yes', 'yeah', 'yep', 'ok', 'okay', 'sure', 'send', 'go ahead', 'please'],
  'ar': ['نعم', 'أجل', 'موافق', 'أرسل', 'حسنا', 'حسناً'],
};
const Map<String, List<String>> _negative = {
  'fr': ['non', 'arrête', 'arrete', 'stop', 'annule', 'pas besoin', 'ça va'],
  'en': ['no', 'nope', 'stop', 'cancel', 'fine', 'no thanks'],
  'ar': ['لا', 'توقف', 'ألغ', 'لا شكرا'],
};

/// Words that abort a guided dialog (adding a contact, etc.).
const Map<String, List<String>> _cancelWords = {
  'fr': ['annule', 'annuler', 'laisse tomber'],
  'en': ['cancel', 'never mind', 'forget it'],
  'ar': ['إلغاء', 'ألغ', 'انس'],
};

/// Spoken single-digit words → digit, for hands-free phone-number entry.
const Map<String, Map<String, String>> _digitWords = {
  'en': {
    'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9'
  },
  'fr': {
    'zéro': '0', 'zero': '0', 'un': '1', 'une': '1', 'deux': '2', 'trois': '3',
    'quatre': '4', 'cinq': '5', 'six': '6', 'sept': '7', 'huit': '8', 'neuf': '9'
  },
  'ar': {
    'صفر': '0', 'واحد': '1', 'اثنان': '2', 'اثنين': '2', 'ثلاثة': '3',
    'أربعة': '4', 'اربعة': '4', 'خمسة': '5', 'ستة': '6', 'سبعة': '7',
    'ثمانية': '8', 'تسعة': '9'
  },
};

// ── Fuzzy keyword matching (noise / mis-transcription tolerance) ─────────────

/// Diacritic folding so a recognizer that drops accents ("parametre" for
/// "paramètre") still matches. Arabic has no equivalent folding here.
const Map<String, String> _accentFold = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
};

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_accentFold[ch] ?? ch);
  }
  return b.toString();
}

/// Levenshtein edit distance (two-row, O(m·n) time, O(n) space).
int _lev(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var cur = List<int>.filled(n + 1, 0);
  for (int i = 1; i <= m; i++) {
    cur[0] = i;
    for (int j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[n];
}

/// Allowed edit distance, scaled by keyword length. Short words demand an exact
/// match (a 1-edit window on a 3-letter word matches far too much).
int _fuzzTolerance(int len) {
  if (len <= 4) return 0;
  if (len <= 7) return 1;
  return 2;
}

bool _tokenMatches(String token, String keyword) {
  if (token == keyword) return true;
  final tol = _fuzzTolerance(keyword.length);
  if (tol == 0) return false;
  if ((token.length - keyword.length).abs() > tol) return false;
  return _lev(token, keyword) <= tol;
}

/// True if [keyword] appears in [text] exactly (substring) or fuzzily (a single
/// transcript token within edit-distance tolerance).
///
/// The exact check runs on the **unfolded** text, identical to the original
/// `contains()` matcher — so accent folding can never create a new substring
/// collision (e.g. a folded "où"→"ou" matching inside "ouvre"). Folding is used
/// only for the fuzzy token fallback, which recovers mis-transcriptions and
/// dropped accents on whole words.
bool _matchesKeyword(String text, String keyword) {
  if (keyword.contains(' ')) return text.contains(keyword);
  if (text.contains(keyword)) return true;
  final k = _fold(keyword);
  for (final tok in _fold(text).split(RegExp(r'[^a-z0-9؀-ۿ]+'))) {
    if (tok.isEmpty) continue;
    if (_tokenMatches(tok, k)) return true;
  }
  return false;
}

bool _hasAny(String text, List<String>? words) =>
    words != null && words.any((w) => _matchesKeyword(text, w));

/// True if [text] is an affirmative ("yes/send/ok") answer in [lang].
bool isAffirmative(String text, String lang) => _hasAny(text, _affirmative[lang]);

/// True if [text] is a negative ("no/stop/cancel") answer in [lang].
bool isNegative(String text, String lang) => _hasAny(text, _negative[lang]);

/// True if [text] asks to cancel/abort the current guided dialog.
bool isCancel(String text, String lang) => _hasAny(text, _cancelWords[lang]);

/// Extract a phone number from a spoken [text]: keeps literal digits and maps
/// spoken digit-words (zero..nine) in [lang]. Preserves a leading '+' if the
/// user said "plus" or "+". Best used with a spoken read-back confirmation.
String parseSpokenDigits(String text, String lang) {
  final lower = text.toLowerCase();
  final hasPlus =
      lower.contains('+') || lower.contains('plus') || lower.contains('زائد');
  final words = _digitWords[lang] ?? const {};
  final buf = StringBuffer();
  for (final tok in lower.split(RegExp(r'[\s,.\-_/()]+'))) {
    if (tok.isEmpty) continue;
    final raw = tok.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isNotEmpty) {
      buf.write(raw);
    } else if (words[tok] != null) {
      buf.write(words[tok]);
    }
  }
  final digits = buf.toString();
  return (hasPlus && digits.isNotEmpty) ? '+$digits' : digits;
}

/// Returns true if [text] (already lowercased) matches [key] in [lang].
bool commandMatches(String text, String key, String lang) =>
    _hasAny(text, commands[key]?[lang]);

/// Resolve a transcript to a command key, or null if nothing matches.
///
/// SOS always wins. Toggles (camera/GPS/volume) are direction-aware: a shared
/// noun or the bare verb "stop" can't fire the wrong command.
String? matchCommand(String text, String lang) {
  if (commandMatches(text, 'sos', lang)) return 'sos';

  final off = _hasAny(text, _offWords[lang]);

  // Location query before GPS toggle ("where am I" must not flip sharing).
  if (_hasAny(text, _whereWords[lang])) return 'where_am_i';

  // Emergency-contact management (noun-anchored; verb picks the action).
  if (_hasAny(text, _contactWords[lang])) {
    if (_hasAny(text, _addWords[lang])) return 'add_contact';
    if (_hasAny(text, _removeWords[lang]) || off) return 'remove_contacts';
    return 'list_contacts';
  }

  // GPS sharing on/off (noun-anchored).
  if (_hasAny(text, _gpsWords[lang])) return off ? 'gps_off' : 'gps_on';

  // Camera on/off (noun/verb-anchored).
  if (_hasAny(text, _cameraWords[lang])) return off ? 'camera_off' : 'camera_on';

  // Volume up/down (direction-aware; a bare "volume" defaults to louder).
  if (_hasAny(text, _volumeDown[lang])) return 'volume_down';
  if (_hasAny(text, _volumeUp[lang]) || _hasAny(text, _volumeNouns[lang])) {
    return 'volume_up';
  }

  for (final key in _tableOrder) {
    if (commandMatches(text, key, lang)) return key;
  }

  // A bare "stop" / "off" with no noun → stop the camera (the common case).
  if (off) return 'camera_off';
  return null;
}
