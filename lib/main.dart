import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'models/category.dart';
import 'models/transaction.dart';
import 'screens/home_shell.dart';
import 'services/capture.dart';
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
  Txn? _txn;
  List<Category> _categories = Category.defaults;

  /// An overlay nobody answers is an overlay sitting on top of every other
  /// app. The payment is already saved, so letting it go costs only the tag.
  static const _idleTimeout = Duration(seconds: 60);
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    _idle = Timer(_idleTimeout, dismissOverlay);
    _loadPending();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  /// The overlay runs in its own engine, so it reads everything it needs from
  /// the database rather than waiting to be handed a payload.
  Future<void> _loadPending() async {
    try {
      final pending = await TransactionsDb.instance.meta(pendingKey);
      final txn = pending == null
          ? null
          : await TransactionsDb.instance.byId(int.parse(pending));
      // Nothing to tag means an empty card with no way to dismiss it. Go away
      // instead of sitting there invisible.
      if (txn == null) return dismissOverlay();

      final categories = await TransactionsDb.instance.categories();
      if (!mounted) return;
      setState(() {
        _txn = txn;
        if (categories.isNotEmpty) _categories = categories;
      });
    } catch (_) {
      await dismissOverlay();
    }
  }

  /// The window is created non-focusable so it can never hold the system
  /// keyboard hostage. Typing needs focus, so it is granted on the tap that
  /// asks for it and given back when the overlay closes.
  Future<void> _takeFocus() async {
    _idle?.cancel();
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
  }

  Future<void> _handleSubmit(String category, String reason) async {
    final txn = _txn;
    if (txn?.id == null) return;
    await TransactionsDb.instance.tag(txn!.id!, category, reason);
    await dismissOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final txn = _txn;
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
              child: txn == null
                  ? const SizedBox.shrink()
                  : CategoryReasonForm(
                      categories: _categories,
                      bank: txn.bank,
                      amount: txn.amount,
                      type: txn.type,
                      time: txn.time,
                      onReasonTap: _takeFocus,
                      onSubmit: _handleSubmit,
                      onCancel: dismissOverlay,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
