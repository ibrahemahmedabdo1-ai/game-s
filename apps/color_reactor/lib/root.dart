import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_screen.dart';

Widget colorReactorRoot(ShellController ctl) => StandardRoot(
      ctl: ctl,
      gameBuilder: (mode, level) => GameScreen(ctl: ctl, mode: mode, level: level),
    );
