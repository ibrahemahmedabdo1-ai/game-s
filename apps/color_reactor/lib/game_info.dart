import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const colorReactorInfo = GameInfo(
  id: 'color_reactor',
  titleEn: 'Color Reactor',
  titleAr: 'مفاعل الألوان',
  color: Color(0xFF00BFA5),
  levelCount: 100,
  tutorialEn: [
    'Colored energy enters from the left edge. Each color must reach the ring of the same color on the right edge.',
    'Tap a pipe to rotate it. Connect every source to its matching target to complete the level.',
    'Padlocked pipes cannot be rotated. Numbered pipes can only be rotated that many times. Orange-framed pipes work only while the switch is ON. Ice hazards freeze the pipe beneath them. Delivering a color to the wrong ring costs extra moves.',
  ],
  tutorialAr: [
    'تدخل الطاقة الملونة من الحافة اليسرى. يجب أن يصل كل لون إلى الحلقة التي تحمل اللون نفسه على الحافة اليمنى.',
    'اضغط على الأنبوب لتدويره. صِل كل مصدر بهدفه المطابق لإكمال المرحلة.',
    'الأنابيب المقفلة لا تُدار. الأنابيب المرقّمة تُدار بعدد المرات المكتوب فقط. الأنابيب ذات الإطار البرتقالي تعمل فقط عند تشغيل المفتاح. عوائق الجليد تجمّد الأنبوب تحتها. إيصال لون إلى حلقة خاطئة يكلّفك حركات إضافية.',
  ],
  extraStrings: {
    'en': {'movesLeft': 'Moves left', 'extraMoves': '+5 moves', 'tileHint': 'Try rotating the highlighted pipe.', 'wrongRoute': 'Wrong target! +1 move penalty', 'legend': 'Number = rotations left | Switch opens orange pipes | Ice freezes a pipe'},
    'ar': {'movesLeft': 'الحركات المتبقية', 'extraMoves': '+٥ حركات', 'tileHint': 'جرّب تدوير الأنبوب المميّز.', 'wrongRoute': 'هدف خاطئ! عقوبة حركة إضافية', 'legend': 'الرقم = مرات التدوير المتبقية | المفتاح يفتح الأنابيب البرتقالية | الجليد يجمّد أنبوباً'},
  },
);

const reactorColors = [Color(0xFFFF5252), Color(0xFF40C4FF), Color(0xFFFFD740), Color(0xFFB388FF)];
