import 'package:flutter/material.dart';

import 'transactions_db.dart';

/// Small key/value settings, stored in the database's `meta` table.
///
/// That table has been sitting unused since schema v3; a preferences plugin
/// would mean shipping a second store for a handful of strings.
class Settings {
  Settings._();
  static final Settings instance = Settings._();

  static const _themeKey = 'theme';

  Future<ThemeMode> themeMode() async {
    final raw = await TransactionsDb.instance.meta(_themeKey);
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      TransactionsDb.instance.setMeta(_themeKey, mode.name);
}
