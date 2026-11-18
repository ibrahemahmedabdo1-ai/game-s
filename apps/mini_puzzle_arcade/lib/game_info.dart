import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

const arcadeInfo = GameInfo(
  id: 'mini_puzzle_arcade',
  titleEn: 'Mini Puzzle Arcade',
  titleAr: 'ميني أركيد الألغاز',
  color: Color(0xFF5C6BC0),
  levelCount: 1,
  tutorialEn: ['Pick any of the five games. Each keeps its own progress.'],
  tutorialAr: ['اختر أي لعبة من الألعاب الخمس. كل لعبة تحتفظ بتقدمها الخاص.'],
  extraStrings: {
    'en': {'arcadeTitle': 'Pick a game', 'bestScoreIn': 'Best'},
    'ar': {'arcadeTitle': 'اختر لعبة', 'bestScoreIn': 'الأفضل'},
  },
);
