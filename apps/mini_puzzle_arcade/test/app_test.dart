import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minipuzzlearcade/game_info.dart';
import 'package:minipuzzlearcade/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('hub lists all five games and opens settings in Arabic RTL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ctl = await ShellController.create(arcadeInfo, test: true);
    await tester.pumpWidget(ArcadeApp(ctl: ctl));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    for (final n in ['Color Reactor', 'Gravity Switch', 'Shape Eater', 'Perfect Drop', 'Color Merge Lab']) {
      expect(find.text(n), findsOneWidget);
    }
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('الإعدادات'))), TextDirection.rtl);
  });
}
