import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const gravitySwitchInfo = GameInfo(
  id: 'gravity_switch',
  titleEn: 'Gravity Switch',
  titleAr: 'قلب الجاذبية',
  color: Color(0xFFFF7043),
  levelCount: 100,
  tutorialEn: [
    'Your ball rushes through a corridor. Tap anywhere to flip gravity and swap between floor and ceiling.',
    'Pillars block one side of the corridor. Be on the opposite side when you reach them, and leave time to cross.',
    'Collect stars for bonus points. Flags are checkpoints. Purple spinning bars sweep the middle, so do not flip while crossing them. A golden gate needs its key first: grab the key, then pass the gate.',
  ],
  tutorialAr: [
    'تندفع الكرة عبر ممر. اضغط في أي مكان لقلب الجاذبية والانتقال بين الأرض والسقف.',
    'تسدّ الأعمدة أحد جانبي الممر. كن في الجهة المعاكسة عند الوصول إليها، واترك وقتاً للعبور.',
    'اجمع النجوم لنقاط إضافية. الأعلام نقاط حفظ. الأذرع البنفسجية الدوّارة تكتسح منتصف الممر فلا تقلب الجاذبية أثناء عبورها. البوابة الذهبية تحتاج مفتاحها أولاً: التقط المفتاح ثم اعبر البوابة.',
  ],
);

const gravitySkins = [
  SkinDef('default', 'Cyan Core', 'القلب السماوي', Color(0xFF26C6DA), 0),
  SkinDef('sunset', 'Sunset', 'الغروب', Color(0xFFFF7043), 50),
  SkinDef('lime', 'Lime Pulse', 'نبض الليمون', Color(0xFFC6FF00), 100),
  SkinDef('violet', 'Violet Storm', 'عاصفة بنفسجية', Color(0xFFB388FF), 150),
  SkinDef('gold', 'Golden Orb', 'الكرة الذهبية', Color(0xFFFFD740), 300),
  SkinDef('ember', 'Ember Red', 'جمر أحمر', Color(0xFFFF1744), 500),
];
