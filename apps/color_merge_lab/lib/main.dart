import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final ctl = await ShellController.create(colorMergeInfo);
  runApp(ColorMergeApp(ctl: ctl));
}

class ColorMergeApp extends StatelessWidget {
  const ColorMergeApp({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => StudioApp(ctl: ctl, home: colorMergeRoot(ctl));
}
