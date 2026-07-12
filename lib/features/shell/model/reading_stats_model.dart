import '../../../engine/localization_engine.dart';

import 'book_model.dart';

/// ReadingStats aggregates reading duration and activity information from a
/// list of books.
class ReadingStats {
  final Map<DateTime, int> dailyMinutes;
  final int totalMinutes;
  final int todayMinutes;
  final int yesterdayMinutes;
  final int weekMinutes;
  final int previousWeekMinutes;
  final int monthMinutes;
  final int previousMonthMinutes;
  final int yearMinutes;
  final int previousYearMinutes;
  final int previousDailyWindowMinutes;
  final int activeDays;
  final int streakDays;
  final int completedBooks;
  final DateTime? longestReadingDay;
  final int longestReadingDuration;
  final int distributionUnder1HourMinutes;
  final int distribution1To2HoursMinutes;
  final int distribution2To3HoursMinutes;
  final int distribution3HoursMoreMinutes;

  String get formattedTodayReading => _formatDuration(todayMinutes);
  String get formattedWeekReading => _formatDuration(weekMinutes);
  String get formattedTotalReading => _formatDuration(totalMinutes);
  String get formattedTotalReadingShort => _formatDurationShort(totalMinutes);
  String get formattedAverageDailyReading => _formatDuration(
        (totalMinutes / (activeDays > 0 ? activeDays : 1)).round(),
      );
  String get todayChangeLabel =>
      _formatChangeRate(todayMinutes / 60.0, yesterdayMinutes / 60.0);
  String get weekChangeLabel =>
      _formatChangeRate(weekMinutes / 60.0, previousWeekMinutes / 60.0);
  String get longestReadingDayLabel => longestReadingDay == null
      ? LocalizationEngine.text('today_reading')
      : '${longestReadingDay!.month}/${longestReadingDay!.day}';
  String get longestReadingDurationLabel =>
      _formatDuration(longestReadingDuration);
  String get formattedDistributionTotal => _formatDuration(totalMinutes);

  ReadingStats._({
    required this.dailyMinutes,
    required this.totalMinutes,
    required this.todayMinutes,
    required this.yesterdayMinutes,
    required this.weekMinutes,
    required this.previousWeekMinutes,
    required this.monthMinutes,
    required this.previousMonthMinutes,
    required this.yearMinutes,
    required this.previousYearMinutes,
    required this.previousDailyWindowMinutes,
    required this.activeDays,
    required this.streakDays,
    required this.completedBooks,
    required this.longestReadingDay,
    required this.longestReadingDuration,
    required this.distributionUnder1HourMinutes,
    required this.distribution1To2HoursMinutes,
    required this.distribution2To3HoursMinutes,
    required this.distribution3HoursMoreMinutes,
  });

  static ReadingStats fromBooks(List<BookModel> books) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = <DateTime, int>{};

    for (final book in books) {
      if (book.progress <= 0 && book.readingDurationSeconds <= 0) {
        continue;
      }
      final minutes = book.readingDurationSeconds > 0
          ? ((book.readingDurationSeconds + 59) ~/ 60)
          : (book.progress * 60).ceil();
      final readDate = book.lastReadAt == null
          ? today
          : DateTime(
              book.lastReadAt!.year,
              book.lastReadAt!.month,
              book.lastReadAt!.day,
            );
      normalized[readDate] = (normalized[readDate] ?? 0) + minutes;
    }

    final totalMinutes = normalized.values.fold<int>(0, (sum, value) => sum + value);
    final todayMinutes = normalized[today] ?? 0;
    final yesterdayMinutes = normalized[today.subtract(const Duration(days: 1))] ?? 0;

    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    final currentMonthStart = DateTime(today.year, today.month, 1);
    final previousMonthStart = DateTime(today.year, today.month - 1, 1);
    final currentYearStart = DateTime(today.year, 1, 1);
    final previousYearStart = DateTime(today.year - 1, 1, 1);

    final weekMinutes = _sumInRange(
      currentWeekStart,
      currentWeekStart.add(const Duration(days: 7)),
      normalized,
    );
    final previousWeekMinutes = _sumInRange(
      previousWeekStart,
      currentWeekStart,
      normalized,
    );
    final monthMinutes = _sumInRange(
      currentMonthStart,
      DateTime(today.year, today.month + 1, 1),
      normalized,
    );
    final previousMonthMinutes = _sumInRange(
      previousMonthStart,
      currentMonthStart,
      normalized,
    );
    final yearMinutes = _sumInRange(
      currentYearStart,
      DateTime(today.year + 1, 1, 1),
      normalized,
    );
    final previousYearMinutes = _sumInRange(
      previousYearStart,
      currentYearStart,
      normalized,
    );

    final periodDays = 12;
    final currentWindowStart = today.subtract(Duration(days: periodDays - 1));
    final previousWindowStart = currentWindowStart.subtract(Duration(days: periodDays));
    final previousDailyWindowMinutes = _sumInRange(
      previousWindowStart,
      currentWindowStart,
      normalized,
    );

    final uniqueDays = normalized.keys.toSet();
    final activeDays = uniqueDays.length;
    final streakDays = _countStreakDays(uniqueDays, today);

    final longestEntry = normalized.entries.fold<MapEntry<DateTime, int>?>(
      null,
      (previous, entry) {
        if (previous == null) return entry;
        return entry.value >= previous.value ? entry : previous;
      },
    );

    final longestReadingDay = longestEntry?.key;
    final longestReadingDuration = longestEntry?.value ?? 0;

    var distributionUnder1HourMinutes = 0;
    var distribution1To2HoursMinutes = 0;
    var distribution2To3HoursMinutes = 0;
    var distribution3HoursMoreMinutes = 0;

    for (final minutes in normalized.values) {
      if (minutes < 60) {
        distributionUnder1HourMinutes += minutes;
      } else if (minutes < 120) {
        distribution1To2HoursMinutes += minutes;
      } else if (minutes < 180) {
        distribution2To3HoursMinutes += minutes;
      } else {
        distribution3HoursMoreMinutes += minutes;
      }
    }

    return ReadingStats._(
      dailyMinutes: normalized,
      totalMinutes: totalMinutes,
      todayMinutes: todayMinutes,
      yesterdayMinutes: yesterdayMinutes,
      weekMinutes: weekMinutes,
      previousWeekMinutes: previousWeekMinutes,
      monthMinutes: monthMinutes,
      previousMonthMinutes: previousMonthMinutes,
      yearMinutes: yearMinutes,
      previousYearMinutes: previousYearMinutes,
      previousDailyWindowMinutes: previousDailyWindowMinutes,
      activeDays: activeDays,
      streakDays: streakDays,
      completedBooks: books.where((book) => book.progress >= 1.0).length,
      longestReadingDay: longestReadingDay,
      longestReadingDuration: longestReadingDuration,
      distributionUnder1HourMinutes: distributionUnder1HourMinutes,
      distribution1To2HoursMinutes: distribution1To2HoursMinutes,
      distribution2To3HoursMinutes: distribution2To3HoursMinutes,
      distribution3HoursMoreMinutes: distribution3HoursMoreMinutes,
    );
  }

  static int _sumInRange(
    DateTime startInclusive,
    DateTime endExclusive,
    Map<DateTime, int> dailyMinutes,
  ) {
    var sum = 0;
    for (final entry in dailyMinutes.entries) {
      if (!entry.key.isBefore(startInclusive) && entry.key.isBefore(endExclusive)) {
        sum += entry.value;
      }
    }
    return sum;
  }

  static int _countStreakDays(Set<DateTime> uniqueDays, DateTime today) {
    var streak = 0;
    var cursor = today;
    while (uniqueDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int minutesBetween(DateTime startInclusive, DateTime endExclusive) {
    var sum = 0;
    for (final entry in dailyMinutes.entries) {
      if (!entry.key.isBefore(startInclusive) && entry.key.isBefore(endExclusive)) {
        sum += entry.value;
      }
    }
    return sum;
  }

  static String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0${LocalizationEngine.text('minutes_short')}';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final hourPart = hours > 0 ? '$hours${LocalizationEngine.text('hours_short')}' : '';
    final minutePart = '$mins${LocalizationEngine.text('minutes_short')}';
    return hourPart.isNotEmpty ? '$hourPart $minutePart' : minutePart;
  }

  static String _formatDurationShort(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours${LocalizationEngine.text('hours_short')}';
    }
    return '$mins${LocalizationEngine.text('minutes_short')}';
  }

  static String _formatChangeRate(double current, double previous) {
    if (previous <= 0) {
      return current <= 0 ? '0%' : '+100%';
    }
    final rate = ((current - previous) / previous) * 100;
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(0)}%';
  }
}
