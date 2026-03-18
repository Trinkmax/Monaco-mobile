import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('Formatters.currency', () {
    test('formats positive integer', () {
      expect(Formatters.currency(1500), contains('1.500'));
      expect(Formatters.currency(1500), contains('\$'));
    });

    test('formats zero', () {
      expect(Formatters.currency(0), contains('0'));
    });

    test('truncates decimals', () {
      // decimalDigits: 0, so no decimal portion
      final result = Formatters.currency(99.99);
      expect(result, contains('\$'));
      expect(result, contains('100'));
    });

    test('formats negative amount', () {
      final result = Formatters.currency(-500);
      expect(result, contains('500'));
    });

    test('formats large amount with thousands separator', () {
      final result = Formatters.currency(1000000);
      expect(result, contains('1.000.000'));
    });
  });

  group('Formatters.date', () {
    test('formats a date correctly', () {
      final dt = DateTime(2024, 3, 15);
      final result = Formatters.date(dt);
      expect(result, contains('15'));
      expect(result, contains('2024'));
    });

    test('formats single-digit day', () {
      final dt = DateTime(2024, 1, 5);
      final result = Formatters.date(dt);
      expect(result, contains('5'));
      expect(result, contains('2024'));
    });
  });

  group('Formatters.time', () {
    test('formats time as HH:mm', () {
      final dt = DateTime(2024, 1, 1, 14, 30);
      final result = Formatters.time(dt);
      expect(result, '14:30');
    });

    test('formats midnight', () {
      final dt = DateTime(2024, 1, 1, 0, 0);
      final result = Formatters.time(dt);
      expect(result, '00:00');
    });

    test('formats single-digit hour and minute with leading zero', () {
      final dt = DateTime(2024, 1, 1, 9, 5);
      final result = Formatters.time(dt);
      expect(result, '09:05');
    });
  });

  group('Formatters.dateTime', () {
    test('contains both date and time parts', () {
      final dt = DateTime(2024, 3, 15, 14, 30);
      final result = Formatters.dateTime(dt);
      expect(result, contains('15'));
      expect(result, contains('2024'));
      expect(result, contains('14:30'));
    });
  });

  group('Formatters.points', () {
    test('formats zero', () {
      expect(Formatters.points(0), '0');
    });

    test('formats small number without separator', () {
      expect(Formatters.points(999), '999');
    });

    test('formats thousands with separator', () {
      expect(Formatters.points(1500), '1,500');
    });

    test('formats large number', () {
      expect(Formatters.points(1000000), '1,000,000');
    });
  });

  group('Formatters.relativeTime', () {
    test('returns Ahora for less than 1 minute ago', () {
      final dt = DateTime.now().subtract(const Duration(seconds: 30));
      expect(Formatters.relativeTime(dt), 'Ahora');
    });

    test('returns Ahora for just now (0 seconds)', () {
      final dt = DateTime.now();
      expect(Formatters.relativeTime(dt), 'Ahora');
    });

    test('returns minutes for < 60 min', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(Formatters.relativeTime(dt), 'Hace 5 min');
    });

    test('returns minutes at 59 min boundary', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 59));
      expect(Formatters.relativeTime(dt), 'Hace 59 min');
    });

    test('returns hours for < 24h', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      expect(Formatters.relativeTime(dt), 'Hace 3h');
    });

    test('returns hours at 23h boundary', () {
      final dt = DateTime.now().subtract(const Duration(hours: 23));
      expect(Formatters.relativeTime(dt), 'Hace 23h');
    });

    test('returns days for < 7 days', () {
      final dt = DateTime.now().subtract(const Duration(days: 3));
      expect(Formatters.relativeTime(dt), 'Hace 3d');
    });

    test('returns days at 6d boundary', () {
      final dt = DateTime.now().subtract(const Duration(days: 6));
      expect(Formatters.relativeTime(dt), 'Hace 6d');
    });

    test('returns formatted date for >= 7 days', () {
      final dt = DateTime.now().subtract(const Duration(days: 10));
      final result = Formatters.relativeTime(dt);
      // Should not start with "Hace", should be a formatted date
      expect(result, isNot(startsWith('Hace')));
      expect(result, isNot('Ahora'));
    });
  });

  group('Formatters.eta', () {
    test('returns Ahora for 0 minutes', () {
      expect(Formatters.eta(0), 'Ahora');
    });

    test('returns Ahora for negative minutes', () {
      expect(Formatters.eta(-5), 'Ahora');
    });

    test('returns minutes for < 60', () {
      expect(Formatters.eta(30), '30 min');
    });

    test('returns 1 min for 1 minute', () {
      expect(Formatters.eta(1), '1 min');
    });

    test('returns 59 min at boundary', () {
      expect(Formatters.eta(59), '59 min');
    });

    test('returns hours and minutes for >= 60 with remainder', () {
      expect(Formatters.eta(90), '1h 30min');
    });

    test('returns only hours when no remainder', () {
      expect(Formatters.eta(120), '2h');
    });

    test('returns hours and minutes for large value', () {
      expect(Formatters.eta(150), '2h 30min');
    });

    test('returns only hours for exact multiple of 60', () {
      expect(Formatters.eta(180), '3h');
    });
  });

  group('Formatters.phone', () {
    test('formats 10-digit phone', () {
      final result = Formatters.phone('1123456789');
      expect(result, '112 345-6789');
    });

    test('formats 11-digit phone', () {
      final result = Formatters.phone('11234567890');
      expect(result, '1123 456-7890');
    });

    test('returns short phone unchanged', () {
      expect(Formatters.phone('12345'), '12345');
    });

    test('returns empty string unchanged', () {
      expect(Formatters.phone(''), '');
    });

    test('formats exactly 10 chars', () {
      final result = Formatters.phone('0123456789');
      // prefix: 012, middle: 345, last4: 6789
      expect(result, '012 345-6789');
    });

    test('returns 9-char phone unchanged', () {
      expect(Formatters.phone('123456789'), '123456789');
    });
  });
}
