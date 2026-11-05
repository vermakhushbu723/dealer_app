import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';

/// The slots that can still be booked on [date], given the current time [now].
List<String> availableSlots(DateTime date, DateTime now) => [
  for (final (label, startHour) in AppConstants.deliverySlots)
    if (!isSameDay(date, now) || startHour >= now.hour + AppConstants.slotLeadHours + 1) label,
];

/// When [slot] starts on [date].
DateTime slotStart(DateTime date, String slot) {
  final hour = AppConstants.deliverySlots.where((s) => s.$1 == slot).firstOrNull?.$2 ?? 9;
  return DateTime(date.year, date.month, date.day, hour);
}

/// Today if a slot is still open, otherwise tomorrow.
DateTime firstDeliveryDate(DateTime now) {
  final today = dateOnly(now);
  return availableSlots(today, now).isNotEmpty ? today : today.add(const Duration(days: 1));
}
