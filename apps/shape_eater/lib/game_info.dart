import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const shapeEaterInfo = GameInfo(
  id: 'shape_eater',
  titleEn: 'Shape Eater',
  titleAr: 'آكل الأشكال',
  color: Color(0xFFEC407A),
  levelCount: 100,
  tutorialEn: [
    'Drag your finger to move your shape. Eat objects that have the SAME shape as you. Wrong shapes cost a life.',
    'Eating quickly builds a combo multiplier, and nearby matching shapes pop in a chain reaction.',
    'Every 5 meals your shape changes, so the rules change too. Grab power-ups: shield, slow time, magnet. Avoid moving bars!',
  ],
  tutorialAr: [
    'اسحب إصبعك لتحريك شكلك. التهم الأشكال المطابقة لشكلك فقط. الشكل الخاطئ يكلّفك روحاً.',
    'الأكل السريع يرفع مضاعف السلسلة، والأشكال المتطابقة القريبة تنفجر في تفاعل متسلسل.',
    'كل 5 وجبات يتغير شكلك فتتغير القواعد. اجمع التعزيزات: درع، إبطاء الوقت، مغناطيس. وتجنّب الأعمدة المتحركة!',
  ],
);

const seSkins = [
  SkinDef('default', 'Candy', 'حلوى', Color(0xFFEC407A), 0),
  SkinDef('ocean', 'Ocean', 'محيط', Color(0xFF29B6F6), 60),
  SkinDef('forest', 'Forest', 'غابة', Color(0xFF66BB6A), 120),
  SkinDef('neon', 'Neon', 'نيون', Color(0xFFD500F9), 200),
  SkinDef('sun', 'Sunburst', 'شروق', Color(0xFFFFB300), 350),
];

/// Three colors (circle, square, triangle) per appearance.
const sePalettes = <String, List<Color>>{
  'default': [Color(0xFFEC407A), Color(0xFF26C6DA), Color(0xFFFFCA28)],
  'ocean': [Color(0xFF29B6F6), Color(0xFF26A69A), Color(0xFF7986CB)],
  'forest': [Color(0xFF66BB6A), Color(0xFFD4E157), Color(0xFF8D6E63)],
  'neon': [Color(0xFFD500F9), Color(0xFF00E5FF), Color(0xFFC6FF00)],
  'sun': [Color(0xFFFFB300), Color(0xFFFF7043), Color(0xFFFFEE58)],
};
