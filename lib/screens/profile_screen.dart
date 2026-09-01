import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/accounts.dart';
import '../services/export_csv.dart';
import '../services/tags.dart';
import '../services/txn_store.dart';
import '../theme.dart';

/// Settings, and only the ones that do something.
///
/// The mock had an avatar, an email address and a Log out row. Yumeko has no
/// account, no login and no server — that block would have been a fabricated
/// identity, so the header states what the app actually is instead.
class ProfileScreen extends StatefulWidget {
  final List<Txn> txns;
  final List<Account> accounts;
  final List<Category> categories;
  final bool capturing;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onTurnOnCapture;
  final Future<void> Function() onChanged;
  final TxnStore store;

  /// Set when Overview's "Manage accounts" sent you here, so the accounts
  /// sheet opens rather than leaving you to find the row.
  final bool autoOpenAccounts;
  final VoidCallback onAutoOpened;

  const ProfileScreen({
    super.key,
    required this.txns,
    required this.accounts,
    required this.categories,
    required this.capturing,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onTurnOnCapture,
    required this.onChanged,
    required this.store,
    this.autoOpenAccounts = false,
    required this.onAutoOpened,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void didUpdateWidget(ProfileScreen old) {
    super.didUpdateWidget(old);
    if (widget.autoOpenAccounts && !old.autoOpenAccounts) {
      widget.onAutoOpened();
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAccounts());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final balances = accountBalances(widget.txns, widget.accounts);
    final tags = tagSpend(widget.txns);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text('Profile',
            style: uiText(size: 22, weight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: p.fabGradient),
                ),
                child: Center(
                  child: Text('Y', style: heroAmount(20, color: p.onAccent)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yumeko',
                        style: uiText(
                            size: 16, weight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 2),
                    Text('${widget.txns.length} transactions · on this phone only',
                        style: uiText(size: 12, color: p.inkFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(title: 'Money', children: [
          _Row(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Accounts',
            value: '${widget.accounts.length}',
            onTap: _openAccounts,
          ),
          _Row(
            icon: Icons.category_rounded,
            label: 'Categories',
            value: '${widget.categories.length}',
            onTap: _openCategories,
          ),
          _Row(
            icon: Icons.sell_rounded,
            label: 'Tags',
            value: '${tags.length} in use',
            onTap: () => _openTags(tags),
          ),
        ]),
        const SizedBox(height: 14),
        _Section(title: 'Preferences', children: [
          _Row(
            icon: Icons.contrast_rounded,
            label: 'Theme',
            value: switch (widget.themeMode) {
              ThemeMode.dark => 'Dark',
              ThemeMode.light => 'Light',
              ThemeMode.system => 'System',
            },
            onTap: _pickTheme,
          ),
          _Row(
            icon: Icons.notifications_active_rounded,
            label: 'Capture',
            value: widget.capturing ? 'On' : 'Off',
            onTap: widget.onTurnOnCapture,
          ),
          _Row(
            icon: Icons.currency_rupee_rounded,
            label: 'Currency',
            value: 'INR (₹)',
          ),
        ]),
        const SizedBox(height: 14),
        _Section(title: 'Data', children: [
          _Row(
            icon: Icons.ios_share_rounded,
            label: 'Export data',
            value: 'CSV · Excel',
            onTap: _pickExport,
          ),
          _Row(
            icon: Icons.info_outline_rounded,
            label: 'About Yumeko',
            onTap: _about,
          ),
        ]),
        const SizedBox(height: 10),
        if (balances.any((b) => b.clamped))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'A cash account went below zero and is being shown as ₹0. '
              'Physical cash cannot be negative, so either the opening '
              'balance is too low or some income was never recorded.',
              style: uiText(size: 11.5, color: p.inkFaint).copyWith(height: 1.5),
            ),
          ),
      ],
    );
  }

  Future<void> _pickExport() async {
    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: 'Export data',
        subtitle: 'All ${widget.txns.length} transactions, every time — '
            'Yumeko does not export a partial period.',
        children: [
          _Row(
            icon: Icons.grid_on_rounded,
            label: 'CSV',
            value: 'for Notion, Sheets',
            onTap: () => Navigator.of(ctx).pop(ExportFormat.csv),
          ),
          _Row(
            icon: Icons.table_chart_rounded,
            label: 'Excel',
            value: '.xlsx',
            onTap: () => Navigator.of(ctx).pop(ExportFormat.xlsx),
          ),
        ],
      ),
    );
    if (format == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportTransactions(widget.txns,
          format: format, categories: widget.categories);
      messenger.showSnackBar(SnackBar(
          content: Text('Exported ${widget.txns.length} transactions.',
              style: uiText(size: 13))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not export: $e', style: uiText(size: 13))));
    }
  }

  Future<void> _pickTheme() async {
    final p = Palette.of(context);
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: 'Theme',
        children: [
          for (final mode in ThemeMode.values)
            _Row(
              icon: switch (mode) {
                ThemeMode.system => Icons.phone_android_rounded,
                ThemeMode.dark => Icons.dark_mode_rounded,
                ThemeMode.light => Icons.light_mode_rounded,
              },
              label: switch (mode) {
                ThemeMode.system => 'Follow the phone',
                ThemeMode.dark => 'Dark',
                ThemeMode.light => 'Light',
              },
              trailing: widget.themeMode == mode
                  ? Icon(Icons.check_rounded, size: 18, color: p.accentInk)
                  : null,
              onTap: () => Navigator.of(ctx).pop(mode),
            ),
        ],
      ),
    );
    if (picked != null) widget.onThemeChanged(picked);
  }

  Future<void> _openTags(List<({Tag tag, double amount})> tags) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _Sheet(
        title: 'Tags in use',
        subtitle: 'Read from what you type as the reason — nothing to set up.',
        children: tags.isEmpty
            ? [
                const _Note(
                    'No tags yet. Tag a payment with a reason like "chai" and '
                    'it appears here.')
              ]
            : [
                for (final entry in tags)
                  _Row(
                    icon: entry.tag.icon,
                    label: entry.tag.label,
                    value: '₹${entry.amount.toStringAsFixed(0)}',
                  ),
              ],
      ),
    );
  }

  Future<void> _openCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CategoriesSheet(store: widget.store),
    );
    await widget.onChanged();
  }

  Future<void> _openAccounts() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AccountsSheet(store: widget.store),
    );
    await widget.onChanged();
  }

  void _about() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _Sheet(
        title: 'About Yumeko',
        children: [
          _Note(
            'Yumeko reads bank SMS and payment-app notifications on this '
            'phone, works out what each one was, and asks you to tag it.',
          ),
          _Note(
            'Everything stays in a database on this phone. Nothing is '
            'uploaded, there is no account and no server. Export is the only '
            'way data leaves — and only when you tap it.',
          ),
          _Note(
            'Balances start from an opening figure you set. When your bank '
            'prints its own balance in a message, Yumeko uses that instead.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: eyebrow(color: p.inkFaint)),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.caption,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: p.accentInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(size: 14, color: p.ink)),
                  if (caption != null)
                    Text(caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiText(size: 10.5, color: p.inkFaint)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!, style: uiText(size: 12.5, color: p.inkFaint)),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.inkFaint),
            ],
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;

  const _Sheet({
    required this.title,
    this.subtitle,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          top: 14,
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(title,
                  style:
                      uiText(size: 16, weight: FontWeight.w700, color: p.ink)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(subtitle!,
                    style: uiText(size: 12.5, color: p.inkMuted)),
              ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Text(text,
          style: uiText(size: 13, color: p.inkMuted).copyWith(height: 1.5)),
    );
  }
}

/// Add, rename and remove the categories you tag with. The three Yumeko ships
/// with are only a starting point.
class _CategoriesSheet extends StatefulWidget {
  final TxnStore store;

  const _CategoriesSheet({required this.store});

  @override
  State<_CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState extends State<_CategoriesSheet> {
  List<Category>? _categories;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final categories = await widget.store.categories();
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _edit({Category? existing}) async {
    final label = await _promptText(
      context,
      title: existing == null ? 'New category' : 'Rename category',
      hint: 'Travel',
      initial: existing?.label,
    );
    if (label == null || label.isEmpty) return;

    final list = _categories ?? const <Category>[];
    // Renaming keeps the original id, so every payment already tagged with it
    // follows the new name instead of being orphaned.
    final id = existing?.id ?? _uniqueId(label, list);
    await widget.store.saveCategory(Category(
      id: id,
      label: label,
      position: existing?.position ?? list.length,
    ));
    await _reload();
  }

  String _uniqueId(String label, List<Category> existing) {
    final base = Category.idFrom(label);
    final taken = existing.map((c) => c.id).toSet();
    if (!taken.contains(base)) return base;
    for (var i = 2;; i++) {
      if (!taken.contains('$base-$i')) return '$base-$i';
    }
  }

  Future<void> _remove(Category category) async {
    final p = Palette.of(context);
    final used = await widget.store.countWithCategory(category.id);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Delete ${category.label}?',
            style: uiText(size: 16, weight: FontWeight.w600, color: p.ink)),
        content: Text(
          used == 0
              ? 'Nothing is using it.'
              : '$used ${used == 1 ? 'payment goes' : 'payments go'} back to '
                  'needing a tag. The amounts stay; only the category and '
                  'reason are cleared.',
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
    if (confirmed != true) return;
    await widget.store.deleteCategory(category.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final categories = _categories;
    return _Sheet(
      title: 'Categories',
      subtitle: 'What you pick when tagging a payment. Add your own or drop '
          'the ones you never use.',
      action: AddRowButton(label: 'Add category', onTap: () => _edit()),
      children: categories == null
          ? [const _Note('Loading…')]
          : categories.isEmpty
              ? [const _Note('No categories. Add one to start tagging again.')]
              : [
                  for (final category in categories)
                    _Row(
                      icon: categoryIcon(category.id),
                      label: category.label,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_outlined,
                                size: 16, color: p.inkFaint),
                            onPressed: () => _edit(existing: category),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 17, color: p.inkFaint),
                            onPressed: () => _remove(category),
                          ),
                        ],
                      ),
                    ),
                ],
    );
  }
}

/// Add bank accounts and cash, set what each held to begin with, remove the
/// ones you don't want.
class _AccountsSheet extends StatefulWidget {
  final TxnStore store;

  const _AccountsSheet({required this.store});

  @override
  State<_AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<_AccountsSheet> {
  List<Account>? _accounts;
  List<Txn> _txns = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final accounts = await widget.store.accounts();
    final txns = await widget.store.load();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _txns = txns;
      });
    }
  }

  Future<void> _edit({Account? existing}) async {
    final result = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccountForm(existing: existing),
    );
    if (result == null) return;

    // A rename is a new row, so the old one goes with it. Transactions keep
    // pointing at the original name; renaming an account that has history
    // would silently detach it, which is why the form blocks that case.
    if (existing != null && existing.name != result.name) {
      await widget.store.deleteAccount(existing.name);
    }
    await widget.store.saveAccount(result);
    await _reload();
  }

  Future<void> _remove(Account account) async {
    final p = Palette.of(context);
    final used = await widget.store.countWithAccount(account.name);
    if (!mounted) return;

    if (used > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: p.surface,
          title: Text('${account.name} is in use',
              style: uiText(size: 16, weight: FontWeight.w600, color: p.ink)),
          content: Text(
            '$used ${used == 1 ? 'transaction is' : 'transactions are'} '
            'recorded against it. Removing it would leave them pointing at an '
            'account that no longer exists, and it would reappear the next '
            'time that bank sends a message.',
            style: uiText(size: 13, color: p.inkMuted),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    await widget.store.deleteAccount(account.name);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final accounts = _accounts;
    final balances =
        accounts == null ? <AccountBalance>[] : accountBalances(_txns, accounts);

    return _Sheet(
      title: 'Accounts',
      subtitle: 'Set what each held before Yumeko started watching. When a '
          'bank prints its own balance in a message, that is used instead.',
      action: AddRowButton(label: 'Add account', onTap: () => _edit()),
      children: accounts == null
          ? [const _Note('Loading…')]
          : accounts.isEmpty
              ? [const _Note('No accounts yet. Add cash or a bank to start.')]
              : [
                  for (final balance in balances)
                    _Row(
                      icon: balance.account.isCash
                          ? Icons.payments_rounded
                          : Icons.account_balance_rounded,
                      label: balance.account.name,
                      caption: balance.fromBank
                          ? 'from the bank · ₹${balance.balance.toStringAsFixed(0)}'
                          : balance.clamped
                              ? 'held at ₹0 — cash cannot go negative'
                              : 'now ₹${balance.balance.toStringAsFixed(0)}',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_outlined,
                                size: 16, color: p.inkFaint),
                            onPressed: () => _edit(existing: balance.account),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 17, color: p.inkFaint),
                            onPressed: () => _remove(balance.account),
                          ),
                        ],
                      ),
                    ),
                ],
    );
  }
}

class _AccountForm extends StatefulWidget {
  final Account? existing;

  const _AccountForm({this.existing});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _opening = TextEditingController(
      text: widget.existing == null || widget.existing!.opening == 0
          ? ''
          : widget.existing!.opening.toStringAsFixed(0));
  late AccountKind _kind = widget.existing?.kind ?? AccountKind.bank;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the account a name');
      return;
    }
    final opening = double.tryParse(_opening.text.trim().replaceAll(',', ''));
    if (_opening.text.trim().isNotEmpty && opening == null) {
      setState(() => _error = 'That balance is not a number');
      return;
    }
    // Physical cash cannot be negative, and neither can an opening figure you
    // are typing in from memory.
    if ((opening ?? 0) < 0) {
      setState(() => _error = 'A balance cannot be negative');
      return;
    }
    Navigator.of(context).pop(Account(
      name: name,
      kind: _kind,
      opening: opening ?? 0,
      position: widget.existing?.position ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );

    return _Sheet(
      title: widget.existing == null ? 'Add account' : 'Edit account',
      children: [
        Row(
          children: [
            for (final kind in AccountKind.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: kind == AccountKind.values.last ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _kind = kind),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _kind == kind
                            ? p.accent.withValues(alpha: 0.16)
                            : p.ground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kind == kind ? p.accent : p.line),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            kind == AccountKind.cash
                                ? Icons.payments_rounded
                                : Icons.account_balance_rounded,
                            size: 16,
                            color: _kind == kind ? p.accentInk : p.inkFaint,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kind == AccountKind.cash ? 'Cash' : 'Bank',
                            style: uiText(
                              size: 12,
                              color: _kind == kind ? p.ink : p.inkMuted,
                              weight: _kind == kind
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          autofocus: widget.existing == null,
          style: uiText(size: 14, color: p.ink),
          cursorColor: p.accentInk,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: _kind == AccountKind.cash ? 'Cash' : 'Canara Bank',
            hintStyle: uiText(size: 14, color: p.inkFaint),
            filled: true,
            fillColor: p.ground,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: border(p.line),
            enabledBorder: border(p.line),
            focusedBorder: border(p.accent),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _opening,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: uiText(size: 14, color: p.ink),
          cursorColor: p.accentInk,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: uiText(size: 14, color: p.inkFaint),
            hintText: 'Balance right now',
            hintStyle: uiText(size: 14, color: p.inkFaint),
            filled: true,
            fillColor: p.ground,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: border(p.line),
            enabledBorder: border(p.line),
            focusedBorder: border(p.accent),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: uiText(
                  size: 12, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save',
                style:
                    uiText(size: 14, weight: FontWeight.w600, color: p.onAccent)),
          ),
        ),
      ],
    );
  }
}

class AddRowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AddRowButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.add_rounded, size: 18, color: p.accentInk),
        label: Text(label, style: uiText(size: 13.5, color: p.accentInk)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: p.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) async {
  final p = Palette.of(context);
  final controller = TextEditingController(text: initial ?? '');
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.surface,
      title: Text(title,
          style: uiText(size: 16, weight: FontWeight.w600, color: p.ink)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: uiText(size: 15, color: p.ink),
        cursorColor: p.accentInk,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: uiText(size: 15, color: p.inkFaint),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: uiText(size: 13, color: p.inkMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
