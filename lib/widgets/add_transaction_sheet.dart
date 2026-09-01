import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
import 'category_reason_form.dart';

/// Logging what the phone never saw — cash, and payments no bank alerted on.
///
/// Deliberately shaped like [CategoryReasonForm] so adding a payment and
/// tagging a captured one feel like the same moment.
class AddTransactionSheet extends StatefulWidget {
  final List<Category> categories;
  final List<Account> accounts;
  final void Function(Txn txn) onSubmit;
  final VoidCallback onCancel;

  const AddTransactionSheet({
    super.key,
    required this.categories,
    required this.accounts,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _category;
  TxnType _type = TxnType.debit;
  DateTime _when = DateTime.now();
  String? _error;
  late String _account = widget.accounts
      .firstWhere(
        (a) => a.isCash,
        orElse: () => widget.accounts.isEmpty
            ? const Account(name: cashAccount, kind: AccountKind.cash)
            : widget.accounts.first,
      )
      .name;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final p = Palette.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final account in widget.accounts)
                ListTile(
                  dense: true,
                  leading: Icon(
                    account.isCash
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded,
                    size: 18,
                    color: p.accentInk,
                  ),
                  title: Text(account.name,
                      style: uiText(size: 14, color: p.ink)),
                  trailing: account.name == _account
                      ? Icon(Icons.check_rounded, size: 18, color: p.accentInk)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(account.name),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _account = picked);
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;
    setState(() => _when = DateTime(date.year, date.month, date.day,
        time?.hour ?? _when.hour, time?.minute ?? _when.minute));
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    final reason = _reason.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_category == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Add what it was for');
      return;
    }
    widget.onSubmit(Txn(
      bank: _account,
      amount: amount,
      type: _type,
      time: _when,
      source: TxnSource.manual,
      rawSender: 'manual',
      rawBody: '',
      category: _category,
      reason: reason,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final type in TxnType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = type),
                      child: Text(
                        type == TxnType.debit ? 'PAID' : 'RECEIVED',
                        style: uiText(
                          size: 11,
                          spacing: 2.2,
                          weight: FontWeight.w600,
                          color: _type == type ? p.accentInk : p.inkFaint,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onCancel,
                  child:
                      Icon(Icons.close_rounded, size: 20, color: p.inkFaint),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('₹', style: heroAmount(38, color: p.inkFaint)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: heroAmount(44, color: p.ink),
                    cursorColor: p.accentInk,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: heroAmount(44, color: p.inkFaint),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.accounts.length > 1)
                  Flexible(
                    child: _Picker(
                      icon: Icons.account_balance_wallet_rounded,
                      label: _account,
                      onTap: _pickAccount,
                    ),
                  )
                else
                  Flexible(
                    child: _Picker(
                      icon: Icons.account_balance_wallet_rounded,
                      label: _account,
                      onTap: null,
                    ),
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: _Picker(
                    icon: Icons.schedule_rounded,
                    label: _whenLabel(),
                    onTap: _pickWhen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            CategoryChips(
              categories: widget.categories,
              selected: _category,
              onSelect: (c) => setState(() {
                _category = c;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            ReasonField(controller: _reason, onSubmitted: (_) => _submit()),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: uiText(
                      size: 12, color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 14),
            AccentButton(label: 'Add payment', onPressed: _submit),
          ],
        ),
      ),
    );
  }

  String _whenLabel() {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(_when.year, _when.month, _when.day))
        .inDays;
    final day = switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${_when.day} ${monthNames[_when.month - 1]}',
    };
    final hour = _when.hour % 12 == 0 ? 12 : _when.hour % 12;
    return '$day, $hour:${_when.minute.toString().padLeft(2, '0')} '
        '${_when.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _Picker extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Picker({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: p.ground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: p.inkFaint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiText(size: 12, color: p.inkMuted)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 15, color: p.inkFaint),
            ],
          ],
        ),
      ),
    );
  }
}

const monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
