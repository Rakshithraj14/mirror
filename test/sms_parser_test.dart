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

  test('UPI debit naming both sides is a debit, not a credit', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Rs.10.00 debited from A/c XX1234 and credited to merchant@upi on '
          '25-08-26. UPI Ref 523456789012. -Canara Bank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.debit);
    expect(txn.amount, 10.0);
    expect(txn.bank, 'Canara Bank');
  });

  test('credit naming both sides stays a credit', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Rs.1000.00 credited to A/c XX1234 debited from sender@upi on '
          '25-08-26. -Canara Bank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.credit);
  });

  test('parses the rupee symbol as an amount', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      '₹250.50 debited from your A/c XX1234 via UPI. -Canara Bank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.debit);
    expect(txn.amount, 250.50);
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
  // Real Canara Bank SMS, captured from a live test.
  test('parses the real Canara credit format', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Dear Customer, Acct XXX489 credited with INR 1,000.00 on 26/08/26 '
          'from MANJUNATH N; UPI:344289141508; Bal INR 1,343.42-CanaraBank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.credit);
    expect(txn.amount, 1000.0);
    expect(txn.bank, 'Canara Bank');
  });

  // Real Canara Bank debit SMS. Canara abbreviates the verb to "Dr.".
  test('parses the real Canara debit format using Dr.', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Dear Customer, Acct XXX489 Dr. INR 190.00 on 01/07/26 to SHASHIKANTA; '
          'UPI: 618239653510; Bal INR 98.75.Not you?SMS BLOCKUPI to '
          '9901771222-CanaraBank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.debit);
    expect(txn.amount, 190.00);
    expect(txn.bank, 'Canara Bank');
  });

  test('parses a Cr. abbreviated credit', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Dear Customer, Acct XXX489 Cr. INR 500.00 on 26/08/26 from JOHN; '
          'UPI: 618239653511; Bal INR 598.75-CanaraBank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.credit);
    expect(txn.amount, 500.00);
  });

  // "Dr" inside a payee name must not flip a credit into a debit.
  test('ignores Dr. in a payee name', () {
    final txn = parseBankSms(
      'AD-CANBNK',
      'Dear Customer, Acct XXX489 credited with INR 750.00 on 26/08/26 '
          'from Dr. RAMESH; UPI:344289141512; Bal INR 1,343.42-CanaraBank',
      now,
    );

    expect(txn, isNotNull);
    expect(txn!.type, TxnType.credit);
    expect(txn.amount, 750.00);
  });
  group('payment app notifications', () {
    test('ignores apps that are not on the payment whitelist', () {
      final txn = parsePaymentNotification(
        'com.whatsapp',
        'Rahul',
        'sent you ₹500',
        now,
      );

      expect(txn, isNull);
    });

    test('captures a received amount with no bank-SMS wording', () {
      final txn = parsePaymentNotification(
        'com.samsung.android.spay',
        'Money received',
        'You received ₹5 from ANUP SINGH',
        now,
      );

      expect(txn, isNotNull);
      expect(txn!.type, TxnType.credit);
      expect(txn.amount, 5.0);
      expect(txn.bank, 'Samsung Wallet');
      expect(txn.source, TxnSource.notification);
    });

    test('captures a payment as a debit', () {
      final txn = parsePaymentNotification(
        'com.phonepe.app',
        'Payment successful',
        'You paid ₹250 to Chai Point',
        now,
      );

      expect(txn, isNotNull);
      expect(txn!.type, TxnType.debit);
      expect(txn.amount, 250.0);
    });

    test('ignores a whitelisted app notification with no amount', () {
      final txn = parsePaymentNotification(
        'com.phonepe.app',
        'Cashback awaits!',
        'Scan any QR to win rewards',
        now,
      );

      expect(txn, isNull);
    });
  });
  group('upi reference extraction', () {
    test('pulls the reference from the real Canara debit', () {
      final txn = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 Dr. INR 190.00 on 01/07/26 to SHASHIKANTA; '
            'UPI: 618239653510; Bal INR 98.75.Not you?SMS BLOCKUPI to '
            '9901771222-CanaraBank',
        now,
      );

      expect(txn!.upiRef, '618239653510');
    });

    test('does not mistake the block-UPI helpline for a reference', () {
      final txn = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 Dr. INR 50.00 on 01/07/26 to SHOP; '
            'Bal INR 98.75.Not you?SMS BLOCKUPI to 9901771222-CanaraBank',
        now,
      );

      expect(txn!.upiRef, isNull,
          reason: 'a wrong reference would discard real transactions');
    });

    test('handles the "UPI Ref No" wording', () {
      final txn = parseBankSms(
        'VM-HDFCBK',
        'Rs.500.00 debited from A/c XX1234 to VPA shop@upi. '
            'UPI Ref No 123456789012. -HDFC Bank',
        now,
      );

      expect(txn!.upiRef, '123456789012');
    });

    test('leaves the reference null when the message has none', () {
      final txn = parsePaymentNotification(
        'com.samsung.android.spay',
        'Money received',
        'You received ₹5 from ANUP SINGH',
        now,
      );

      expect(txn!.upiRef, isNull);
    });
  });

  group('closing balance', () {
    test("captures the bank's own balance without stealing the amount", () {
      final txn = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 Dr. INR 190.00 on 01/07/26 to '
            'SHASHIKANTA; UPI: 618239653510; Bal INR 98.75.Not you?'
            'SMS BLOCKUPI to 9901771222-CanaraBank',
        DateTime(2026, 7, 1),
      );

      expect(txn, isNotNull);
      // The amount must still be the transaction, not the balance beside it.
      expect(txn!.amount, 190);
      expect(txn.type, TxnType.debit);
      expect(txn.balanceAfter, 98.75);
    });

    test('reads a balance with thousands separators', () {
      final txn = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 credited with INR 1,000.00 on 26/08/26 '
            'from MANJUNATH N; UPI:344289141508; Bal INR 1,343.42-CanaraBank',
        DateTime(2026, 8, 26),
      );

      expect(txn!.amount, 1000);
      expect(txn.balanceAfter, 1343.42);
    });

    test('a message with no balance leaves it unknown', () {
      final txn = parseBankSms(
        'VM-HDFCBK',
        'Rs 250.00 debited from a/c XX1234 to someone@upi',
        DateTime(2026, 9, 1),
      );

      expect(txn!.amount, 250);
      expect(txn.balanceAfter, isNull);
    });
  });
}
