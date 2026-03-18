import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('d MMM yyyy', 'es');
  static final _timeFormat = DateFormat('HH:mm', 'es');
  static final _dateTimeFormat = DateFormat('d MMM yyyy HH:mm', 'es');


  static String currency(num amount) => _currencyFormat.format(amount);

  static String date(DateTime dt) => _dateFormat.format(dt.toLocal());

  static String time(DateTime dt) => _timeFormat.format(dt.toLocal());

  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

  static String points(int points) => NumberFormat('#,###').format(points);

  static String relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return _dateFormat.format(dt.toLocal());
  }

  static String eta(int minutes) {
    if (minutes <= 0) return 'Ahora';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }

  static String phone(String phone) {
    if (phone.length >= 10) {
      return '${phone.substring(0, phone.length - 7)} ${phone.substring(phone.length - 7, phone.length - 4)}-${phone.substring(phone.length - 4)}';
    }
    return phone;
  }
}
