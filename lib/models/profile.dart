/// Who the phone belongs to, as far as the app is concerned.
///
/// Typed in, not signed in. There is no account, no server and no sync, so a
/// Google or phone-number identity would be an auth stack in exchange for one
/// text label. Both fields are optional and the app reads fine without them.
class Profile {
  /// What the profile is called before you rename it — the app's own name,
  /// stored for real rather than faked at render time, so the edit field opens
  /// with something in it instead of a blank.
  static const defaultName = 'Yumeko';

  final String name;

  /// Absolute path to a file this app owns, or null to draw [initial].
  final String? avatar;

  const Profile({this.name = defaultName, this.avatar});

  String get _trimmed => name.trim();

  /// Guards the one case the editor cannot produce but a stray write could:
  /// a name saved empty would otherwise render as a blank card.
  String get display => _trimmed.isEmpty ? defaultName : _trimmed;

  /// Taken from runes rather than `[0]` so a name starting with an emoji or a
  /// Devanagari letter does not come back as half a character.
  String get initial =>
      String.fromCharCode(display.runes.first).toUpperCase();

  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
}
