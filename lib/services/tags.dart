import 'package:flutter/material.dart';

import '../models/transaction.dart';

/// What a payment was *for*, derived from the reason you typed.
///
/// Categories (Personal/Family/Office) are who the money was for and stay
/// something you pick. A tag is what it bought, and typing "chai" already
/// said that — so it is read rather than asked for again.
typedef Tag = ({String id, String label, IconData icon});

const _fallback = (id: 'other', label: 'Other', icon: Icons.receipt_long_rounded);

/// Ordered: the first entry whose keyword appears in the reason wins, so more
/// specific words are listed before the generic ones they contain.
const _rules = <({String id, String label, IconData icon, List<String> words})>[
  (
    id: 'cafe',
    label: 'Cafe',
    icon: Icons.local_cafe_rounded,
    words: ['chai', 'tea', 'coffee', 'cafe', 'juice', 'shake', 'ice cream',
        'icecream', 'coke', 'pepsi', 'soda', 'cold drink', 'lassi']
  ),
  (
    id: 'dining',
    label: 'Dining',
    icon: Icons.restaurant_rounded,
    words: ['lunch', 'dinner', 'breakfast', 'food', 'restaurant', 'hotel',
        'snack', 'pizza', 'biryani', 'meal', 'swiggy', 'zomato']
  ),
  (
    id: 'groceries',
    label: 'Groceries',
    icon: Icons.shopping_cart_rounded,
    words: ['grocery', 'groceries', 'vegetable', 'veggies', 'milk', 'flower', 'fruits',
        'provision', 'kirana', 'supermarket', 'bigbasket', 'blinkit', 'fish',
        'chicken', 'mutton', 'meat', 'egg', 'rice', 'oil', 'atta', 'dal']
  ),
  (
    id: 'fuel',
    label: 'Fuel',
    icon: Icons.local_gas_station_rounded,
    words: ['fuel', 'petrol', 'diesel', 'gas station']
  ),
  (
    id: 'entertainment',
    label: 'Entertainment',
    icon: Icons.movie_rounded,
    words: ['movie', 'cinema', 'pvr', 'inox', 'bookmyshow', 'theatre',
        'theater', 'concert', 'show', 'park']
  ),
  (
    id: 'transport',
    label: 'Transport',
    icon: Icons.directions_car_rounded,
    words: ['travel', 'auto', 'cab', 'taxi', 'uber', 'ola', 'bus', 'train', 'metro',
        'rapido', 'ticket', 'toll', 'parking']
  ),
  (
    id: 'health',
    label: 'Health',
    icon: Icons.medical_services_rounded,
    words: ['medicine', 'medicines', 'pharmacy', 'doctor', 'drops', 'hospital',
        'clinic', 'tablet', 'chemist', 'apollo']
  ),
  (
    id: 'grooming',
    label: 'Grooming',
    icon: Icons.content_cut_rounded,
    words: ['haircut', 'salon', 'barber', 'spa', 'grooming', 'parlour',
        'clip', 'trimmer', 'comb', 'nail', 'shave', 'razor']
  ),
  (
    id: 'bills',
    label: 'Bills',
    icon: Icons.bolt_rounded,
    words: ['electricity', 'water bill', 'gas bill', 'bill', 'recharge',
        'broadband', 'wifi', 'dth', 'postpaid', 'prepaid', 'cable',
        'cable tv', 'internet', 'mobile bill']
  ),
  (
    id: 'rent',
    label: 'Rent',
    icon: Icons.home_rounded,
    words: ['rent', 'maintenance', 'deposit']
  ),
  (
    id: 'fitness',
    label: 'Fitness',
    icon: Icons.fitness_center_rounded,
    words: ['gym', 'fitness', 'yoga', 'sports', 'cricket']
  ),
  (
    id: 'printing',
    label: 'Printing',
    icon: Icons.print_rounded,
    words: ['xerox', 'photocopy', 'print', 'printout', 'scan', 'lamination',
        'binding']
  ),
  (
    id: 'books',
    label: 'Books',
    icon: Icons.menu_book_rounded,
    words: ['book', 'books', 'stationery', 'pen', 'notebook']
  ),
  (
    id: 'education',
    label: 'Education',
    icon: Icons.school_rounded,
    words: ['school', 'fees', 'tuition', 'course', 'college', 'exam']
  ),
  (
    id: 'clothing',
    label: 'Clothing',
    icon: Icons.checkroom_rounded,
    words: ['clothes', 'shirt', 'shoe', 'chappal', 'slipper', 'sandal',
        'dress', 'saree', 'jeans', 'laundry', 'innerwear', 'socks']
  ),
  (
    id: 'household',
    label: 'Household',
    icon: Icons.cleaning_services_rounded,
    words: ['soap', 'shampoo', 'detergent', 'cleaning', 'utensil', 'repair',
        'furniture', 'paste', 'tissue', 'toothbrush', 'toothpaste', 'brush',
        'napkin', 'sanitizer', 'broom', 'bulb', 'battery']
  ),
  (
    id: 'software',
    label: 'Software',
    icon: Icons.cloud_rounded,
    words: ['domain', 'hosting', 'subscription', 'software', 'license',
        'netflix', 'spotify', 'icloud', 'renewal', 'claude code', 'claude',
        'chatgpt', 'openai', 'copilot', 'github', 'vercel', 'figma', 'credits']
  ),
  (
    id: 'gifts',
    label: 'Gifts',
    icon: Icons.card_giftcard_rounded,
    words: ['gift', 'donation', 'birthday', 'wedding']
  ),
  (
    id: 'jewellery',
    label: 'Jewellery',
    icon: Icons.diamond_rounded,
    words: ['gold', 'silver', 'jewellery', 'jewelry', 'ornament', 'chain',
        'bangle', 'ring', 'earring']
  ),
  (
    id: 'finance',
    label: 'Finance',
    icon: Icons.account_balance_rounded,
    words: ['bank', 'loan', 'emi', 'interest', 'insurance', 'premium', 'atm',
        'tax', 'charges', 'fine', 'penalty']
  ),
  (
    id: 'shopping',
    label: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    words: ['order', 'amazon', 'flipkart', 'myntra', 'shopping', 'online']
  ),
  (
    id: 'baby',
    label: 'Baby',
    icon: Icons.child_care_rounded,
    words: ['baby', 'diaper', 'toy', 'kids']
  ),
  (
    id: 'temple',
    label: 'Temple',
    icon: Icons.temple_buddhist_rounded,
    words: ['temple', 'mandir', 'laddu', 'puja', 'prasad', 'aarti']
  )
];

/// Icons for the three categories Yumeko ships with. A category you add
/// yourself has no icon of its own, so it falls back to the generic receipt —
/// which is fine, because the reason you type usually supplies one anyway.
const categoryIcons = <String, IconData>{
  'personal': Icons.person_rounded,
  'family': Icons.favorite_rounded,
  'office': Icons.work_rounded,
};

IconData categoryIcon(String? id) =>
    categoryIcons[id] ?? Icons.label_rounded;

/// Whole words only, with an optional plural.
///
/// Plain substring matching quietly mis-tags: "team lunch" contains "tea", so
/// a work dinner came back as Cafe. Anchoring on word boundaries is the
/// difference between a keyword map and a guessing game.
final _matchers = <String, RegExp>{
  for (final rule in _rules)
    rule.id: RegExp(
      r'\b(?:' +
          rule.words.map(RegExp.escape).join('|') +
          r')s?\b',
      caseSensitive: false,
    ),
};

/// Reason first, category as the fallback, and a neutral receipt when there is
/// neither — an untagged payment should not borrow a tag it never earned.
Tag tagFor(String? reason, String? category, {String? categoryLabel}) {
  final text = reason?.trim() ?? '';
  if (text.isNotEmpty) {
    for (final rule in _rules) {
      if (_matchers[rule.id]!.hasMatch(text)) {
        return (id: rule.id, label: rule.label, icon: rule.icon);
      }
    }
  }
  if (category != null) {
    return (
      id: category,
      label: categoryLabel ??
          category[0].toUpperCase() + category.substring(1).replaceAll('-', ' '),
      icon: categoryIcon(category),
    );
  }
  return _fallback;
}

Tag tagOf(Txn txn) => tagFor(txn.reason, txn.category);

/// Spend per tag for a set of transactions, biggest first. Credits are money
/// arriving, not something bought, so they never carry a tag total.
List<({Tag tag, double amount})> tagSpend(Iterable<Txn> txns) {
  final totals = <String, ({Tag tag, double amount})>{};
  for (final txn in txns) {
    if (txn.type != TxnType.debit) continue;
    final tag = tagOf(txn);
    final existing = totals[tag.id];
    totals[tag.id] =
        (tag: tag, amount: (existing?.amount ?? 0) + txn.amount);
  }
  final list = totals.values.toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return list;
}
