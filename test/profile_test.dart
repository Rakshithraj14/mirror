import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/profile.dart';

void main() {
  test('a fresh profile is already called Yumeko', () {
    // The name is stored for real rather than faked at render time, so the
    // rename field opens with something in it instead of a blank.
    expect(const Profile().name, 'Yumeko');
    expect(const Profile().display, 'Yumeko');
    expect(const Profile().initial, 'Y');
  });

  test('a name is trimmed and its initial capitalised', () {
    expect(const Profile(name: '  rakshith  ').display, 'rakshith');
    expect(const Profile(name: '  rakshith  ').initial, 'R');
  });

  test('an empty name still renders as something', () {
    // The editor refuses to save a blank, but a stray write must not leave a
    // nameless card behind.
    expect(const Profile(name: '   ').display, 'Yumeko');
    expect(const Profile(name: '').initial, 'Y');
  });

  test('a non-Latin initial is a whole character, not half a rune', () {
    expect(const Profile(name: 'राहुल').initial, 'र');
    expect(const Profile(name: '🦊 fox').initial, '🦊');
  });

  test('hasAvatar treats an empty path as no photo', () {
    expect(const Profile().hasAvatar, isFalse);
    expect(const Profile(avatar: '').hasAvatar, isFalse);
    expect(const Profile(avatar: '/data/avatar_1.jpg').hasAvatar, isTrue);
  });
}
