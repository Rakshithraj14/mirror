import 'package:flutter/material.dart';

import '../models/transaction.dart';

class CategoryReasonForm extends StatefulWidget {
  final String bank;
  final double amount;
  final TxnType type;
  final DateTime time;
  final void Function(TxnCategory category, String reason) onSubmit;
  final VoidCallback? onCancel;

  const CategoryReasonForm({
    super.key,
    required this.bank,
    required this.amount,
    required this.type,
    required this.time,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<CategoryReasonForm> createState() => _CategoryReasonFormState();
}

class _CategoryReasonFormState extends State<CategoryReasonForm> {
  TxnCategory? _category;
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_category == null || _reasonController.text.trim().isEmpty) {
      setState(() => _error = 'Pick a category and add a reason');
      return;
    }
    widget.onSubmit(_category!, _reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = widget.type == TxnType.credit;
    final time = widget.time;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black45)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.bank,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(
              '${isCredit ? '+' : '-'}₹${widget.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isCredit ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} '
              'on ${time.day}/${time.month}/${time.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: TxnCategory.values.map((c) {
                return ChoiceChip(
                  label: Text(_label(c)),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('Submit')),
            ),
          ],
        ),
      ),
    );
  }

  String _label(TxnCategory c) => switch (c) {
        TxnCategory.personal => 'Personal',
        TxnCategory.family => 'Family',
        TxnCategory.office => 'Office',
      };
}
