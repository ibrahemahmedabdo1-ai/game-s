import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final ctl = await ShellController.create(perfectDropInfo);
  runApp(PerfectDropApp(ctl: ctl));
}

class PerfectDropApp extends StatelessWidget {
  const PerfectDropApp({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => StudioApp(ctl: ctl, home: perfectDropRoot(ctl));
}
