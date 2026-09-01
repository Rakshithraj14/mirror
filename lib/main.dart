import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'models/transaction.dart';
import 'screens/dashboard_screen.dart';
import 'services/transactions_db.dart';
import 'theme.dart';
import 'widgets/category_reason_form.dart';

void main() {
  runApp(const YumekoApp());
}

class YumekoApp extends StatelessWidget {
  const YumekoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yumeko',
      theme: yumekoTheme,
      home: const DashboardScreen(),
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

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && mounted) setState(() => _data = event);
    });
  }

  Future<void> _handleSubmit(TxnCategory category, String reason) async {
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
      theme: yumekoTheme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: data == null
                ? const SizedBox.shrink()
                : CategoryReasonForm(
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
    );
  }
}
