/// A spending category you pick when tagging.
///
/// These used to be a fixed enum. They are rows now so you can add and remove
/// them — the three defaults are only a starting point, not the schema.
class Category {
  /// Stable key stored on every transaction. Never changes, so renaming a
  /// category cannot orphan the payments already tagged with it.
  final String id;
  final String label;
  final int position;

  const Category({
    required this.id,
    required this.label,
    required this.position,
  });

  /// Seeded on a fresh install and on the upgrade from the old enum, whose
  /// values were stored as exactly these ids.
  static const defaults = [
    Category(id: 'personal', label: 'Personal', position: 0),
    Category(id: 'family', label: 'Family', position: 1),
    Category(id: 'office', label: 'Office', position: 2),
  ];

  Map<String, Object?> toMap() =>
      {'id': id, 'label': label, 'position': position};

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as String,
        label: map['label'] as String,
        position: map['position'] as int,
      );

  /// A key from a label the user typed, kept url-ish so it stays readable in
  /// the CSV export and in the database.
  static String idFrom(String label) {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'category' : slug;
  }
}

/// Reads a label for a category id, falling back to the id itself so a
/// deleted category still shows something recognisable rather than blank.
String categoryLabel(String? id, List<Category> categories) {
  if (id == null) return 'Untagged';
  for (final c in categories) {
    if (c.id == id) return c.label;
  }
  return id[0].toUpperCase() + id.substring(1).replaceAll('-', ' ');
}
