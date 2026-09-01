import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/accounts.dart';
import '../services/analytics.dart';
import '../theme.dart';
import '../widgets/count_up.dart';
import '../widgets/txn_row.dart';

/// The landing screen: what you've spent, what you hold, what just happened.
class OverviewScreen extends StatefulWidget {
  final List<Txn> txns;
  final List<Account> accounts;
  final List<Category> categories;
  final DateTime now;
  final bool capturing;
  final ValueChanged<Txn> onTag;
  final ValueChanged<Txn> onDelete;
  final VoidCallback onTurnOnCapture;
  final VoidCallback onSeeAll;
  final VoidCallback onManageAccounts;
  final Future<void> Function() onRefresh;

  const OverviewScreen({
    super.key,
    required this.txns,
    required this.accounts,
    required this.categories,
    required this.now,
    required this.capturing,
    required this.onTag,
    required this.onDelete,
    required this.onTurnOnCapture,
    required this.onSeeAll,
    required this.onManageAccounts,
    required this.onRefresh,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Period _period = Period.month;
  bool _hideBalances = false;

  static const _recentLimit = 6;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final txns = widget.txns;
    final spent = spentIn(txns, _period, now: widget.now);
    final change = changeVsPrevious(txns, _period, now: widget.now);
    final untagged = untaggedCount(txns);
    final accounts = accountBalances(txns, widget.accounts);
    final recent = txns.take(_recentLimit).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: p.accentInk,
      backgroundColor: p.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          ScreenHeader(title: 'YUMEKO', untagged: untagged, onTap: widget.onSeeAll),
          const SizedBox(height: 16),
          PeriodSwitch(
            value: _period,
            onChanged: (v) => setState(() => _period = v),
          ),
          const SizedBox(height: 14),
          _SpendCard(spent: spent, period: _period, change: change),
          const SizedBox(height: 12),
          _BalancesCard(
            accounts: accounts,
            hidden: _hideBalances,
            onToggleHidden: () =>
                setState(() => _hideBalances = !_hideBalances),
            onManage: widget.onManageAccounts,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('All transactions · ${txns.length}',
                  style: uiText(
                      size: 13, color: p.inkMuted, weight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onSeeAll,
                child: Text('See all',
                    style: uiText(size: 12, color: p.accentInk)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            _Empty(
                capturing: widget.capturing, onTurnOn: widget.onTurnOnCapture)
          else
            ...groupedRows(
              recent,
              now: widget.now,
              onTag: widget.onTag,
              onDelete: widget.onDelete,
              color: p.inkFaint,
            ),
        ],
      ),
    );
  }
}

/// Day-grouped transaction rows, shared by Overview and Transactions.
List<Widget> groupedRows(
  List<Txn> txns, {
  required DateTime now,
  required ValueChanged<Txn> onTag,
  required ValueChanged<Txn> onDelete,
  required Color color,
  bool showTime = false,
}) {
  final widgets = <Widget>[];
  groupByDay(txns).forEach((day, rows) {
    widgets
      ..add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(dayLabel(day, now), style: eyebrow(color: color)),
      ))
      ..addAll(rows.map((t) => TxnRow(
            txn: t,
            showTime: showTime,
            onTap: () => onTag(t),
            onLongPress: () => onDelete(t),
          )));
  });
  return widgets;
}

String dayLabel(DateTime day, DateTime now) {
  final diff = startOfDay(now).difference(day).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${day.day} ${months[day.month - 1]}';
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final int untagged;
  final VoidCallback onTap;

  const ScreenHeader({
    super.key,
    required this.title,
    required this.untagged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isWordmark = title == title.toUpperCase();
    return Row(
      children: [
        Text(
          title,
          style: isWordmark
              ? uiText(
                  size: 15, weight: FontWeight.w700, spacing: 3.4, color: p.ink)
              : uiText(size: 22, weight: FontWeight.w700, color: p.ink),
        ),
        const Spacer(),
        if (untagged > 0)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: p.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text('$untagged to tag',
                      style: uiText(size: 12, color: p.inkMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PeriodSwitch extends StatelessWidget {
  final Period value;
  final ValueChanged<Period> onChanged;

  const PeriodSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Hugs its content rather than stretching: three short words spread
    // across the whole width read as three separate buttons, not one control.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final period in Period.values)
              GestureDetector(
                onTap: () => onChanged(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                      vertical: 7, horizontal: 18),
                  decoration: BoxDecoration(
                    color: period == value ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Text(
                    period.label,
                    style: uiText(
                      size: 12.5,
                      color: period == value ? p.onAccent : p.inkMuted,
                      weight:
                          period == value ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpendCard extends StatelessWidget {
  final double spent;
  final Period period;
  final double? change;

  const _SpendCard({required this.spent, required this.period, this.change});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 168,
      // Clipped: the art is sized to bleed past the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line),
      ),
      // Two columns rather than a stack. The art cannot land on a sentence if
      // it never shares space with one.
      child: Row(
        children: [
          Expanded(
            flex: 64,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 4, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Total spent',
                      style: uiText(size: 13, color: p.inkMuted)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUp(
                      value: spent,
                      style: heroAmount(40, color: p.ink),
                      fractionStyle: heroAmount(40, color: p.inkFaint),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(period.caption.replaceFirst('spent ', ''),
                      style: uiText(size: 12.5, color: p.inkMuted)),
                  const SizedBox(height: 10),
                  if (change != null)
                    Row(
                      children: [
                        Icon(
                          change! >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 13,
                          color: p.accentInk,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${(change!.abs() * 100).round()}% vs last '
                            '${period.label.toLowerCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: uiText(size: 11.5, color: p.inkMuted),
                          ),
                        ),
                      ],
                    )
                  else
                    // Nothing in the matching span last period, so a
                    // percentage would be dividing by zero and calling it
                    // insight.
                    Text('no comparison yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiText(size: 11.5, color: p.inkFaint)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: OverflowBox(
                maxWidth: 176,
                alignment: Alignment.centerRight,
                child: _FadedArt(p.blobAsset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancesCard extends StatelessWidget {
  final List<AccountBalance> accounts;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onManage;

  const _BalancesCard({
    required this.accounts,
    required this.hidden,
    required this.onToggleHidden,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final total = totalBalance(accounts);
    final shown = accounts.take(3).toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 118,
            child: Row(
              children: [
                Expanded(
                  flex: 62,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text('Your balances',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      uiText(size: 13, color: p.inkMuted)),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: onToggleHidden,
                              child: Icon(
                                hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 15,
                                color: p.inkFaint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(hidden ? '₹••••' : '₹${_money(total)}',
                              style: heroAmount(28, color: p.ink)),
                        ),
                        const SizedBox(height: 5),
                        Text('Across ${accounts.length} accounts',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: uiText(size: 11.5, color: p.inkFaint)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 38,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OverflowBox(
                      maxWidth: 168,
                      alignment: Alignment.centerRight,
                      child: _FadedArt(p.walletAsset),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final account in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      account.account.isCash
                          ? Icons.payments_rounded
                          : Icons.account_balance_rounded,
                      size: 15,
                      color: p.accentInk,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: uiText(size: 13.5, color: p.ink)),
                        // Where the number came from matters: one figure is
                        // the bank's own, the other is our arithmetic on top
                        // of an opening balance you typed.
                        if (account.clamped)
                          Text('held at zero — check the opening balance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: uiText(size: 10.5, color: p.inkFaint))
                        else if (!account.fromBank &&
                            account.account.opening == 0)
                          Text('set an opening balance',
                              style: uiText(size: 10.5, color: p.inkFaint)),
                      ],
                    ),
                  ),
                  Text(
                    hidden ? '₹••••' : '₹${_money(account.balance)}',
                    style: uiText(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: account.balance < 0 ? p.inkMuted : p.ink),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: onManage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.line)),
              ),
              child: Row(
                children: [
                  Text('Manage accounts',
                      style: uiText(size: 12.5, color: p.inkMuted)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: p.inkFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The art assets carry their own dark glow, which reads as a rectangle
/// pasted on the card. Fading the inner edge lets them sit *in* the card.
class _FadedArt extends StatelessWidget {
  final String asset;

  const _FadedArt(this.asset);

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          stops: [0.0, 0.38],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: Image.asset(asset,
            fit: BoxFit.contain, excludeFromSemantics: true),
      );
}

/// Indian digit grouping — 1,23,456 rather than 123,456.
String _money(double v) {
  final negative = v < 0;
  final whole = v.abs().round().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final head = whole.substring(0, whole.length - 3);
    final tail = whole.substring(whole.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buffer.write(',');
      buffer.write(head[i]);
    }
    grouped = '$buffer,$tail';
  }
  return negative ? '-$grouped' : grouped;
}

class _Empty extends StatelessWidget {
  final bool capturing;
  final VoidCallback onTurnOn;

  const _Empty({required this.capturing, required this.onTurnOn});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Text(
            capturing
                ? 'Watching. Your next payment lands here.'
                : 'Turn on capture and your payments land here.',
            textAlign: TextAlign.center,
            style: uiText(size: 13, color: p.inkMuted),
          ),
          if (!capturing) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onTurnOn, child: const Text('Turn on')),
          ],
        ],
      ),
    );
  }
}
