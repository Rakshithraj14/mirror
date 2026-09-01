import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/capture.dart';
import '../services/notification_capture.dart';
import '../services/settings.dart';
import '../services/sms_capture.dart';
import '../services/txn_store.dart';
import '../theme.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/category_reason_form.dart';
import '../widgets/nav_bar.dart';
import 'insights_screen.dart';
import 'overview_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';

/// Owns the data every tab reads, the tab bar, and the add button.
///
/// One load, shared: four screens each fetching the same rows would show four
/// slightly different totals the moment a payment landed mid-scroll.
class HomeShell extends StatefulWidget {
  final TxnStore store;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  /// Which tab to open on. Only the design preview passes this, so a single
  /// screen can be screenshotted without clicking through the app first.
  final int initialTab;

  const HomeShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.store = const TxnStore(),
    this.initialTab = 0,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late int _tab = widget.initialTab;
  List<Txn>? _txns;
  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  DateTime _now = DateTime.now();
  /// Set when Overview's "Manage accounts" is tapped, so Profile opens the
  /// accounts sheet instead of just landing on the tab.
  bool _openAccounts = false;

  bool _smsGranted = false;
  bool _capturing = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
    // have been granted — the overlay plugin never fires its callback.
    if (state == AppLifecycleState.resumed) {
      // If a tagging popup is somehow still up, it is over this app right now
      // and holding focus. Opening Yumeko is the escape hatch.
      dismissOverlay().catchError((_) {});
      _resumeCapture();
      _load();
    }
  }

  Future<void> _load() async {
    final txns = await widget.store.load();
    final accounts = await widget.store.accounts();
    final categories = await widget.store.categories();
    if (!mounted) return;
    setState(() {
      _txns = txns;
      _accounts = accounts;
      _categories = categories;
      _now = DateTime.now();
    });
  }

  /// Starts listening again when the permissions are already in place.
  ///
  /// It used to bail on `_smsGranted`, which is a fresh `false` on every cold
  /// start — so after a restart capture silently did nothing until you tapped
  /// "Turn on" again. The overlay permission is checked first, so the SMS
  /// prompt can never appear before the explainer.
  Future<void> _resumeCapture() async {
    if (_capturing) return;
    final overlay = await FlutterOverlayWindow.isPermissionGranted()
        .catchError((_) => false);
    if (!overlay) return;

    _smsGranted = await requestSmsPermission();
    if (!_smsGranted) return;
    startSmsListening();
    if (mounted) setState(() => _capturing = true);

    if (await isNotificationAccessGranted()) await startNotificationListening();
  }

  Future<void> _ensurePermissions() async {
    if (_asked) return;
    _asked = true;

    bool overlayGranted;
    bool notificationsGranted;
    try {
      overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
      notificationsGranted = await isNotificationAccessGranted();
    } catch (_) {
      return; // a plugin channel failing must not take the app down
    }
    if (overlayGranted) await _resumeCapture();

    if (!shouldAskForCapture(
      overlay: overlayGranted,
      notifications: notificationsGranted,
      askedBefore: await Settings.instance.captureAsked(),
    )) {
      return;
    }
    await Settings.instance.setCaptureAsked();
    if (!mounted) return;

    final p = Palette.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Watch for transactions',
            style: uiText(size: 17, weight: FontWeight.w600, color: p.ink)),
        content: Text(
          'Yumeko reads bank SMS and payment app alerts to catch transactions '
          'as they happen, then asks you to tag them. Nothing leaves this '
          'phone.',
          style: uiText(size: 13, color: p.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Later', style: uiText(size: 13, color: p.inkMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    await grantCapture();
  }

  /// Requests every permission capture needs, reporting what stalled.
  Future<void> grantCapture() async {
    try {
      _smsGranted = await requestSmsPermission();
      if (!_smsGranted) {
        _snack('SMS access is off. Turn it on in Settings › Apps › Yumeko.');
        return;
      }
      if (!await ensureOverlayPermission()) {
        _snack('Turn on "Appear on top" for Yumeko, then come back.');
        return;
      }
      startSmsListening();
      if (mounted) setState(() => _capturing = true);

      if (!await isNotificationAccessGranted()) {
        await openNotificationAccessSettings();
        _snack('Add Yumeko under Notification access to also catch payments '
            'your bank sends no SMS for.');
        return;
      }
      await startNotificationListening();
      _snack('Capture is on.');
    } catch (e) {
      _snack('Could not turn on capture: $e');
    }
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: uiText(size: 13)),
        action: action,
      ));
  }

  /// `viewInsets` is the keyboard, `SafeArea` is the gesture bar. Both are
  /// needed and they never apply at once — MediaQuery's padding collapses to
  /// zero while the keyboard is up.
  Widget _sheet(BuildContext ctx, Widget child) => Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: 14,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 14,
        ),
        child: SafeArea(top: false, child: child),
      );

  Future<void> _add() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(
        ctx,
        AddTransactionSheet(
          categories: _categories,
          accounts: _accounts,
          onCancel: () => Navigator.of(ctx).pop(),
          onSubmit: (txn) async {
            await widget.store.add(txn);
            if (ctx.mounted) Navigator.of(ctx).pop();
            await _load();
          },
        ),
      ),
    );
  }

  Future<void> _tag(Txn txn) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(
        ctx,
        CategoryReasonForm(
          bank: txn.bank,
          amount: txn.amount,
          type: txn.type,
          time: txn.time,
          categories: _categories,
          initialCategory: txn.category,
          initialReason: txn.reason,
          onCancel: () => Navigator.of(ctx).pop(),
          onSubmit: (category, reason) async {
            await widget.store.tag(txn.id!, category, reason);
            if (ctx.mounted) Navigator.of(ctx).pop();
            await _load();
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Txn txn) async {
    final p = Palette.of(context);
    final gone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Delete this payment?',
            style: uiText(size: 17, weight: FontWeight.w600, color: p.ink)),
        content: Text(
          '₹${txn.amount.toStringAsFixed(0)}'
          '${txn.reason == null ? '' : ' · ${txn.reason}'}',
          style: uiText(size: 13, color: p.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep', style: uiText(size: 13, color: p.inkMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (gone != true) return;

    await widget.store.delete(txn.id!);
    await _load();
    _snack(
      'Payment deleted.',
      // Re-inserted, so it returns with a new id — nothing else refers to the
      // old one.
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await widget.store.add(txn);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final txns = _txns;

    if (txns == null) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: p.inkFaint),
          ),
        ),
      );
    }

    final screens = [
      OverviewScreen(
        txns: txns,
        accounts: _accounts,
        categories: _categories,
        now: _now,
        capturing: _capturing,
        onTag: _tag,
        onDelete: _confirmDelete,
        onTurnOnCapture: grantCapture,
        onSeeAll: () => setState(() => _tab = 1),
        onManageAccounts: () => setState(() {
          _tab = 3;
          _openAccounts = true;
        }),
        onRefresh: _load,
      ),
      TransactionsScreen(
        txns: txns,
        categories: _categories,
        now: _now,
        onTag: _tag,
        onDelete: _confirmDelete,
        onRefresh: _load,
      ),
      InsightsScreen(txns: txns, now: _now),
      ProfileScreen(
        txns: txns,
        accounts: _accounts,
        categories: _categories,
        capturing: _capturing,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onTurnOnCapture: grantCapture,
        onChanged: _load,
        store: widget.store,
        autoOpenAccounts: _openAccounts,
        onAutoOpened: () => _openAccounts = false,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: screens),
      ),
      bottomNavigationBar: YumekoNavBar(
        index: _tab,
        onSelect: (i) => setState(() => _tab = i),
        onAdd: _add,
      ),
    );
  }
}
