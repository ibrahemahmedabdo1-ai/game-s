import 'package:colorreactor/game_info.dart';
import 'package:colorreactor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('splash -> menu -> level select -> settings, RTL in Arabic', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ctl = await ShellController.create(colorReactorInfo, test: true);
    await tester.pumpWidget(ColorReactorApp(ctl: ctl));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.text('Color Reactor'), findsOneWidget);

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
    final dir = Directionality.of(tester.element(find.text('الإعدادات')));
    expect(dir, TextDirection.rtl);
    expect(ctl.save.language, 'ar');
  });
}
