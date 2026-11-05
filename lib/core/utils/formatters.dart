import 'package:intl/intl.dart';

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _rupeeShort = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// ₹1,20,000 for whole amounts, ₹1,20,000.50 otherwise.
String money(num value) => value == value.roundToDouble() ? _rupeeShort.format(value) : _rupee.format(value);

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
String formatDateShort(DateTime d) => DateFormat('EEE, d MMM').format(d);
String formatDateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String formatMonth(DateTime d) => DateFormat('MMM').format(d);
String formatMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

const weekdayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Rounds to paise so totals don't pick up floating point noise.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;
