import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const colorMergeInfo = GameInfo(
  id: 'color_merge_lab',
  titleEn: 'Color Merge Lab',
  titleAr: 'مختبر دمج الألوان',
  color: Color(0xFF9CCC65),
  levelCount: 100,
  tutorialEn: [
    'Tap an empty cell to place the next piece. Three or more touching pieces of the same level merge into one higher level.',
    'Merges can chain! Bonus cells double your score. Gray blocks cannot be used. The wild piece joins any group, the bomb clears its neighbors.',
    'Reach the target piece to clear a stage. If the board fills up the game ends. You can undo a few moves.',
  ],
  tutorialAr: [
    'اضغط على خلية فارغة لوضع القطعة التالية. ثلاث قطع متلامسة أو أكثر من المستوى نفسه تندمج في قطعة أعلى مستوى.',
    'قد تتسلسل الدمجات! الخلايا المميزة تضاعف نقاطك. الكتل الرمادية لا يمكن استخدامها. القطعة الجوكر تنضم لأي مجموعة، والقنبلة تمسح جيرانها.',
    'صِل إلى القطعة المطلوبة لإنهاء المرحلة. إذا امتلأت اللوحة تنتهي اللعبة. يمكنك التراجع عن بعض الحركات.',
  ],
  extraStrings: {
    'en': {'layout0': 'Classic 5x5', 'layout1': 'Four pillars', 'layout2': 'Big 6x6', 'layout3': 'Crossroads', 'goal': 'Goal', 'chooseLayout': 'Choose a board'},
    'ar': {'layout0': 'كلاسيكي 5x5', 'layout1': 'أربعة أعمدة', 'layout2': 'كبير 6x6', 'layout3': 'مفترق طرق', 'goal': 'الهدف', 'chooseLayout': 'اختر اللوحة'},
  },
);

const mergeColors = [
  Color(0xFF26C6DA), Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFFFFEE58), Color(0xFFFFA726), Color(0xFFEF5350),
  Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFFD4E157), Color(0xFFFFD54F),
];
