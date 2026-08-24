import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/transactions_db.dart';
import '../widgets/category_reason_form.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<Txn>> _future;

  @override
  void initState() {
    super.initState();
    _future = TransactionsDb.instance.getAll();
  }

  void _refresh() => setState(() => _future = TransactionsDb.instance.getAll());

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
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Txn>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final txns = snapshot.data!;
            if (txns.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(child: Text('No transactions captured yet.')),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: txns.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final txn = txns[index];
                final isCredit = txn.type == TxnType.credit;
                return ListTile(
                  title: Text(txn.bank),
                  subtitle: Text(
                    txn.isTagged
                        ? '${_categoryLabel(txn.category!)} • ${txn.reason}'
                        : 'Tap to tag',
                  ),
                  trailing: Text(
                    '${isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isCredit ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _tag(txn),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _categoryLabel(TxnCategory c) => switch (c) {
        TxnCategory.personal => 'Personal',
        TxnCategory.family => 'Family',
        TxnCategory.office => 'Office',
      };
}
