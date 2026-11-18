import 'package:shapeeater/game_info.dart';
import 'package:shapeeater/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('splash -> menu -> levels -> settings, Arabic is RTL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ctl = await ShellController.create(shapeEaterInfo, test: true);
    await tester.pumpWidget(ShapeEaterApp(ctl: ctl));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.text(ctl.info.titleEn), findsOneWidget);
    await tester.tap(find.text('Levels'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('الإعدادات'))), TextDirection.rtl);
  });
}
