import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/transaction.dart';
import '../services/analytics.dart';
import '../services/notification_capture.dart';
import '../services/sms_capture.dart';
import '../services/transactions_db.dart';
import '../theme.dart';
import '../widgets/category_reason_form.dart';
import '../widgets/spend_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late Future<List<Txn>> _future;
  bool _smsGranted = false;
  bool _capturing = false;
  bool _askedThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = TransactionsDb.instance.getAll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from a settings page is the only signal that a permission may
    // have been granted, since the overlay plugin never fires its callback.
    if (state == AppLifecycleState.resumed) _resumeCapture();
  }

  void _refresh() => setState(() => _future = TransactionsDb.instance.getAll());

  Future<void> _resumeCapture() async {
    if (!_smsGranted || _capturing) return;
    if (await FlutterOverlayWindow.isPermissionGranted().catchError((_) => false)) {
      startSmsListening();
      if (mounted) setState(() => _capturing = true);
    }
    if (await isNotificationAccessGranted()) await startNotificationListening();
  }

  /// Asks for whatever is still missing, as a dialog over the dashboard —
  /// there is no separate setup screen to walk through.
  Future<void> _ensurePermissions() async {
    if (_askedThisLaunch) return;
    _askedThisLaunch = true;

    // A plugin channel failing here must not take the dashboard down with it.
    bool overlayGranted;
    bool notificationsGranted;
    try {
      overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
      notificationsGranted = await isNotificationAccessGranted();
    } catch (_) {
      return;
    }
    if (overlayGranted && notificationsGranted && _capturing) return;
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: YumekoColors.surface,
        title: const Text('Let Yumeko watch for transactions'),
        content: const Text(
          'Yumeko needs to read bank SMS, draw a popup over other apps, and '
          '(optionally) read payment app notifications. Everything stays on '
          'this device.',
          style: TextStyle(color: YumekoColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    await _grantAll();
  }

  Future<void> _grantAll() async {
    try {
      _smsGranted = await requestSmsPermission();
      if (!_smsGranted) {
        _snack('SMS permission denied. Grant it in Settings > Apps > Yumeko.');
        return;
      }

      if (!await ensureOverlayPermission()) {
        _snack('Turn on "Appear on top" for Yumeko, then come back here.');
        return;
      }

      startSmsListening();
      if (mounted) setState(() => _capturing = true);

      if (!await isNotificationAccessGranted()) {
        await openNotificationAccessSettings();
        _snack('Optional: enable Yumeko under Notification access to catch '
            'transactions your bank sends no SMS for.');
        return;
      }
      await startNotificationListening();
    } catch (e) {
      _snack('Permission request failed: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _tag(Txn txn) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          top: 16,
        ),
        child: CategoryReasonForm(
          bank: txn.bank,
          amount: txn.amount,
          type: txn.type,
          time: txn.time,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onSubmit: (category, reason) async {
            await TransactionsDb.instance.tag(txn.id!, category, reason);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yumeko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Txn>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final txns = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SpendRow(txns: txns),
                const SizedBox(height: 20),
                const _SectionTitle('Daily spend · last 30 days'),
                const SizedBox(height: 8),
                SpendChart(daily: dailySpend(txns)),
                const SizedBox(height: 24),
                _SectionTitle('Transactions · ${txns.length}'),
                const SizedBox(height: 4),
                if (txns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nothing captured yet.',
                        style: TextStyle(color: YumekoColors.inkMuted)),
                  )
                else
                  ...txns.map((t) => _TxnTile(txn: t, onTap: () => _tag(t))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: YumekoColors.inkMuted,
          fontSize: 12,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _SpendRow extends StatelessWidget {
  final List<Txn> txns;
  const _SpendRow({required this.txns});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(label: 'Today', amount: spentToday(txns))),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(label: 'This week', amount: spentThisWeek(txns))),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(label: 'This month', amount: spentThisMonth(txns))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final double amount;

  const _StatTile({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: YumekoColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: YumekoColors.inkMuted, fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: YumekoColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Txn txn;
  final VoidCallback onTap;

  const _TxnTile({required this.txn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.type == TxnType.credit;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(txn.bank, style: const TextStyle(color: YumekoColors.ink)),
      subtitle: Text(
        txn.isTagged
            ? '${_categoryLabel(txn.category!)} · ${txn.reason}'
            : 'Tap to tag',
        style: const TextStyle(color: YumekoColors.inkMuted, fontSize: 12),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isCredit ? YumekoColors.credit : YumekoColors.debit,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  static String _categoryLabel(TxnCategory c) => switch (c) {
        TxnCategory.personal => 'Personal',
        TxnCategory.family => 'Family',
        TxnCategory.office => 'Office',
      };
}
