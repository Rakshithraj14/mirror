import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/tags.dart';
import '../theme.dart';

/// The tagging card — shown both as the system overlay when a payment lands
/// and as a sheet inside the app. One card, so the moment looks identical
/// wherever you meet it.
class CategoryReasonForm extends StatefulWidget {
  final String bank;
  final double amount;
  final TxnType type;
  final DateTime time;
  final String? initialCategory;
  final String? initialReason;
  final List<Category> categories;
  final void Function(String category, String reason) onSubmit;
  final VoidCallback? onCancel;

  const CategoryReasonForm({
    super.key,
    required this.bank,
    required this.amount,
    required this.type,
    required this.time,
    required this.categories,
    required this.onSubmit,
    this.initialCategory,
    this.initialReason,
    this.onCancel,
  });

  @override
  State<CategoryReasonForm> createState() => _CategoryReasonFormState();
}

class _CategoryReasonFormState extends State<CategoryReasonForm> {
  late String? _category = widget.initialCategory;
  late final TextEditingController _reason =
      TextEditingController(text: widget.initialReason ?? '');
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (_category == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Add what it was for');
      return;
    }
    widget.onSubmit(_category!, reason);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isCredit = widget.type == TxnType.credit;
    final t = widget.time;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    isCredit ? 'RECEIVED' : 'PAID',
                    style: uiText(
                      size: 11,
                      color: p.accentInk,
                      weight: FontWeight.w600,
                      spacing: 2.2,
                    ),
                  ),
                ),
                if (widget.onCancel != null)
                  GestureDetector(
                    onTap: widget.onCancel,
                    child:
                        Icon(Icons.close_rounded, size: 20, color: p.inkFaint),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${isCredit ? '+' : '−'}₹${widget.amount.toStringAsFixed(0)}',
                style: heroAmount(44, color: p.ink)),
            const SizedBox(height: 6),
            Text(
              '${widget.bank} · ${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}',
              style: uiText(size: 12, color: p.inkFaint),
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
            AccentButton(label: 'Save', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// Shared by the capture popup and the add sheet, so the two cards can never
/// drift apart.
class CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (categories.isEmpty) {
      return Text('Add a category in Profile first.',
          style: uiText(size: 12.5, color: p.inkFaint));
    }
    // Three fit the row; beyond that they scroll, so adding a fourth category
    // never squeezes the labels down to nothing.
    if (categories.length <= 3) {
      return Row(
        children: [
          for (final c in categories)
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: c == categories.last ? 0 : 8),
                child: CategoryChip(
                  category: c,
                  selected: selected == c.id,
                  onTap: () => onSelect(c.id),
                ),
              ),
            ),
        ],
      );
    }
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(
          width: 96,
          child: CategoryChip(
            category: categories[i],
            selected: selected == categories[i].id,
            onTap: () => onSelect(categories[i].id),
          ),
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.16) : p.ground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon(category.id),
                size: 15, color: selected ? p.accentInk : p.inkFaint),
            const SizedBox(height: 6),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiText(
                size: 12,
                color: selected ? p.ink : p.inkMuted,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "what was it for?" field. Shared for the same reason as the chips —
/// and because what you type here now also picks the transaction's icon.
class ReasonField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  const ReasonField({super.key, required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );

    return TextField(
      controller: controller,
      style: uiText(size: 14, color: p.ink),
      cursorColor: p.accentInk,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'What was it for?',
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
    );
  }
}

class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AccentButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style:
                uiText(size: 14, weight: FontWeight.w600, color: p.onAccent)),
      ),
    );
  }
}
