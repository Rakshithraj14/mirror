import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'models/category.dart';
import 'models/transaction.dart';
import 'screens/home_shell.dart';
import 'services/settings.dart';
import 'services/transactions_db.dart';
import 'theme.dart';
import 'widgets/category_reason_form.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read once up front so the app never paints the wrong theme and snaps.
  final mode = await Settings.instance.themeMode().catchError(
        (_) => ThemeMode.system,
      );
  runApp(YumekoApp(initialThemeMode: mode));
}

class YumekoApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const YumekoApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<YumekoApp> createState() => _YumekoAppState();
}

class _YumekoAppState extends State<YumekoApp> {
  late ThemeMode _mode = widget.initialThemeMode;

  void _setMode(ThemeMode mode) {
    setState(() => _mode = mode);
    Settings.instance.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yumeko',
      debugShowCheckedModeBanner: false,
      theme: yumekoTheme(Brightness.light),
      darkTheme: yumekoTheme(Brightness.dark),
      themeMode: _mode,
      home: HomeShell(themeMode: _mode, onThemeChanged: _setMode),
    );
  }
}

// Looked up by exact name "overlayMain" from the plugin's native Android
// side (flutter_overlay_window) when it spins up the overlay window.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  Map<dynamic, dynamic>? _data;
  List<Category> _categories = Category.defaults;

  @override
  void initState() {
    super.initState();
    // The overlay runs in its own engine, so it reads the categories itself
    // rather than inheriting anything from the app.
    TransactionsDb.instance
        .categories()
        .then((c) {
          if (mounted && c.isNotEmpty) setState(() => _categories = c);
        })
        .catchError((_) => null);
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && mounted) setState(() => _data = event);
    });
  }

  Future<void> _handleSubmit(String category, String reason) async {
    final data = _data;
    if (data == null) return;
    await TransactionsDb.instance.tag(data['id'] as int, category, reason);
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: yumekoTheme(Brightness.light),
      darkTheme: yumekoTheme(Brightness.dark),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: data == null
                  ? const SizedBox.shrink()
                  : CategoryReasonForm(
                      categories: _categories,
                      bank: data['bank'] as String,
                      amount: (data['amount'] as num).toDouble(),
                      type: TxnType.values.byName(data['type'] as String),
                      time: DateTime.fromMillisecondsSinceEpoch(
                          data['timestampMillis'] as int),
                      onSubmit: _handleSubmit,
                      onCancel: () => FlutterOverlayWindow.closeOverlay(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
