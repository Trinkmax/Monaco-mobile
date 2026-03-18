import 'package:flutter_test/flutter_test.dart';

/// Validates PIN format constraints independently of Supabase.
/// PIN must be 4-6 numeric digits.
bool isValidPin(String pin) {
  if (pin.length < 4 || pin.length > 6) return false;
  return RegExp(r'^\d+$').hasMatch(pin);
}

void main() {
  group('PIN validation', () {
    test('accepts 4-digit PIN', () {
      expect(isValidPin('1234'), isTrue);
    });

    test('accepts 5-digit PIN', () {
      expect(isValidPin('12345'), isTrue);
    });

    test('accepts 6-digit PIN', () {
      expect(isValidPin('123456'), isTrue);
    });

    test('rejects 3-digit PIN', () {
      expect(isValidPin('123'), isFalse);
    });

    test('rejects 7-digit PIN', () {
      expect(isValidPin('1234567'), isFalse);
    });

    test('rejects letters', () {
      expect(isValidPin('abcd'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidPin(''), isFalse);
    });

    test('rejects mixed alphanumeric', () {
      expect(isValidPin('12a4'), isFalse);
    });

    test('rejects special characters', () {
      expect(isValidPin('12@4'), isFalse);
    });

    test('rejects spaces', () {
      expect(isValidPin('12 4'), isFalse);
    });

    test('rejects single digit', () {
      expect(isValidPin('1'), isFalse);
    });

    test('accepts all zeros', () {
      expect(isValidPin('0000'), isTrue);
    });

    test('accepts all nines', () {
      expect(isValidPin('9999'), isTrue);
    });
  });
}
