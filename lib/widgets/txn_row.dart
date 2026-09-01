import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/tags.dart';
import '../theme.dart';

/// One transaction, everywhere it appears.
///
/// The icon comes from the tag derived from your reason, so "chai" carries a
/// cup and "fuel" a pump. Direction is carried by the sign and the accent —
/// the palette is monochrome, so there is no green to lean on.
class TxnRow extends StatelessWidget {
  final Txn txn;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showTime;

  const TxnRow({
    super.key,
    required this.txn,
    required this.onTap,
    this.onLongPress,
    this.showTime = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isCredit = txn.type == TxnType.credit;
    final tag = tagOf(txn);
    final icon = isCredit ? Icons.call_received_rounded : tag.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: p.accentInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The reason leads: it is the only part of a transaction
                      // that says what the money was actually for.
                      Text(
                        txn.reason?.isNotEmpty == true
                            ? txn.reason!
                            : 'Tap to tag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiText(
                          size: 14.5,
                          weight: FontWeight.w500,
                          color: txn.isTagged ? p.ink : p.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        txn.isTagged
                            ? '${tag.label} · ${txn.bank}'
                            : txn.bank,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiText(size: 11.5, color: p.inkFaint),
                      ),
                      if (showTime) ...[
                        const SizedBox(height: 2),
                        Text(_time(txn.time),
                            style: uiText(size: 10.5, color: p.inkFaint)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${isCredit ? '+' : '−'}₹${txn.amount.toStringAsFixed(0)}',
                  style: uiText(
                    size: 15,
                    weight: FontWeight.w600,
                    color: isCredit ? p.accentInk : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} '
        '${t.hour < 12 ? 'AM' : 'PM'}';
  }
}
