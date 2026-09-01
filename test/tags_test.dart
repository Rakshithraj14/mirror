import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/tags.dart';

Txn txn(double amount, {String? reason, String? category, TxnType type = TxnType.debit}) =>
    Txn(
      bank: 'Canara Bank',
      amount: amount,
      type: type,
      time: DateTime(2026, 9, 1, 12),
      source: TxnSource.sms,
      rawSender: 'AD-CANBNK',
      rawBody: 'raw',
      category: category,
      reason: reason,
    );

void main() {
  group('tagFor', () {
    test('reads the tag out of what you typed', () {
      expect(tagFor('chai', null).label, 'Cafe');
      expect(tagFor('fuel', null).label, 'Fuel');
      expect(tagFor('grocery', null).label, 'Groceries');
      expect(tagFor('haircut', null).label, 'Grooming');
      expect(tagFor('electricity bill', null).label, 'Bills');
      expect(tagFor('nose drops', null).label, 'Health');
    });

    test('the reason beats the category', () {
      // "team lunch" is an Office expense, but it is still Dining. The
      // category says who it was for; the tag says what it bought.
      expect(tagFor('team lunch', 'office').label, 'Dining');
    });

    test('is case and spacing insensitive', () {
      expect(tagFor('  CHAI  ', null).id, tagFor('chai', null).id);
    });

    test('falls back to the category when the reason says nothing useful', () {
      expect(tagFor('xyzzy', 'family').label, 'Family');
      expect(tagFor('xyzzy', 'family').icon, Icons.favorite_rounded);
    });

    test('reads the everyday words you actually type', () {
      expect(tagFor('ice cream', null).label, 'Cafe');
      expect(tagFor('coke', null).label, 'Cafe');
      expect(tagFor('pepsi', null).label, 'Cafe');
      expect(tagFor('cable', null).label, 'Bills');
      expect(tagFor('tissue', null).label, 'Household');
      expect(tagFor('toothbrush', null).label, 'Household');
      expect(tagFor('claude code', null).label, 'Software');
      expect(tagFor('xerox', null).label, 'Printing');
      expect(tagFor('gold', null).label, 'Jewellery');
      expect(tagFor('silver', null).label, 'Jewellery');
      expect(tagFor('bank charges', null).label, 'Finance');
      expect(tagFor('loan', null).label, 'Finance');
      expect(tagFor('shoes', null).label, 'Clothing');
      expect(tagFor('pvr', null).label, 'Entertainment');
      expect(tagFor('clips', null).label, 'Grooming');
      expect(tagFor('fish', null).label, 'Groceries');
    });

    test('a movie ticket is not a bus ticket', () {
      // 'ticket' belongs to Transport, so Entertainment has to be asked first.
      expect(tagFor('movie ticket', null).label, 'Entertainment');
      expect(tagFor('train ticket', null).label, 'Transport');
    });

    test('an untagged payment borrows no tag it did not earn', () {
      expect(tagFor(null, null).label, 'Other');
      expect(tagFor('', null).label, 'Other');
    });
  });

  group('tagSpend', () {
    test('totals by tag, biggest first', () {
      final spend = tagSpend([
        txn(100, reason: 'chai', category: 'personal'),
        txn(50, reason: 'coffee', category: 'personal'),
        txn(400, reason: 'fuel', category: 'personal'),
      ]);

      expect(spend.first.tag.label, 'Fuel');
      expect(spend.first.amount, 400);
      // chai and coffee are one tag, so they add up rather than competing.
      expect(spend[1].tag.label, 'Cafe');
      expect(spend[1].amount, 150);
    });

    test('credits are money arriving, not something bought', () {
      final spend = tagSpend([
        txn(1000, reason: 'salary', type: TxnType.credit),
        txn(40, reason: 'chai', category: 'personal'),
      ]);

      expect(spend.length, 1);
      expect(spend.single.tag.label, 'Cafe');
    });
  });
}
