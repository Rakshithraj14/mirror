import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/analytics.dart';
import '../services/tags.dart';
import '../theme.dart';
import 'overview_screen.dart';

/// The full ledger: filter it, search it, and see what the period nets out to.
class TransactionsScreen extends StatefulWidget {
  final List<Txn> txns;
  final List<Category> categories;
  final DateTime now;
  final ValueChanged<Txn> onTag;
  final ValueChanged<Txn> onDelete;
  final Future<void> Function() onRefresh;

  const TransactionsScreen({
    super.key,
    required this.txns,
    required this.categories,
    required this.now,
    required this.onTag,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _category;
  Period _period = Period.month;
  bool _untaggedOnly = false;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Txn> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return inPeriod(widget.txns, _period, now: widget.now).where((t) {
      if (_untaggedOnly && t.isTagged) return false;
      if (_category != null && t.category != _category) return false;
      if (query.isEmpty) return true;
      // Searches what you'd actually remember: the reason, the bank, the tag,
      // and the amount as typed.
      return (t.reason ?? '').toLowerCase().contains(query) ||
          t.bank.toLowerCase().contains(query) ||
          tagOf(t).label.toLowerCase().contains(query) ||
          t.amount.toStringAsFixed(0).contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = _filtered;
    final income = rows
        .where((t) => t.type == TxnType.credit)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = rows
        .where((t) => t.type == TxnType.debit)
        .fold<double>(0, (s, t) => s + t.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Column(
            children: [
              ScreenHeader(
                title: 'Transactions',
                untagged: untaggedCount(widget.txns),
                onTap: () => setState(() => _untaggedOnly = !_untaggedOnly),
              ),
              const SizedBox(height: 14),
              _CategoryFilter(
                categories: widget.categories,
                value: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PeriodDropdown(
                    value: _period,
                    onChanged: (v) => setState(() => _period = v),
                  ),
                  const Spacer(),
                  _IconToggle(
                    icon: Icons.search_rounded,
                    active: _searching,
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _search.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _IconToggle(
                    icon: Icons.filter_alt_outlined,
                    active: _untaggedOnly,
                    onTap: () =>
                        setState(() => _untaggedOnly = !_untaggedOnly),
                  ),
                ],
              ),
              if (_searching) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  autofocus: true,
                  style: uiText(size: 14, color: p.ink),
                  cursorColor: p.accentInk,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search reason, bank or amount',
                    hintStyle: uiText(size: 13.5, color: p.inkFaint),
                    filled: true,
                    fillColor: p.surface,
                    isDense: true,
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 18, color: p.inkFaint),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.accent),
                    ),
                  ),
                ),
              ],
              if (_untaggedOnly) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Showing untagged only',
                        style: uiText(size: 12, color: p.inkMuted)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _untaggedOnly = false),
                      child: Text('Clear',
                          style: uiText(size: 12, color: p.accentInk)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: p.accentInk,
            backgroundColor: p.surface,
            child: rows.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    children: [
                      Text(
                        'Nothing matches that.',
                        textAlign: TextAlign.center,
                        style: uiText(size: 13, color: p.inkMuted),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                    children: groupedRows(
                      rows,
                      now: widget.now,
                      showTime: true,
                      onTag: widget.onTag,
                      onDelete: widget.onDelete,
                      color: p.inkFaint,
                    ),
                  ),
          ),
        ),
        _Totals(income: income, expense: expense),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CategoryFilter({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget chip(String label, String? category) {
      final selected = value == category;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onChanged(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? p.accent : p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? p.accent : p.line),
            ),
            child: Text(
              label,
              style: uiText(
                size: 12.5,
                color: selected ? p.onAccent : p.inkMuted,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', null),
          for (final category in categories) chip(category.label, category.id),
        ],
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  final Period value;
  final ValueChanged<Period> onChanged;

  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Period>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: p.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: p.inkFaint),
          style: uiText(size: 12.5, color: p.ink),
          onChanged: (v) => v == null ? null : onChanged(v),
          items: [
            for (final period in Period.values)
              DropdownMenuItem(
                value: period,
                child: Text(period.label,
                    style: uiText(size: 12.5, color: p.ink)),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _IconToggle({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? p.accent : p.line),
        ),
        child: Icon(icon, size: 18, color: active ? p.onAccent : p.inkMuted),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final double income;
  final double expense;

  const _Totals({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final net = income - expense;

    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label, style: uiText(size: 10.5, color: p.inkFaint)),
              const SizedBox(height: 3),
              Text(value,
                  style: uiText(
                      size: 13.5, weight: FontWeight.w600, color: color)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          cell('Income', '+₹${income.toStringAsFixed(0)}', p.accentInk),
          Container(width: 1, height: 26, color: p.line),
          cell('Expense', '−₹${expense.toStringAsFixed(0)}', p.ink),
          Container(width: 1, height: 26, color: p.line),
          cell('Net', '${net >= 0 ? '+' : '−'}₹${net.abs().toStringAsFixed(0)}',
              p.ink),
        ],
      ),
    );
  }
}
