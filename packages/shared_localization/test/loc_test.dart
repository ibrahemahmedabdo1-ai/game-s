import 'package:flutter_test/flutter_test.dart';
import 'package:shared_localization/shared_localization.dart';

void main() {
  test('every English key exists in Arabic and vice versa', () {
    final en = Loc.all['en']!.keys.toSet();
    final ar = Loc.all['ar']!.keys.toSet();
    expect(en.difference(ar), isEmpty);
    expect(ar.difference(en), isEmpty);
  });
  test('rtl and fallback', () {
    expect(Loc('ar').isRtl, true);
    expect(Loc('en').isRtl, false);
    expect(Loc('en').t('nope'), 'nope');
    expect(Loc('en').tf('hintsLeft', {'n': 2}), 'Hints: 2');
  });
  test('extra keys override and fall back', () {
    final l = Loc('ar', extra: {'en': {'x': 'X'}});
    expect(l.t('x'), 'X');
  });
}
