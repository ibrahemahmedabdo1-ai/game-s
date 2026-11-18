import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_screen.dart';
import 'logic/merge.dart';

Widget colorMergeRoot(ShellController ctl) => StandardRoot(
      ctl: ctl,
      gameBuilder: (mode, level) => mode == PlayMode.endless
          ? LayoutPicker(ctl: ctl)
          : MergeScreen(ctl: ctl, mode: mode, level: level, layoutIndex: mode == PlayMode.daily ? dailySeed(DateTime.now()) % layouts.length : level % layouts.length),
    );

class LayoutPicker extends StatelessWidget {
  const LayoutPicker({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(ctl.t('chooseLayout'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (var i = 0; i < layouts.length; i++)
            Card(
              color: Colors.white10,
              child: ListTile(
                leading: const Icon(Icons.grid_on_rounded),
                title: Text(ctl.t('layout$i')),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => MergeScreen(ctl: ctl, mode: PlayMode.endless, layoutIndex: i))),
              ),
            ),
        ]),
      );
}
