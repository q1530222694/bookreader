import '../../../engine/localization_engine.dart';

import 'book_model.dart';

/// 按月聚合的阅读时间轴记录，用于回忆页「阅读时间轴」卡片与「查看全部」时间轴页。
/// 按书籍 lastReadAt 所在月份聚合（近似口径，详见 [monthTimeline]）。
class MonthTimelineRecord {
  /// 当月第一天（归一到零点），作为该月的唯一标识。
  final DateTime month;

  /// 当月有阅读活动的书籍数（读完 + 在读）。
  final int bookCount;

  /// 当月阅读总分钟（近似：取 lastReadAt 落在该月的书籍，累加其总阅读时长）。
  final int minutes;

  /// 当月阅读的书籍中被收藏的条数（近似：以 isFavorite 标记，无法精确到收藏时刻）。
  final int favorites;

  /// 当月读完的书籍（progress >= 1.0）。
  final List<BookModel> finished;

  /// 当月开始/在读的书籍（0 <= progress < 1.0，含仅记录时长未更新进度者）。
  final List<BookModel> started;

  const MonthTimelineRecord({
    required this.month,
    required this.bookCount,
    required this.minutes,
    required this.favorites,
    required this.finished,
    required this.started,
  });

  /// 从书籍列表按月聚合时间轴记录，结果按月份倒序（最近的月份在最前）。
  ///
  /// 聚合口径说明（与全 App 其它统计保持一致）：
  /// - 仅统计有阅读活动的书籍（progress>0 或 readingDurationSeconds>0）；
  /// - 以 lastReadAt 所在月份归属，一本书只计入其「最后阅读」所在月；
  /// - 阅读时长为书籍累计总时长（模型未记录逐月明细，故为近似）；
  /// - 收藏数取该月书籍中 isFavorite 为真的数量（模型未记录收藏时刻，故为近似）。
  static List<MonthTimelineRecord> monthTimeline(List<BookModel> books) {
    final Map<DateTime, List<BookModel>> grouped = {};
    for (final book in books) {
      if (book.progress <= 0 && book.readingDurationSeconds <= 0) continue;
      final lr = book.lastReadAt;
      if (lr == null) continue; // 无阅读时间则无法归属月份
      final key = DateTime(lr.year, lr.month, 1);
      grouped.putIfAbsent(key, () => []).add(book);
    }

    final records = <MonthTimelineRecord>[];
    for (final entry in grouped.entries) {
      final monthBooks = entry.value;
      var minutes = 0;
      var favorites = 0;
      final finished = <BookModel>[];
      final started = <BookModel>[];
      for (final b in monthBooks) {
        final m = b.readingDurationSeconds > 0
            ? ((b.readingDurationSeconds + 59) ~/ 60)
            : (b.progress * 60).ceil();
        minutes += m;
        if (b.isFavorite) favorites++;
        if (b.progress >= 1.0) {
          finished.add(b);
        } else {
          started.add(b);
        }
      }
      records.add(
        MonthTimelineRecord(
          month: entry.key,
          bookCount: monthBooks.length,
          minutes: minutes,
          favorites: favorites,
          finished: finished,
          started: started,
        ),
      );
    }
    // 按月份倒序，最近的月份排最前
    records.sort((a, b) => b.month.compareTo(a.month));
    return records;
  }
}

/// ReadingStats aggregates reading duration and activity information from a
/// list of books.
class ReadingStats {
  final Map<DateTime, int> dailyMinutes;
  // 每天 4 个「6 小时段」的阅读分钟数：key=日期(归一到零点)，value=长度 4 的列表
  // 下标含义：[0]=00:00~06:00 [1]=06:00~12:00 [2]=12:00~18:00 [3]=18:00~24:00
  // 用于热力图把每个日期格切分为 4 块、分别显示各时段的阅读情况。
  final Map<DateTime, List<int>> dailyBlockMinutes;
  // 小时级阅读分钟分布（0~23 时），用于「阅读时间分布·时段」统计
  final Map<int, int> hourlyMinutes;
  // 按天 × 按小时的阅读分钟明细：key=日期(归一到零点)，value=长度 24 的列表，
  // 下标即 0~23 时。用于「日」视图下趋势图（按小时）/ 热力图（每小时切 4 格）。
  final Map<DateTime, List<int>> dailyHourlyMinutes;
  // 按天 × 按「15 分钟段」的阅读分钟明细：key=日期(归一到零点)，
  // value=长度 96 的列表，下标 = 小时×4 + (分钟~/15)，覆盖 00:00~23:59 共 96 段。
  // 用于「日」视图热力图：每小时切成 4 个小方格（每格 = 1 个 15 分钟段）。
  final Map<DateTime, List<int>> dailyQuarterMinutes;
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
    required this.dailyBlockMinutes,
    required this.hourlyMinutes,
    required this.dailyHourlyMinutes,
    required this.dailyQuarterMinutes,
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
    final dailyBlock = <DateTime, List<int>>{};
    final hourly = <int, int>{};
    final dailyHourly = <DateTime, List<int>>{};
    final dailyQuarter = <DateTime, List<int>>{};

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

      // 记录每个日期 4 个「6 小时段」的阅读分钟：按最后阅读时间所在小时归入对应时段
      final block =
          book.lastReadAt == null ? 0 : (book.lastReadAt!.hour ~/ 6).clamp(0, 3);
      final blocks = dailyBlock.putIfAbsent(readDate, () => [0, 0, 0, 0]);
      blocks[block] += minutes;

      // 记录小时级分布，用于「时段」统计：取书籍真实的最后阅读时间所在小时
      if (book.lastReadAt != null) {
        final h = book.lastReadAt!.hour;
        hourly[h] = (hourly[h] ?? 0) + minutes;

        // 按天 × 按小时聚合：将阅读分钟累加到该日对应小时档
        final dh = dailyHourly.putIfAbsent(readDate, () => List.filled(24, 0));
        dh[h] += minutes;

        // 按天 × 按「15 分钟段」聚合：取真实最后阅读时间的分钟定位到该小时内的第几段
        // （0~3 段，对应 0-14/15-29/30-44/45-59 分钟），与小时档的分钟均分无冲突。
        final quarter = (book.lastReadAt!.minute ~/ 15).clamp(0, 3);
        final dq = dailyQuarter.putIfAbsent(readDate, () => List.filled(96, 0));
        dq[h * 4 + quarter] += minutes;
      }
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
      dailyBlockMinutes: dailyBlock,
      hourlyMinutes: hourly,
      dailyHourlyMinutes: dailyHourly,
      dailyQuarterMinutes: dailyQuarter,
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

  /// 统计区间内「读完」的书籍数量：进度达到 100%（progress>=1.0），
  /// 且最后阅读时间落在区间 [startInclusive, endExclusive) 内。
  /// 与「点开过几本书」区分——仅统计真正读完的书籍。
  static int completedBooksInRange(
    List<BookModel> books,
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    var count = 0;
    for (final b in books) {
      if (b.progress < 1.0) continue; // 未读完，不计入
      final lr = b.lastReadAt;
      if (lr == null) continue;
      if (!lr.isBefore(startInclusive) && lr.isBefore(endExclusive)) count++;
    }
    return count;
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

  /// 统计区间内「有阅读活动的天数」（累计阅读天数）。
  /// 与 [minutesBetween] 不同，这里计数的是「天数」而非「分钟数」：
  /// 凡是区间 [startInclusive, endExclusive) 内有阅读记录的日期都计入 1 天。
  int activeDaysInRange(DateTime startInclusive, DateTime endExclusive) {
    var count = 0;
    for (final d in dailyMinutes.keys) {
      if (!d.isBefore(startInclusive) && d.isBefore(endExclusive)) count++;
    }
    return count;
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
