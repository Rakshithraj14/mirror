import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/upi.dart';

void main() {
  test('accepts real UPI IDs, rejects the rest', () {
    expect(isValidUpiId('7795356018@axl'), isTrue);
    expect(isValidUpiId('rakshith.r@okicici'), isTrue);
    expect(isValidUpiId(' 7795356018@ybl '), isTrue);

    expect(isValidUpiId('7795356018'), isFalse);
    expect(isValidUpiId('@axl'), isFalse);
    expect(isValidUpiId('a b@axl'), isFalse);
    expect(isValidUpiId('me@ax l'), isFalse);
    expect(isValidUpiId('me@@axl'), isFalse);
  });

  test('pay link carries payee, amount and note', () {
    expect(
      upiPayUri(
        upiId: '7795356018@axl',
        name: 'Rakshith Raj',
        amount: 250,
        note: 'chai & snacks',
      ),
      'upi://pay?pa=7795356018@axl&pn=Rakshith%20Raj&am=250.00&cu=INR'
      '&tn=chai%20%26%20snacks',
    );
  });

  test('a blank note is left out rather than sent empty', () {
    expect(
      upiPayUri(upiId: 'me@axl', name: 'Me', amount: 9.5, note: '  '),
      'upi://pay?pa=me@axl&pn=Me&am=9.50&cu=INR',
    );
  });
}
