import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/sms_capture.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _overlayGranted = false;
  bool _capturing = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOverlayStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOverlayStatus();
  }

  Future<void> _refreshOverlayStatus() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() => _overlayGranted = granted);
  }

  Future<void> _enableCapture() async {
    setState(() => _requesting = true);
    try {
      final granted = await requestSmsAndOverlayPermissions();
      if (granted) startSmsListening();
      if (mounted) setState(() => _capturing = granted);
      await _refreshOverlayStatus();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Permission wasn't granted. If Android didn't show a prompt, it "
              'may be permanently denied — grant it manually in Settings > '
              'Apps > Yumeko > Permissions.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yumeko')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Yumeko reads incoming bank/UPI SMS on this device to detect '
              'transactions, then pops up so you can tag each one with a '
              'category and reason. Everything stays on this device.',
            ),
            const SizedBox(height: 20),
            _StatusRow(label: 'Overlay permission', granted: _overlayGranted),
            const SizedBox(height: 4),
            _StatusRow(label: 'Capture active this session', granted: _capturing),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _requesting ? null : _enableCapture,
              child: Text(_requesting ? 'Requesting…' : 'Enable transaction capture'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionsScreen()),
              ),
              child: const Text('View transactions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool granted;

  const _StatusRow({required this.label, required this.granted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: granted ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
