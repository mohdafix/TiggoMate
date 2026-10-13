import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final DateFormat dateFormatter = DateFormat('dd MMM yyyy');
  static final DateFormat timeFormatter = DateFormat('hh:mm a');
  static final DateFormat dateTimeFormatter = DateFormat(
    'dd MMM yyyy, hh:mm a',
  );
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );
  static final NumberFormat kmFormatter = NumberFormat('#,##0', 'en_MY');

  static String formatCurrency(double amount) =>
      currencyFormatter.format(amount);

  static String formatDistance(double km) =>
      '${kmFormatter.format(km.round())} km';

  static String formatDate(DateTime date) => dateFormatter.format(date);

  static String formatDateTime(DateTime dateTime) =>
      dateTimeFormatter.format(dateTime);

  static String formatPercentage(double percent) =>
      '${percent.toStringAsFixed(0)}%';
}
