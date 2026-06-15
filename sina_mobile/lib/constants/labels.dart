/// All multilingual strings + spoken-sentence builders.
/// Ported verbatim from app.py (LABELS, POS_LABELS, DIST_LABELS, UI,
/// _build_spoken, _build_grouped_spoken) and the inline phrases in assistant.js.
library;

const List<String> kLangs = ['fr', 'en', 'ar'];

/// Language → BCP-47 locale for TTS and STT.
const Map<String, String> langToLocale = {
  'fr': 'fr-FR',
  'en': 'en-US',
  'ar': 'ar-SA',
};

/// Object label translations.
const Map<String, Map<String, String>> labels = {
  'person': {'fr': 'Personne', 'en': 'Person', 'ar': 'شخص'},
  'bicycle': {'fr': 'Vélo', 'en': 'Bicycle', 'ar': 'دراجة'},
  'car': {'fr': 'Voiture', 'en': 'Car', 'ar': 'سيارة'},
  'motorcycle': {'fr': 'Moto', 'en': 'Motorcycle', 'ar': 'دراجة نارية'},
  'bus': {'fr': 'Bus', 'en': 'Bus', 'ar': 'حافلة'},
  'truck': {'fr': 'Camion', 'en': 'Truck', 'ar': 'شاحنة'},
  'traffic light': {'fr': 'Feu', 'en': 'Traffic light', 'ar': 'إشارة مرور'},
  'stop sign': {'fr': 'Panneau stop', 'en': 'Stop sign', 'ar': 'علامة توقف'},
  'bench': {'fr': 'Banc', 'en': 'Bench', 'ar': 'مقعد'},
  'dog': {'fr': 'Chien', 'en': 'Dog', 'ar': 'كلب'},
  'potted plant': {'fr': 'Plante', 'en': 'Plant', 'ar': 'نبتة'},
  // ── Navigation classes (OOD custom model) ──────────────────────────────────
  'tree': {'fr': 'Arbre', 'en': 'Tree', 'ar': 'شجرة'},
  'train': {'fr': 'Train', 'en': 'Train', 'ar': 'قطار'},
  'pole': {'fr': 'Poteau', 'en': 'Pole', 'ar': 'عمود'},
  'crutch': {'fr': 'Béquille', 'en': 'Crutch', 'ar': 'عكاز'},
  'bus stop': {'fr': 'Arrêt de bus', 'en': 'Bus stop', 'ar': 'محطة حافلات'},
  'curb': {'fr': 'Bordure', 'en': 'Curb', 'ar': 'حافة الرصيف'},
  'fire hydrant': {
    'fr': "Bouche d'incendie",
    'en': 'Fire hydrant',
    'ar': 'صنبور حريق'
  },
  'spherical roadblock': {'fr': 'Borne', 'en': 'Roadblock', 'ar': 'حاجز كروي'},
  'stairs': {'fr': 'Escalier', 'en': 'Stairs', 'ar': 'درج'},
  'street light': {'fr': 'Lampadaire', 'en': 'Street light', 'ar': 'مصباح شارع'},
  'warning column': {
    'fr': "Borne d'avertissement",
    'en': 'Warning post',
    'ar': 'عمود تحذير'
  },
  'waste container': {'fr': 'Poubelle', 'en': 'Bin', 'ar': 'حاوية نفايات'},
  'door': {'fr': 'Porte', 'en': 'Door', 'ar': 'باب'},
  'crosswalk': {'fr': 'Passage piéton', 'en': 'Crosswalk', 'ar': 'ممر المشاة'},
  // Generic fallback for a low-confidence detection the model can't name.
  'object': {'fr': 'Objet', 'en': 'Object', 'ar': 'جسم'},
};

/// Position spoken labels.
const Map<String, Map<String, String>> posLabels = {
  'left': {'fr': 'à votre gauche', 'en': 'on your left', 'ar': 'على يسارك'},
  'center': {'fr': 'devant vous', 'en': 'ahead of you', 'ar': 'أمامك'},
  'right': {'fr': 'à votre droite', 'en': 'on your right', 'ar': 'على يمينك'},
};

/// Core UI strings (welcome, camera, alert, not_found) per language.
const Map<String, Map<String, String>> ui = {
  'fr': {
    'welcome':
        "Bonjour, je suis SINA, votre assistant de mobilité. Pour détecter les obstacles, dites ouvre caméra. Pour l'arrêter, dites stop. En cas de danger, dites danger et j'alerterai immédiatement votre famille. Je vous écoute.",
    'camera_on': 'Caméra activée. Je surveille les obstacles et vous préviens.',
    'camera_off': 'Caméra désactivée. Dites ouvre caméra pour reprendre.',
    'camera_error':
        "Impossible d'ouvrir la caméra. Vérifiez qu'elle est connectée.",
    'alert_sent':
        "Alerte envoyée à votre famille. Restez calme, de l'aide est en route.",
    'not_found':
        "Je n'ai pas compris. Dites ouvre caméra, stop, ou danger en cas de besoin.",
  },
  'en': {
    'welcome':
        'Hello, I am SINA, your mobility assistant. To detect obstacles, say open camera. To stop it, say stop camera. In case of danger, say help and I will immediately alert your family. I am listening.',
    'camera_on': 'Camera activated. I am monitoring for obstacles.',
    'camera_off': 'Camera deactivated. Say open camera to resume.',
    'camera_error': 'Could not open the camera. Please check it is connected.',
    'alert_sent': 'Alert sent to your family. Stay calm, help is on the way.',
    'not_found':
        'I did not understand. Say open camera, stop camera, or help in case of danger.',
  },
  'ar': {
    'welcome':
        'مرحباً، أنا سينا، مساعدك للتنقل. للكشف عن العوائق، قل افتح الكاميرا. لإيقافها، قل أغلق الكاميرا. في حالة خطر، قل مساعدة وسأنبّه عائلتك فوراً. أنا أستمع.',
    'camera_on': 'تم تشغيل الكاميرا. أراقب العوائق وسأنبهك.',
    'camera_off': 'تم إيقاف الكاميرا. قل افتح الكاميرا للمتابعة.',
    'camera_error': 'تعذر فتح الكاميرا. تأكد من توصيلها.',
    'alert_sent': 'تم إرسال التنبيه لعائلتك. ابقَ هادئاً، المساعدة في الطريق.',
    'not_found': 'لم أفهم. قل افتح الكاميرا، أغلق الكاميرا، أو مساعدة في حالة خطر.',
  },
};

String t(String lang, String key) => ui[lang]?[key] ?? ui['fr']![key] ?? '';

bool _isVowel(String c) => 'aeiouAEIOU'.contains(c);

/// Single-object spoken alert — port of _build_spoken (returns all languages).
Map<String, String> buildSpoken(String label, String distKey, String posKey) {
  final out = <String, String>{};
  for (final lang in kLangs) {
    final obj = labels[label]?[lang] ?? label;
    final pos = posLabels[posKey]?[lang] ?? '';
    if (lang == 'fr') {
      switch (distKey) {
        case 'very_close':
          out[lang] = 'Attention : $obj très proche $pos. Arrêtez-vous ou bougez.';
          break;
        case 'close':
          out[lang] = '$obj à 1 mètre $pos. Vous pouvez marcher, restez prudent.';
          break;
        case 'medium':
          out[lang] = '$obj à 2-4 mètres $pos. Vous pouvez marcher librement.';
          break;
        default:
          out[lang] = '$obj au loin $pos. Pas de danger immédiat.';
      }
    } else if (lang == 'en') {
      final article = (obj.isNotEmpty && _isVowel(obj[0])) ? 'An' : 'A';
      switch (distKey) {
        case 'very_close':
          out[lang] =
              'Caution: ${article.toLowerCase()} $obj very close $pos. Stop or move away.';
          break;
        case 'close':
          out[lang] = '$article $obj at 1 meter $pos. Safe to walk, stay alert.';
          break;
        case 'medium':
          out[lang] =
              '$article $obj at 2 to 4 meters $pos. You can walk freely.';
          break;
        default:
          out[lang] = '$article $obj far away $pos. No immediate danger.';
      }
    } else {
      switch (distKey) {
        case 'very_close':
          out[lang] = 'تنبيه: $obj قريب جداً $pos. توقف أو تحرك بعيداً.';
          break;
        case 'close':
          out[lang] = '$obj على متر واحد $pos. آمن للمشي، بقَ حذراً.';
          break;
        case 'medium':
          out[lang] = '$obj على بعد 2 إلى 4 أمتار $pos. يمكنك المشي بحرية.';
          break;
        default:
          out[lang] = '$obj بعيد $pos. لا يوجد خطر فوري.';
      }
    }
  }
  return out;
}

/// Grouped (multiple objects, same distance+position) — port of
/// _build_grouped_spoken.
Map<String, String> buildGroupedSpoken(
    List<String> groupLabels, String distKey, String posKey) {
  final out = <String, String>{};
  for (final lang in kLangs) {
    final objList = groupLabels.map((l) => labels[l]?[lang] ?? l).toList();
    final pos = posLabels[posKey]?[lang] ?? '';
    if (lang == 'en') {
      final objStr = objList.length > 1 ? objList.join(' and ') : objList[0];
      final article =
          (objList[0].isNotEmpty && _isVowel(objList[0][0])) ? 'An' : 'A';
      switch (distKey) {
        case 'very_close':
          out[lang] = 'Multiple obstacles: $objStr very close $pos. Stop immediately.';
          break;
        case 'close':
          out[lang] = '$article $objStr $pos at 1 meter. Walk carefully.';
          break;
        case 'medium':
          out[lang] = '$article $objStr $pos at 2 to 4 meters. Path is clear.';
          break;
        default:
          out[lang] = '$article $objStr $pos in the distance.';
      }
    } else if (lang == 'fr') {
      final objStr = objList.join(' et ');
      switch (distKey) {
        case 'very_close':
          out[lang] =
              'Plusieurs obstacles: $objStr très proches $pos. Arrêtez-vous immédiatement.';
          break;
        case 'close':
          out[lang] = '$objStr $pos à 1 mètre. Marchez prudemment.';
          break;
        case 'medium':
          out[lang] = '$objStr $pos à 2-4 mètres. Le chemin est libre.';
          break;
        default:
          out[lang] = '$objStr $pos au loin.';
      }
    } else {
      final objStr = objList.join(' و');
      switch (distKey) {
        case 'very_close':
          out[lang] = 'عوائق متعددة: $objStr قريبة جداً $pos. توقف فوراً.';
          break;
        case 'close':
          out[lang] = '$objStr $pos على متر واحد. امش بحذر.';
          break;
        case 'medium':
          out[lang] = '$objStr $pos على 2 إلى 4 أمتار. المسار واضح.';
          break;
        default:
          out[lang] = '$objStr $pos في البعيد.';
      }
    }
  }
  return out;
}

/// Traffic-light state announcement (red/green/yellow). Heuristic colour only.
Map<String, String> buildTrafficLightSpoken(String state) {
  switch (state) {
    case 'red':
      return _m(
        'Feu rouge. Veuillez attendre, ne traversez pas.',
        'Red light. Please wait, do not cross.',
        'إشارة حمراء. انتظر من فضلك، لا تعبر.',
      );
    case 'green':
      return _m(
        'Feu vert. Vous pouvez traverser, restez prudent.',
        'Green light. You may cross, stay alert.',
        'إشارة خضراء. يمكنك العبور، ابقَ حذراً.',
      );
    default: // yellow
      return _m(
        'Feu orange. Ne commencez pas à traverser.',
        'Yellow light. Do not start crossing.',
        'إشارة صفراء. لا تبدأ بالعبور.',
      );
  }
}

/// "Many obstacles, <distance>" summary — port of the >5 branch in app.py.
Map<String, String> buildManySpoken(String distKey) {
  String fr, en, ar;
  switch (distKey) {
    case 'very_close':
      fr = 'juste devant';
      en = 'right ahead';
      ar = 'أمامك مباشرة';
      break;
    case 'close':
      fr = '1 mètre';
      en = '1 meter away';
      ar = 'متر واحد';
      break;
    case 'medium':
      fr = '2-4 mètres';
      en = '2-4 meters away';
      ar = '2-4 أمتار';
      break;
    default:
      fr = 'au loin';
      en = 'far away';
      ar = 'بعيد';
  }
  return {
    'fr': "Beaucoup d'obstacles, $fr",
    'en': 'Many obstacles, $en',
    'ar': 'عوائق كثيرة $ar',
  };
}

// ── Misc spoken phrases (ported from assistant.js inline strings) ────────────

Map<String, String> _m(String fr, String en, String ar) =>
    {'fr': fr, 'en': en, 'ar': ar};

String pick(Map<String, String> m, String lang) => m[lang] ?? m['fr'] ?? '';

final Map<String, String> msgVolume = _m(
  'Volume à {pct} pour cent',
  'Volume at {pct} percent',
  'مستوى الصوت في {pct} في المئة',
);

final Map<String, String> msgGpsOn = _m(
  'Partage de localisation activé. Votre famille peut voir votre position.',
  'Location sharing enabled. Your family can see your position.',
  'مشاركة الموقع مفعّلة. يمكن لعائلتك أن ترى موقعك.',
);

final Map<String, String> msgGpsOff = _m(
  'Partage de localisation désactivé.',
  'Location sharing disabled.',
  'مشاركة الموقع معطّلة.',
);

final Map<String, String> msgLocationUnavailable = _m(
  'Localisation indisponible',
  'Location not available',
  'الموقع غير متاح',
);

final Map<String, String> msgGpsStale = _m(
  'Localisation indisponible. Vérifiez vos paramètres GPS.',
  'Location data stale. Check your GPS settings.',
  'بيانات الموقع قديمة. تحقق من إعدادات GPS.',
);

/// Short re-activation cue. Spoken when the user taps the orb to resume (the
/// full welcome/tutorial is only spoken once, on first activation).
final Map<String, String> msgResume = _m(
  'Je vous écoute.',
  "I'm listening.",
  'أنا أستمع.',
);

final Map<String, String> msgMicBlocked = _m(
  'Microphone refusé. Activez-le dans les paramètres.',
  'Microphone blocked. Please enable it in settings.',
  'الميكروفون محظور. فعّله في الإعدادات.',
);

final Map<String, String> msgOpenCameraToSee = _m(
  'Ouvre la caméra pour que je puisse voir.',
  'Open the camera so I can see.',
  'افتح الكاميرا حتى أتمكن من الرؤية.',
);

final Map<String, String> msgNothingSeen = _m(
  "Je ne vois rien en ce moment. C'est clair devant vous.",
  "I don't see anything right now. It's clear ahead.",
  'لا أرى شيئاً الآن. الطريق خالي أمامك.',
);

final Map<String, String> msgOpeningSettings = _m(
  'Ouverture des paramètres...',
  'Opening settings...',
  'جارٍ فتح الإعدادات...',
);

final Map<String, String> msgReadingText = _m(
  'Je lis le texte, tenez la caméra immobile.',
  'Reading the text, hold the camera steady.',
  'أقرأ النص، أمسك الكاميرا بثبات.',
);

final Map<String, String> msgNoText = _m(
  "Je n'ai trouvé aucun texte lisible.",
  "I couldn't find any readable text.",
  'لم أعثر على نص مقروء.',
);

final Map<String, String> msgSosConfirm = _m(
  "Alerte envoyée à votre famille. De l'aide est en route. Restez calme. Après 30 secondes, je vérifierai si vous avez toujours besoin d'aide.",
  'Alert sent to your family. Help is coming. Stay calm. I will check in after 30 seconds.',
  'تم إرسال التنبيه لعائلتك. المساعدة في الطريق. ابقَ هادئاً. سأتحقق بعد 30 ثانية.',
);

final Map<String, String> msgSosCheckIn = _m(
  'Ça va mieux? Vous pouvez dire oui ou appeler à nouveau à l\'aide.',
  'Are you okay? You can say yes or call for help again.',
  'هل أنت بخير؟ يمكنك قول نعم أو استدعاء المساعدة مرة أخرى.',
);

final Map<String, String> msgSosAlert = _m(
  "Besoin d'aide urgente",
  'Urgent help needed',
  'بحاجة إلى مساعدة عاجلة',
);

/// Body of the autonomous SOS text message sent to the family contact.
/// Includes a tappable Google Maps link when a GPS fix is available.
String buildSosSms(String lang, double? lat, double? lng) {
  final loc =
      (lat != null && lng != null) ? 'https://maps.google.com/?q=$lat,$lng' : '';
  switch (lang) {
    case 'ar':
      final l = loc.isEmpty ? '' : ' الموقع: $loc';
      return 'نداء استغاثة من سينا. أحتاج مساعدة عاجلة.$l';
    case 'en':
      final l = loc.isEmpty ? '' : ' Location: $loc';
      return 'SOS from SINA. I need urgent help.$l';
    default:
      final l = loc.isEmpty ? '' : ' Position: $loc';
      return "SOS depuis SINA. J'ai besoin d'aide urgente.$l";
  }
}

final Map<String, String> msgSosSmsSent = _m(
  "Message envoyé à votre famille avec votre position. Restez calme, de l'aide arrive. Je vérifierai régulièrement avec vous.",
  'Message sent to your family with your location. Stay calm, help is coming. I will keep checking in with you.',
  'تم إرسال رسالة لعائلتك مع موقعك. ابقَ هادئاً، المساعدة في الطريق. سأتفقدك بانتظام.',
);

final Map<String, String> msgSosSmsSentCalling = _m(
  "Message envoyé à votre famille avec votre position. J'appelle maintenant votre famille pour être sûr qu'elle voie le message.",
  'Message sent to your family with your location. I am now calling them to make sure they see it.',
  'تم إرسال رسالة لعائلتك مع موقعك. أتصل بهم الآن للتأكد من أنهم رأوا الرسالة.',
);

/// Spoken when an SOS is detected but a tap is required to confirm it.
final Map<String, String> msgSosConfirmPrompt = _m(
  "Urgence détectée. Touchez n'importe où sur l'écran pour confirmer. J'annule dans dix secondes si vous ne touchez pas.",
  'Emergency detected. Tap anywhere on the screen to confirm. I will cancel in ten seconds if you do not tap.',
  'تم رصد حالة طوارئ. المس أي مكان على الشاشة للتأكيد. سألغي خلال عشر ثوانٍ إذا لم تلمس.',
);

final Map<String, String> msgSosCancelled = _m(
  "Alerte annulée. Je continue à vous écouter. Dites danger pour réessayer.",
  "Alert cancelled. I'm still listening. Say help to try again.",
  'تم إلغاء التنبيه. ما زلت أستمع. قل مساعدة للمحاولة مرة أخرى.',
);

/// Recurring prompt offering to send a fresh location update to the contacts.
final Map<String, String> msgSosResendPrompt = _m(
  "Avez-vous toujours besoin d'aide ? Dites oui pour envoyer une nouvelle position à votre famille, ou dites stop pour arrêter.",
  'Do you still need help? Say yes to send your family an updated location, or say stop to end.',
  'هل ما زلت بحاجة إلى مساعدة؟ قل نعم لإرسال موقع جديد لعائلتك، أو قل توقف للإيقاف.',
);

final Map<String, String> msgSosResendSent = _m(
  'Nouvelle position envoyée à votre famille.',
  'Updated location sent to your family.',
  'تم إرسال موقعك الجديد لعائلتك.',
);

final Map<String, String> msgSosSharingStopped = _m(
  "D'accord, j'arrête d'envoyer des mises à jour. Dites danger si vous avez encore besoin d'aide.",
  "Okay, I'll stop sending updates. Say help if you still need it.",
  'حسناً، سأتوقف عن إرسال التحديثات. قل مساعدة إذا احتجت.',
);

// ── Hands-free contact management ────────────────────────────────────────────

final Map<String, String> msgContactsNone = _m(
  "Vous n'avez aucun contact d'urgence. Dites ajouter un contact pour en créer un.",
  'You have no emergency contacts. Say add a contact to create one.',
  'ليس لديك جهات اتصال للطوارئ. قل أضف جهة اتصال لإنشاء واحدة.',
);

final Map<String, String> msgContactsList = _m(
  "Vos contacts d'urgence sont :",
  'Your emergency contacts are:',
  'جهات اتصال الطوارئ هي:',
);

final Map<String, String> msgAskName = _m(
  "Quel est le nom du contact ? Dites annuler pour arrêter.",
  "What is the contact's name? Say cancel to stop.",
  'ما اسم جهة الاتصال؟ قل إلغاء للتوقف.',
);

final Map<String, String> msgAskPhone = _m(
  'Dites maintenant le numéro de téléphone, chiffre par chiffre.',
  'Now say the phone number, digit by digit.',
  'الآن قل رقم الهاتف، رقماً رقماً.',
);

final Map<String, String> msgAskPhoneAgain = _m(
  "D'accord. Redites le numéro, chiffre par chiffre.",
  'Okay. Say the number again, digit by digit.',
  'حسناً. أعد قول الرقم رقماً رقماً.',
);

final Map<String, String> msgPhoneTooShort = _m(
  "Je n'ai pas bien saisi le numéro. Redites-le lentement, chiffre par chiffre.",
  "I didn't catch the number. Please say it slowly, digit by digit.",
  'لم ألتقط الرقم جيداً. أعد قوله ببطء، رقماً رقماً.',
);

/// {num} is replaced with the spaced-out digits so TTS reads each one.
final Map<String, String> msgConfirmNumber = _m(
  "J'ai entendu {num}. Est-ce correct ? Dites oui ou non.",
  'I heard {num}. Is that correct? Say yes or no.',
  'سمعت {num}. هل هذا صحيح؟ قل نعم أو لا.',
);

/// {name} is replaced with the saved contact name.
final Map<String, String> msgContactSaved = _m(
  'Contact {name} enregistré.',
  'Contact {name} saved.',
  'تم حفظ جهة الاتصال {name}.',
);

final Map<String, String> msgContactCancelled = _m(
  "D'accord, j'annule.",
  'Okay, cancelled.',
  'حسناً، تم الإلغاء.',
);

final Map<String, String> msgYesOrNo = _m(
  'Dites oui ou non.',
  'Please say yes or no.',
  'قل نعم أو لا.',
);

final Map<String, String> msgClearContactsConfirm = _m(
  "Voulez-vous vraiment supprimer tous les contacts d'urgence ? Dites oui ou non.",
  'Do you really want to delete all emergency contacts? Say yes or no.',
  'هل تريد حقاً حذف جميع جهات اتصال الطوارئ؟ قل نعم أو لا.',
);

final Map<String, String> msgContactsCleared = _m(
  'Tous les contacts ont été supprimés.',
  'All contacts have been deleted.',
  'تم حذف جميع جهات الاتصال.',
);

final Map<String, String> msgContactsKept = _m(
  "D'accord, je garde vos contacts.",
  "Okay, I'll keep your contacts.",
  'حسناً، سأحتفظ بجهات اتصالك.',
);

// ── First-run onboarding ─────────────────────────────────────────────────────

final Map<String, String> msgOnboardWelcome = _m(
  "Bienvenue dans SINA. Avant de commencer, ajoutez au moins un contact d'urgence. En cas de danger, j'enverrai votre position à ce contact. Saisissez le numéro, ou demandez à un proche de le faire, puis touchez Continuer.",
  "Welcome to SINA. Before we start, please add at least one emergency contact. In an emergency I will send your location to this contact. Enter the number, or ask a relative to help, then tap Continue.",
  'مرحباً بك في سينا. قبل أن نبدأ، أضف جهة اتصال طوارئ واحدة على الأقل. في حالة الخطر، سأرسل موقعك إلى جهة الاتصال هذه. أدخل الرقم أو اطلب المساعدة من أحد أقاربك، ثم المس متابعة.',
);

final Map<String, String> lblOnboardTitle = _m(
  'Contact d\'urgence',
  'Emergency contact',
  'جهة اتصال الطوارئ',
);

final Map<String, String> lblOnboardIntro = _m(
  "Ajoutez au moins un contact d'urgence. SINA lui enverra votre position en cas de danger. Ces contacts sont enregistrés pour les prochaines fois.",
  'Add at least one emergency contact. SINA will text them your location in an emergency. These are saved for next time.',
  'أضف جهة اتصال طوارئ واحدة على الأقل. سيرسل سينا موقعك إليها عند الخطر. تُحفظ هذه جهات الاتصال للمرات القادمة.',
);

final Map<String, String> lblContinue = _m('Continuer', 'Continue', 'متابعة');

final Map<String, String> msgOnboardNeedContact = _m(
  "Ajoutez d'abord un numéro de téléphone.",
  'Please add a phone number first.',
  'أضف رقم هاتف أولاً.',
);

// ── Screen / UI strings (settings, family, contacts, home) ───────────────────
// On-screen labels for the low-vision UI. Spoken content is localized elsewhere;
// these keep the *visual* interface in the user's language too (incl. RTL ar).

// Settings — section titles
final Map<String, String> lblSettings = _m('Paramètres', 'Settings', 'الإعدادات');
final Map<String, String> lblSpeechSpeed =
    _m('Vitesse de parole', 'Speech Speed', 'سرعة الكلام');
final Map<String, String> lblVolume = _m('Volume', 'Volume', 'مستوى الصوت');
final Map<String, String> lblSoundEffects =
    _m('Effets sonores', 'Sound Effects', 'المؤثرات الصوتية');
final Map<String, String> lblAccessibility =
    _m('Accessibilité', 'Accessibility', 'إمكانية الوصول');
final Map<String, String> lblDetectionSensitivity =
    _m('Sensibilité de détection', 'Detection Sensitivity', 'حساسية الكشف');
final Map<String, String> lblLocationServices =
    _m('Localisation (GPS)', 'Location Services (GPS)', 'خدمات الموقع (GPS)');
final Map<String, String> lblCameraAutoStart =
    _m('Démarrage auto de la caméra', 'Camera Auto-Start', 'تشغيل تلقائي للكاميرا');
final Map<String, String> lblEmergencyContacts =
    _m("Contacts d'urgence", 'Emergency Contacts', 'جهات اتصال الطوارئ');
final Map<String, String> lblEmergencyBehaviour =
    _m("Comportement d'urgence", 'Emergency Behaviour', 'سلوك الطوارئ');
final Map<String, String> lblAbout = _m('À propos', 'About', 'حول');

// Settings — speech-speed descriptors
final Map<String, String> lblSlow = _m('Lente', 'Slow', 'بطيئة');
final Map<String, String> lblNormalSpeed = _m('Normale', 'Normal', 'عادية');
final Map<String, String> lblFast = _m('Rapide', 'Fast', 'سريعة');
final Map<String, String> lblVeryFast = _m('Très rapide', 'Very Fast', 'سريعة جداً');

// Settings — sensitivity descriptors
final Map<String, String> lblQuiet = _m('Calme', 'Quiet', 'هادئ');
final Map<String, String> lblMedium = _m('Moyen', 'Medium', 'متوسط');
final Map<String, String> lblNoisy = _m('Bruyant', 'Noisy', 'صاخب');

// Settings — toggles
final Map<String, String> lblBeepsHaptics =
    _m('Bips et vibrations', 'Beeps & haptics', 'أصوات واهتزازات');
final Map<String, String> lblHighContrast = _m('Contraste élevé / grands boutons',
    'High-contrast / large buttons', 'تباين عالٍ / أزرار كبيرة');
final Map<String, String> lblWarnUnknown = _m('Signaler les objets non reconnus',
    'Warn about unrecognized objects', 'التنبيه للأجسام غير المعروفة');
final Map<String, String> lblDepthDistance =
    _m('Distance par profondeur', 'Depth-based distance', 'المسافة بالعمق');
final Map<String, String> lblLocationSharing =
    _m('Partage de localisation', 'Location sharing', 'مشاركة الموقع');
final Map<String, String> lblAutoActivateCamera = _m('Activer la caméra automatiquement',
    'Auto-activate camera', 'تفعيل الكاميرا تلقائياً');
final Map<String, String> lblConfirmSosToggle = _m('Confirmer le SOS (10s)',
    'Tap to confirm SOS (10s countdown)', 'تأكيد الاستغاثة (10 ثوانٍ)');
final Map<String, String> lblCallFirstContact = _m('Appeler le premier contact après un SOS',
    'Call first contact after sending SOS', 'الاتصال بأول جهة بعد الاستغاثة');

// Settings — descriptions
final Map<String, String> descAccessibility = _m(
  "Cibles tactiles plus grandes, libellés en gras et couleurs blanc sur noir pour les malvoyants. Appui long n'importe où sur l'accueil pour envoyer un SOS.",
  'Bigger touch targets, bold labels and white-on-black colours for low-vision users. Long-press anywhere on the home screen to send an SOS.',
  'أهداف لمس أكبر، تسميات عريضة وألوان أبيض على أسود لضعاف البصر. اضغط مطولاً في أي مكان على الشاشة الرئيسية لإرسال استغاثة.',
);
final Map<String, String> descSensitivity = _m(
  '1=Environnements calmes, 2=Normal, 3=Environnements bruyants',
  '1=Quiet environments, 2=Normal, 3=Noisy environments',
  '1=بيئات هادئة، 2=عادي، 3=بيئات صاخبة',
);
final Map<String, String> descWarnUnknown = _m(
  "En cas de doute sur un objet, prévenir quand même « objet détecté » s'il est proche",
  'When unsure what an object is, still warn "object detected" if it is close',
  'عند عدم التأكد من الجسم، نبّه «جسم مكتشف» إذا كان قريباً',
);
final Map<String, String> descDepth = _m(
  "Utiliser le modèle de profondeur monoculaire pour une distance réelle si disponible (sinon estimation par taille).",
  'Use the monocular depth model for real distance when available (falls back to size-based estimate)',
  'استخدم نموذج العمق الأحادي للمسافة الحقيقية عند توفره (وإلا تقدير بالحجم).',
);
final Map<String, String> descLocationSharing = _m(
  "Partager la localisation uniquement lors de l'envoi d'une alerte SOS à la famille",
  'Share location only when sending an SOS alert to family',
  'شارك الموقع فقط عند إرسال تنبيه استغاثة للعائلة',
);
final Map<String, String> descEmergencyContacts = _m(
  "Lors d'un SOS, SINA envoie à chaque contact un SMS automatique avec un lien de carte vers la position — sans toucher l'écran, et même sans internet. Le premier contact est aussi appelé.",
  "On SOS, SINA texts every contact an automatic message with a map link to the user's location — no tapping needed, and it works without internet. The first contact is also called.",
  'عند الاستغاثة، يرسل سينا لكل جهة رسالة تلقائية برابط خريطة للموقع — دون لمس، وحتى بدون إنترنت. كما يتصل بأول جهة.',
);
final Map<String, String> descConfirmSos = _m(
  "Évite les fausses alertes : lors d'un SOS, SINA attend 10 secondes (avec un compte à rebours parlé) un appui n'importe où avant d'envoyer. Aucun appui l'annule. Désactivez pour envoyer immédiatement.",
  'Prevents false alarms: on SOS, SINA waits 10 seconds (with a spoken countdown) for a tap anywhere on screen before sending. No tap cancels it. Turn off to send immediately.',
  'يمنع الإنذارات الكاذبة: عند الاستغاثة ينتظر سينا 10 ثوانٍ (مع عدّ تنازلي منطوق) للمس في أي مكان قبل الإرسال. عدم اللمس يلغيها. أوقفه للإرسال فوراً.',
);
final Map<String, String> descCheckIn = _m(
  "Après un SOS, SINA demande à cet intervalle s'il faut envoyer à votre famille une position mise à jour. Dites oui pour renvoyer, ou stop pour terminer.",
  'After an SOS, SINA asks at this interval whether to send your family an updated location. Say yes to resend, or stop to end.',
  'بعد الاستغاثة، يسأل سينا بهذه الفترة عمّا إذا كان سيرسل لعائلتك موقعاً محدّثاً. قل نعم لإعادة الإرسال، أو قف للإنهاء.',
);
final Map<String, String> descAbout = _m(
  'SINA v1.0\nVotre assistant de mobilité guidé par la voix\n\nPour les personnes malvoyantes\nDétection d\'obstacles en temps réel avec retour vocal\nAlertes d\'urgence à la famille',
  'SINA v1.0\nYour voice-guided mobility assistant\n\nFor visually impaired users\nReal-time obstacle detection with voice feedback\nFamily emergency alerts',
  'سينا الإصدار 1.0\nمساعد التنقل الموجّه بالصوت\n\nلضعاف البصر\nكشف العوائق في الوقت الفعلي مع تغذية صوتية\nتنبيهات الطوارئ للعائلة',
);

// Settings — misc
final Map<String, String> lblLocationCheckIn =
    _m('Vérification de position toutes les', 'Location check-in every', 'فحص الموقع كل');
final Map<String, String> lblMinutesUnit = _m('min', 'min', 'دقيقة');
final Map<String, String> lblTestCall = _m('Appel test (premier contact)',
    'Test Call (first contact)', 'مكالمة تجريبية (أول جهة)');
final Map<String, String> lblWhatsappNumber = _m('Numéro WhatsApp (secours optionnel)',
    'WhatsApp Number (optional fallback)', 'رقم واتساب (احتياطي اختياري)');
final Map<String, String> msgAddPhoneFirst = _m(
    "Veuillez d'abord ajouter un numéro de téléphone",
    'Please add a phone number first',
    'يرجى إضافة رقم هاتف أولاً');

// Family screen
final Map<String, String> lblFamilyTracking =
    _m('SINA — Suivi familial', 'SINA — Family Tracking', 'سينا — تتبع العائلة');
final Map<String, String> lblOnline = _m('En ligne', 'Online', 'متصل');
final Map<String, String> lblWaitingGps =
    _m('En attente du GPS…', 'Waiting for GPS…', 'في انتظار GPS…');
final Map<String, String> lblNoLocationYet =
    _m('Pas encore de position', 'No location yet', 'لا يوجد موقع بعد');
final Map<String, String> lblLastUpdate =
    _m('Dernière mise à jour', 'Last update', 'آخر تحديث');
final Map<String, String> lblNoAlertsYet =
    _m('Aucune alerte pour le moment.', 'No alerts yet.', 'لا توجد تنبيهات بعد.');

// Contacts editor
final Map<String, String> lblAddContact =
    _m('Ajouter un contact', 'Add contact', 'إضافة جهة اتصال');
final Map<String, String> lblContact = _m('Contact', 'Contact', 'جهة الاتصال');
final Map<String, String> lblNameOptional =
    _m('Nom (optionnel)', 'Name (optional)', 'الاسم (اختياري)');
final Map<String, String> lblPhoneNumber =
    _m('Numéro de téléphone', 'Phone number', 'رقم الهاتف');
final Map<String, String> lblNameHint = _m('Maman', 'Mom', 'أمي');

// Home screen
final Map<String, String> lblFamily = _m('Famille', 'Family', 'العائلة');
final Map<String, String> lblCamera = _m('Caméra', 'Camera', 'الكاميرا');
final Map<String, String> lblMicrophone =
    _m('Microphone SINA', 'SINA microphone', 'ميكروفون سينا');
final Map<String, String> hintOrbListening = _m('Écoute en cours. Activez pour arrêter.',
    'Listening. Activate to stop.', 'يستمع. فعّل للإيقاف.');
final Map<String, String> hintOrbSpeaking =
    _m('En train de parler.', 'Speaking.', 'يتحدث.');
final Map<String, String> hintOrbIdle = _m('Activez pour commencer à écouter.',
    'Activate to start listening.', 'فعّل لبدء الاستماع.');
final Map<String, String> lblSosButton = _m(
    "Urgence SOS. Un appui long n'importe où envoie aussi un SOS.",
    'SOS Emergency. Long-press anywhere also sends an SOS.',
    'استغاثة SOS. الضغط المطوّل في أي مكان يرسل استغاثة أيضاً.');
final Map<String, String> lblTapToConfirmSos = _m("TOUCHEZ N'IMPORTE OÙ\nPOUR CONFIRMER LE SOS",
    'TAP ANYWHERE\nTO CONFIRM SOS', 'المس في أي مكان\nلتأكيد الاستغاثة');
final Map<String, String> lblNoTapCancels = _m("Aucun appui annule l'alerte",
    'No tap cancels the alert', 'عدم اللمس يلغي التنبيه');
// {s} = remaining seconds.
final Map<String, String> lblConfirmEmergency = _m(
  "Confirmer l'urgence. Touchez n'importe où pour envoyer l'alerte. Elle s'annule dans {s} secondes si vous ne faites rien.",
  'Confirm emergency. Tap anywhere to send the alert. It cancels in {s} seconds if you do nothing.',
  'أكّد الطوارئ. المس في أي مكان لإرسال التنبيه. يُلغى خلال {s} ثوانٍ إن لم تفعل شيئاً.',
);

final Map<String, String> msgSosSmsFailed = _m(
  "Je n'ai pas pu envoyer le message. J'essaie d'appeler votre famille.",
  'I could not send the message. I am trying to call your family.',
  'تعذّر إرسال الرسالة. أحاول الاتصال بعائلتك.',
);

final Map<String, String> msgSosNoContact = _m(
  "Aucun contact d'urgence n'est configuré. Demandez à un proche de l'ajouter dans les paramètres.",
  'No emergency contact is set. Ask a relative to add one in settings.',
  'لا يوجد جهة اتصال للطوارئ. اطلب من أحد أقاربك إضافتها في الإعدادات.',
);

final Map<String, String> msgHelp = _m(
  'Dites ouvre caméra pour détecter les obstacles. Dites qu\'est-ce que tu vois pour décrire la scène. '
      'Dites lis le texte pour lire un texte écrit. '
      'Dites volume haut ou bas pour ajuster. Dites où suis-je pour connaître votre position. '
      'Dites mes contacts pour les écouter, ou ajouter un contact pour en enregistrer un. '
      'Dites danger pour alerter votre famille. Dites paramètres pour les réglages.',
  'Say open camera to detect obstacles. Say what do you see to describe the scene. '
      'Say read text to read printed text aloud. '
      'Say volume up or down to adjust. Say where am I to know your location. '
      'Say my contacts to hear them, or add a contact to save one. '
      'Say danger to alert your family. Say settings for preferences.',
  'قل افتح الكاميرا للكشف عن العوائق. قل ما الذي تراه لوصف المشهد. '
      'قل اقرأ النص لقراءة نص مكتوب. '
      'قل مستوى الصوت أعلى أو أخفض للتعديل. قل أين أنا معرفة موقعك. '
      'قل جهات الاتصال لسماعها، أو أضف جهة اتصال لحفظ واحدة. '
      'قل خطر لتنبيه عائلتك. قل إعدادات للتفضيلات.',
);

/// Spoken system status (port of _build_status_message).
String buildStatusMessage(String lang,
    {required bool cameraOn, required bool gpsOn}) {
  final parts = <String>[];
  if (lang == 'fr') {
    parts.add('Caméra ${cameraOn ? "activée" : "désactivée"}');
    parts.add('Partage de localisation ${gpsOn ? "activé" : "désactivé"}');
    parts.add('Langue: Français');
  } else if (lang == 'ar') {
    parts.add('الكاميرا ${cameraOn ? "مفعّلة" : "معطّلة"}');
    parts.add('مشاركة الموقع ${gpsOn ? "مفعّلة" : "معطّلة"}');
    parts.add('اللغة: العربية');
  } else {
    parts.add('Camera ${cameraOn ? "on" : "off"}');
    parts.add('Location sharing ${gpsOn ? "on" : "off"}');
    parts.add('Language: English');
  }
  return parts.join('. ');
}

/// Status-text labels shown under the orb for each app state.
const Map<String, Map<String, String>> stateLabels = {
  'idle': {'fr': 'Appuyez pour parler', 'en': 'Tap to speak', 'ar': 'اضغط للتحدث'},
  'listening': {'fr': "J'écoute…", 'en': 'Listening…', 'ar': 'أستمع…'},
  'responding': {'fr': 'SINA parle…', 'en': 'SINA speaking…', 'ar': 'سينا تتحدث…'},
};

/// Tap-to-start overlay prompt.
final Map<String, String> msgTapToActivate = _m(
  "Appuyez n'importe où pour activer votre assistant vocal.",
  'Tap anywhere to activate your voice assistant.',
  'انقر في أي مكان لتفعيل مساعدك الصوتي.',
);

final Map<String, String> lblTapToActivate = _m(
  "Appuyez n'importe où pour activer SINA",
  'Tap anywhere to activate SINA',
  'انقر في أي مكان لتفعيل سينا',
);
