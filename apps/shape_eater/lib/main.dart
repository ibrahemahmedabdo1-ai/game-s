import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final ctl = await ShellController.create(shapeEaterInfo);
  runApp(ShapeEaterApp(ctl: ctl));
}

class ShapeEaterApp extends StatelessWidget {
  const ShapeEaterApp({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => StudioApp(ctl: ctl, home: shapeEaterRoot(ctl));
}
