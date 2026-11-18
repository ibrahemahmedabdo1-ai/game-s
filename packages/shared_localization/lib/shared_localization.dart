/// Minimal map-based localization. Games add their own keys via `extra`.
class Loc {
  Loc(this.lang, {Map<String, Map<String, String>> extra = const {}}) : _extra = extra;
  final String lang;
  final Map<String, Map<String, String>> _extra;

  static const supported = ['en', 'ar'];
  bool get isRtl => lang == 'ar';

  String t(String key) =>
      _extra[lang]?[key] ?? _strings[lang]?[key] ?? _extra['en']?[key] ?? _strings['en']![key] ?? key;

  String tf(String key, Map<String, Object> args) {
    var s = t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  static Map<String, Map<String, String>> get all => _strings;
}

const Map<String, Map<String, String>> _strings = {
  'en': {
    'play': 'Play', 'continue': 'Continue', 'settings': 'Settings', 'sound': 'Sound',
    'music': 'Music', 'haptics': 'Vibration', 'language': 'Language', 'levels': 'Levels',
    'pause': 'Paused', 'resume': 'Resume', 'restart': 'Restart', 'quit': 'Quit to menu',
    'gameOver': 'Game over', 'levelComplete': 'Level complete!', 'score': 'Score',
    'best': 'Best', 'moves': 'Moves', 'level': 'Level', 'dailyReward': 'Daily reward',
    'claim': 'Claim', 'claimed': 'Come back tomorrow', 'coins': 'Coins',
    'achievements': 'Achievements', 'tutorial': 'How to play', 'next': 'Next',
    'done': 'Got it', 'privacy': 'Privacy policy', 'privacyOptions': 'Ad privacy options',
    'hint': 'Hint', 'watchAd': 'Watch a short video', 'watchForHint': 'Watch a video for a free hint?',
    'watchForContinue': 'Watch a video to continue?', 'rewardFailed': 'Video not available right now.',
    'endless': 'Endless', 'daily': 'Daily challenge', 'stars': 'Stars', 'english': 'English',
    'arabic': 'العربية', 'close': 'Close', 'cancel': 'Cancel', 'locked': 'Locked',
    'adsNote': 'This game shows ads. Rewarded videos are always optional.',
    'privacyBody': 'This game works offline and stores progress only on your device. It uses Google AdMob to show ads, which may collect device identifiers according to your consent choices. See the full policy at the link provided on the store listing.',
    'ach_first_win': 'First win', 'ach_ten_levels': 'Ten levels cleared', 'ach_fifty_levels': 'Fifty levels cleared',
    'ach_three_stars_10': 'Ten perfect levels', 'ach_daily_streak_3': 'Three-day streak', 'ach_coins_500': 'Collector: 500 coins',
    'unlocked': 'Unlocked', 'hintsLeft': 'Hints: {n}', 'skins': 'Skins', 'select': 'Select', 'lives': 'Lives', 'stage': 'Stage', 'combo': 'Combo', 'undo': 'Undo', 'release': 'Release', 'perfect': 'Perfect!', 'tapToFlip': 'Tap to flip gravity', 'missions': 'Daily missions', 'm_round': 'Play {n} rounds', 'm_win': 'Complete {n} levels', 'm_stars': 'Earn {n} stars', 'done2': 'Done',
  },
  'ar': {
    'play': 'العب', 'continue': 'متابعة', 'settings': 'الإعدادات', 'sound': 'المؤثرات الصوتية',
    'music': 'الموسيقى', 'haptics': 'الاهتزاز', 'language': 'اللغة', 'levels': 'المراحل',
    'pause': 'إيقاف مؤقت', 'resume': 'استئناف', 'restart': 'إعادة', 'quit': 'الخروج للقائمة',
    'gameOver': 'انتهت اللعبة', 'levelComplete': 'أحسنت! اكتملت المرحلة', 'score': 'النتيجة',
    'best': 'الأفضل', 'moves': 'الحركات', 'level': 'المرحلة', 'dailyReward': 'المكافأة اليومية',
    'claim': 'استلام', 'claimed': 'عد غداً', 'coins': 'العملات',
    'achievements': 'الإنجازات', 'tutorial': 'طريقة اللعب', 'next': 'التالي',
    'done': 'فهمت', 'privacy': 'سياسة الخصوصية', 'privacyOptions': 'خيارات خصوصية الإعلانات',
    'hint': 'تلميح', 'watchAd': 'شاهد فيديو قصير', 'watchForHint': 'شاهد فيديو للحصول على تلميح مجاني؟',
    'watchForContinue': 'شاهد فيديو للمتابعة؟', 'rewardFailed': 'الفيديو غير متاح حالياً.',
    'endless': 'اللانهائي', 'daily': 'تحدي اليوم', 'stars': 'النجوم', 'english': 'English',
    'arabic': 'العربية', 'close': 'إغلاق', 'cancel': 'إلغاء', 'locked': 'مقفل',
    'adsNote': 'تعرض هذه اللعبة إعلانات. الفيديوهات المكافِئة اختيارية دائماً.',
    'privacyBody': 'تعمل هذه اللعبة دون اتصال وتحفظ تقدمك على جهازك فقط. تستخدم إعلانات Google AdMob التي قد تجمع معرّفات الجهاز وفق اختياراتك للموافقة. راجع السياسة الكاملة عبر الرابط في صفحة المتجر.',
    'ach_first_win': 'الفوز الأول', 'ach_ten_levels': 'عشر مراحل مكتملة', 'ach_fifty_levels': 'خمسون مرحلة مكتملة',
    'ach_three_stars_10': 'عشر مراحل بثلاث نجوم', 'ach_daily_streak_3': 'ثلاثة أيام متتالية', 'ach_coins_500': 'جامع العملات: 500',
    'unlocked': 'تم الفتح', 'hintsLeft': 'التلميحات: {n}', 'skins': 'المظاهر', 'select': 'اختيار', 'lives': 'الأرواح', 'stage': 'المرحلة', 'combo': 'سلسلة', 'undo': 'تراجع', 'release': 'إطلاق', 'perfect': 'مثالي!', 'tapToFlip': 'اضغط لقلب الجاذبية', 'missions': 'المهام اليومية', 'm_round': 'العب {n} جولات', 'm_win': 'أكمل {n} مراحل', 'm_stars': 'اجمع {n} نجوم', 'done2': 'تم',
  },
};
