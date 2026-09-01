import 'package:flutter/material.dart';

import '../theme.dart';

typedef NavItem = ({IconData icon, String label});

const navItems = <NavItem>[
  (icon: Icons.show_chart_rounded, label: 'Overview'),
  (icon: Icons.receipt_long_rounded, label: 'Transactions'),
  (icon: Icons.pie_chart_rounded, label: 'Insights'),
  (icon: Icons.person_rounded, label: 'Profile'),
];

/// Four tabs with the add button breaking out of the middle.
///
/// Hand-built rather than a [NavigationBar]: the button has to overflow the
/// bar's own bounds, which a NavigationBar will not let a child do.
class YumekoNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  const YumekoNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  static const barHeight = 64.0;
  static const fabSize = 62.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: barHeight + bottomInset + fabSize / 2,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: barHeight + bottomInset,
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.line)),
            ),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Row(
              children: [
                _tab(p, 0),
                _tab(p, 1),
                const SizedBox(width: fabSize + 16),
                _tab(p, 2),
                _tab(p, 3),
              ],
            ),
          ),
          Positioned(
            bottom: bottomInset + barHeight - fabSize / 2 - 6,
            child: _AddButton(onTap: onAdd),
          ),
        ],
      ),
    );
  }

  Widget _tab(Palette p, int i) {
    final selected = i == index;
    final color = selected ? p.accentInk : p.inkFaint;
    return Expanded(
      child: InkResponse(
        onTap: () => onSelect(i),
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(navItems[i].icon, size: 21, color: color),
            const SizedBox(height: 4),
            Text(
              navItems[i].label,
              style: uiText(
                size: 10,
                color: color,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: YumekoNavBar.fabSize,
        height: YumekoNavBar.fabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: p.fabGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
          // A ring in the bar's own colour so the circle reads as sitting on
          // top of the bar rather than punched through it.
          border: Border.all(color: p.surface, width: 3),
        ),
        child: Icon(Icons.add_rounded, size: 30, color: p.onAccent),
      ),
    );
  }
}
