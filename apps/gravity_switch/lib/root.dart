import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'game_screen.dart';

Widget gravitySwitchRoot(ShellController ctl) => StandardRoot(
      ctl: ctl,
      gameBuilder: (mode, level) => GravityScreen(ctl: ctl, mode: mode, level: level),
      extraMenu: (context) => [
        IconButton(
            tooltip: ctl.t('skins'),
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => SkinsScreen(ctl: ctl, skins: gravitySkins)))),
      ],
    );
