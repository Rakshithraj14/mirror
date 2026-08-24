import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/sms_parser.dart';

void main() {
  final now = DateTime(2026, 8, 24, 10, 30);

  test('parses a debit SMS with bank resolved from sender ID', () {
    final txn = parseBankSms(
      'VM-HDFCBK',
      'Rs.500.00 debited from A/c XX1234 on 24-08-26 to VPA merchant@upi. Ref No 123456789012. -HDFC Bank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.debit);
    expect(txn.amount, 500.0);
    expect(txn.bank, 'HDFC Bank');
  });

  test('parses a credit SMS and comma-formatted amount', () {
    final txn = parseBankSms(
      'AD-SBIINB',
      'Dear Customer, INR 1,250.00 credited to your A/c XXXXX1234 on 24-Aug-26 via UPI Ref No 987654321. -SBI',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.credit);
    expect(txn.amount, 1250.0);
    expect(txn.bank, 'SBI');
  });

  test('ignores promotional SMS mentioning Rs but no account context', () {
    final txn = parseBankSms(
      'AX-PROMO',
      'Get Rs 100 cashback on your next order! Use code SAVE100.',
      now,
    );

    expect(txn, isNull);
  });

  test('ignores SMS with an amount and account context but no txn verb', () {
    final txn = parseBankSms(
      'AX-BANK',
      'Your A/c XX1234 UPI PIN can be reset. Daily limit is Rs 100000.',
      now,
    );

    expect(txn, isNull);
  });
}
