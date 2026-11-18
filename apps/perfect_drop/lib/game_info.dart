import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const perfectDropInfo = GameInfo(
  id: 'perfect_drop',
  titleEn: 'Perfect Drop',
  titleAr: 'السقوط المثالي',
  color: Color(0xFF7C4DFF),
  levelCount: 100,
  tutorialEn: [
    'Balls fall from the top. Tap a paddle to tilt it and steer the balls toward the glowing bins at the bottom.',
    'Each bin has a multiplier. You have a limited number of moves to set the paddles, so plan before you act.',
    'Press Release to drop the balls. Get every ball into a scoring bin for a Perfect bonus!',
  ],
  tutorialAr: [
    'تسقط الكرات من الأعلى. اضغط على اللوح لإمالته ووجّه الكرات نحو الحاويات المضيئة في الأسفل.',
    'لكل حاوية مضاعف. لديك عدد محدود من الحركات لضبط الألواح، فخطّط قبل أن تتحرك.',
    'اضغط إطلاق لإسقاط الكرات. أدخل كل الكرات إلى حاويات الأهداف لتحصل على مكافأة المثالي!',
  ],
);

const dropSkins = [
  SkinDef('default', 'Pearl', 'لؤلؤة', Color(0xFFE0E0E0), 0),
  SkinDef('aqua', 'Aqua', 'أكوا', Color(0xFF4DD0E1), 50),
  SkinDef('rose', 'Rose', 'وردي', Color(0xFFFF80AB), 100),
  SkinDef('lime', 'Lime', 'ليموني', Color(0xFFCCFF90), 150),
  SkinDef('gold', 'Gold', 'ذهبي', Color(0xFFFFD740), 300),
];
