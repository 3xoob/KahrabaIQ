import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/app_state_widgets.dart';
import '../../../shared/services/kahrabaiq_api_service.dart';

class EnergyHistoryScreen extends StatefulWidget {
  const EnergyHistoryScreen({
    super.key,
    required this.homeId,
    required this.dashboard,
  });

  final String homeId;
  final DashboardData dashboard;

  @override
  State<EnergyHistoryScreen> createState() => _EnergyHistoryScreenState();
}

class _EnergyHistoryScreenState extends State<EnergyHistoryScreen> {
  final KahrabaIqApiService _api = KahrabaIqApiService();
  late Future<EnergyHistoryData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.dashboard.scenarioId != null
        ? Future.value(_demoEnergyHistoryData(widget.dashboard))
        : _api.fetchEnergyHistory(homeId: widget.homeId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.dashboard.scenarioId != null
          ? Future.value(_demoEnergyHistoryData(widget.dashboard))
          : _api.fetchEnergyHistory(homeId: widget.homeId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Energy Insights')),
      body: RefreshIndicator(
        color: ColorTokens.primary,
        onRefresh: _reload,
        child: FutureBuilder<EnergyHistoryData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: snapshot.error.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
                onRetry: _reload,
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const AppEmptyState(
                icon: Icons.insights,
                title: 'No energy history',
                message:
                    'Energy summaries will appear after the Pi syncs them.',
              );
            }
            final dailyPoints = data.dailyEnergy.isNotEmpty
                ? data.dailyEnergy
                : data.hourlyUsage;
            final monthlyPoints = data.monthlyEnergy.isNotEmpty
                ? data.monthlyEnergy
                : dailyPoints;
            final costPoints = data.costHistory.isNotEmpty
                ? data.costHistory
                : dailyPoints;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text('Energy Consumption History', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Review usage patterns and find where energy can be reduced.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 18),
                _SummaryGrid(dashboard: widget.dashboard, data: data),
                const SizedBox(height: 18),
                _LineChartCard(
                  title: 'Power Over Time',
                  empty: 'No power history available yet.',
                  points: data.hourlyUsage.isNotEmpty
                      ? data.hourlyUsage
                      : data.powerHistory,
                  value: (point) => point.powerW,
                  labelType: _ChartLabelType.time,
                  valueFormatter: _formatPowerValue,
                  color: ColorTokens.warning,
                  periods: _ChartPeriod.powerPeriods,
                ),
                _LineChartCard(
                  title: 'Daily Energy Usage',
                  empty: 'No daily energy summaries yet.',
                  points: dailyPoints,
                  value: (point) => point.kwh,
                  labelType: _ChartLabelType.day,
                  valueFormatter: _formatEnergyValue,
                  color: ColorTokens.success,
                  periods: _ChartPeriod.dayPeriods,
                ),
                _LineChartCard(
                  title: 'Monthly Energy Usage',
                  empty: 'No monthly energy summaries yet.',
                  points: monthlyPoints,
                  value: (point) => point.kwh,
                  labelType: _ChartLabelType.month,
                  valueFormatter: _formatEnergyValue,
                  color: ColorTokens.primary,
                  periods: _ChartPeriod.monthPeriods,
                ),
                _LineChartCard(
                  title: 'Cost Over Time',
                  empty: 'No cost history available yet.',
                  points: costPoints,
                  value: (point) => point.costBhd,
                  labelType: _ChartLabelType.day,
                  valueFormatter: _formatCostValue,
                  color: ColorTokens.info,
                  periods: _ChartPeriod.dayPeriods,
                ),
                _BreakerContributionCard(items: data.breakerContribution),
                _PeakHoursCard(items: data.peakUsageHours),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.dashboard, required this.data});

  final DashboardData dashboard;
  final EnergyHistoryData data;

  @override
  Widget build(BuildContext context) {
    final breakers = dashboard.devices
        .where((device) => device.id.startsWith('breaker_'))
        .toList();
    final peak = data.powerHistory.fold<double>(
      dashboard.reading.power,
      (max, item) => item.powerW > max ? item.powerW : max,
    );
    final topBreaker = breakers.isEmpty
        ? 'Waiting'
        : breakers
              .reduce((a, b) => a.energyToday >= b.energyToday ? a : b)
              .name;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryTile(
          'Today',
          '${dashboard.reading.energyToday.toStringAsFixed(2)} kWh',
        ),
        _SummaryTile(
          'Today cost',
          '${dashboard.reading.costToday.toStringAsFixed(3)} BHD',
        ),
        _SummaryTile(
          'Month',
          dashboard.reading.monthDataAvailable
              ? '${dashboard.reading.energyMonth.toStringAsFixed(1)} kWh'
              : '--',
        ),
        _SummaryTile(
          'Month cost',
          dashboard.reading.monthDataAvailable
              ? '${dashboard.reading.costMonth.toStringAsFixed(3)} BHD'
              : '--',
        ),
        _SummaryTile('Peak', '${peak.toStringAsFixed(0)} W'),
        _SummaryTile('Top breaker', topBreaker),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 50) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.bodyMedium, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _LineChartCard extends StatefulWidget {
  const _LineChartCard({
    required this.title,
    required this.empty,
    required this.points,
    required this.value,
    required this.labelType,
    required this.valueFormatter,
    required this.color,
    required this.periods,
  });

  final String title;
  final String empty;
  final List<EnergyHistoryPoint> points;
  final double Function(EnergyHistoryPoint point) value;
  final _ChartLabelType labelType;
  final String Function(double value) valueFormatter;
  final Color color;

  final List<_ChartPeriod> periods;

  @override
  State<_LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<_LineChartCard> {
  late _ChartPeriod _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.periods.first;
  }

  @override
  void didUpdateWidget(covariant _LineChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stillAvailable = widget.periods.any(
      (period) => period.label == _selectedPeriod.label,
    );
    if (!stillAvailable) {
      _selectedPeriod = widget.periods.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartPoints = _selectedPeriod.filter(widget.points);
    final latest = chartPoints.isEmpty ? 0.0 : widget.value(chartPoints.last);
    final total = chartPoints.fold<double>(
      0,
      (sum, point) => sum + widget.value(point),
    );
    final average = chartPoints.isEmpty ? 0.0 : total / chartPoints.length;
    final peak = chartPoints.fold<double>(
      0,
      (max, point) => widget.value(point) > max ? widget.value(point) : max,
    );
    final highest = chartPoints.isEmpty
        ? null
        : chartPoints.reduce(
            (a, b) => widget.value(a) >= widget.value(b) ? a : b,
          );
    final estimatedCost = chartPoints.fold<double>(
      0,
      (sum, point) => sum + point.costBhd,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: AppTextStyles.h3)),
              _PeriodDropdown(
                periods: widget.periods,
                selected: _selectedPeriod,
                onChanged: (period) {
                  if (period == null) {
                    return;
                  }
                  setState(() => _selectedPeriod = period);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (chartPoints.isEmpty)
            _EmptyInline(message: widget.empty)
          else
            SizedBox(
              height: 230,
              child: LineChart(
                _chartData(
                  chartPoints,
                  widget.color,
                  widget.value,
                  widget.labelType,
                  widget.valueFormatter,
                ),
              ),
            ),
          if (chartPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatPill('Latest', widget.valueFormatter(latest)),
                _StatPill('Average', widget.valueFormatter(average)),
                if (widget.title.contains('Daily'))
                  _StatPill(
                    'Highest day',
                    highest == null
                        ? '--'
                        : widget.valueFormatter(widget.value(highest)),
                  )
                else
                  _StatPill('Peak', widget.valueFormatter(peak)),
                if (widget.title.contains('Energy') ||
                    widget.title.contains('Cost'))
                  _StatPill(
                    widget.title.contains('Cost') ? 'Total' : 'Estimated cost',
                    widget.title.contains('Cost')
                        ? widget.valueFormatter(total)
                        : '${estimatedCost.toStringAsFixed(3)} BHD',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakerContributionCard extends StatelessWidget {
  const _BreakerContributionCard({required this.items});

  final List<BreakerContribution> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Breaker Contribution', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const _EmptyInline(
              message: 'No breaker energy contribution data yet.',
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _breakerDisplayName(item),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Text(
                          '${item.percentage.toStringAsFixed(0)}%',
                          style: AppTextStyles.mono,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (item.percentage / 100).clamp(0, 1),
                      color: ColorTokens.primary,
                      backgroundColor: ColorTokens.border,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_breakerBranchLabel(item)} | ${item.energyKwh.toStringAsFixed(3)} kWh | ${item.costBhd.toStringAsFixed(3)} BHD',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  final List<_ChartPeriod> periods;
  final _ChartPeriod selected;
  final ValueChanged<_ChartPeriod?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorTokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ChartPeriod>(
          value: selected,
          dropdownColor: ColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: ColorTokens.textMuted,
          ),
          style: AppTextStyles.caption.copyWith(color: ColorTokens.textPrimary),
          items: [
            for (final period in periods)
              DropdownMenuItem(value: period, child: Text(period.label)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PeakHoursCard extends StatelessWidget {
  const _PeakHoursCard({required this.items});

  final List<EnergyHistoryPoint> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Peak Usage Hours', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const _EmptyInline(message: 'No hourly usage data yet.')
          else
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorTokens.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ColorTokens.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${entry.key + 1}',
                        style: AppTextStyles.caption.copyWith(
                          color: ColorTokens.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hourRange(item),
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.costBhd.toStringAsFixed(3)} BHD | ${_formatPowerValue(item.powerW)} peak avg',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.kwh.toStringAsFixed(3)} kWh',
                      style: AppTextStyles.mono,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

enum _ChartLabelType { time, day, month }

enum _ChartBucket { raw, hour, day, month }

class _ChartPeriod {
  const _ChartPeriod(
    this.label, {
    this.duration,
    this.maxPoints,
    this.bucket = _ChartBucket.raw,
  });

  final String label;
  final Duration? duration;
  final int? maxPoints;
  final _ChartBucket bucket;

  static const powerPeriods = [
    _ChartPeriod('1h', duration: Duration(hours: 1), bucket: _ChartBucket.hour),
    _ChartPeriod('4h', duration: Duration(hours: 4), bucket: _ChartBucket.hour),
    _ChartPeriod(
      '12h',
      duration: Duration(hours: 12),
      bucket: _ChartBucket.hour,
    ),
    _ChartPeriod(
      '24h',
      duration: Duration(hours: 24),
      bucket: _ChartBucket.hour,
    ),
  ];

  static const dayPeriods = [
    _ChartPeriod('7d', duration: Duration(days: 7), bucket: _ChartBucket.day),
    _ChartPeriod('30d', duration: Duration(days: 30), bucket: _ChartBucket.day),
    _ChartPeriod('90d', duration: Duration(days: 90), bucket: _ChartBucket.day),
    _ChartPeriod('All', bucket: _ChartBucket.day),
  ];

  static const monthPeriods = [
    _ChartPeriod('6m', maxPoints: 6, bucket: _ChartBucket.month),
    _ChartPeriod('12m', maxPoints: 12, bucket: _ChartBucket.month),
    _ChartPeriod('All', bucket: _ChartBucket.month),
  ];

  List<EnergyHistoryPoint> filter(List<EnergyHistoryPoint> points) {
    if (points.isEmpty) {
      return points;
    }
    final sorted = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var filtered = sorted;
    if (duration != null) {
      final latest = sorted.last.timestamp;
      final cutoff = latest.subtract(duration!);
      filtered = sorted
          .where((point) => !point.timestamp.isBefore(cutoff))
          .toList();
    }
    if (maxPoints != null && filtered.length > maxPoints!) {
      filtered = filtered.sublist(filtered.length - maxPoints!);
    }
    return _fillBuckets(filtered, sorted.last.timestamp);
  }

  List<EnergyHistoryPoint> _fillBuckets(
    List<EnergyHistoryPoint> points,
    DateTime anchor,
  ) {
    if (bucket == _ChartBucket.raw) {
      return points;
    }

    final sorted = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final first = sorted.isEmpty ? anchor : sorted.first.timestamp;
    final buckets = <DateTime, List<EnergyHistoryPoint>>{};
    for (final point in sorted) {
      final key = _bucketStart(point.timestamp, bucket);
      buckets.putIfAbsent(key, () => []).add(point);
    }

    final range = _bucketRange(
      first: first,
      anchor: anchor,
      bucket: bucket,
      duration: duration,
      maxPoints: maxPoints,
    );

    return [
      for (final start in range)
        _bucketPoint(start, bucket, buckets[start] ?? const []),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is _ChartPeriod &&
        other.label == label &&
        other.duration == duration &&
        other.maxPoints == maxPoints &&
        other.bucket == bucket;
  }

  @override
  int get hashCode {
    return Object.hash(label, duration, maxPoints, bucket);
  }
}

DateTime _bucketStart(DateTime timestamp, _ChartBucket bucket) {
  final local = timestamp.toLocal();
  return switch (bucket) {
    _ChartBucket.raw => local,
    _ChartBucket.hour => DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
    ),
    _ChartBucket.day => DateTime(local.year, local.month, local.day),
    _ChartBucket.month => DateTime(local.year, local.month),
  };
}

List<DateTime> _bucketRange({
  required DateTime first,
  required DateTime anchor,
  required _ChartBucket bucket,
  required Duration? duration,
  required int? maxPoints,
}) {
  final end = _bucketStart(anchor, bucket);
  DateTime start;
  if (bucket == _ChartBucket.month && maxPoints != null) {
    start = _addMonths(end, -(maxPoints - 1));
  } else if (bucket == _ChartBucket.day && duration != null) {
    final days = duration.inDays <= 0 ? 1 : duration.inDays;
    start = end.subtract(Duration(days: days - 1));
  } else if (bucket == _ChartBucket.hour && duration != null) {
    final hours = duration.inHours <= 0 ? 1 : duration.inHours;
    start = end.subtract(Duration(hours: hours));
  } else {
    start = _bucketStart(first, bucket);
  }

  final range = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    range.add(cursor);
    cursor = switch (bucket) {
      _ChartBucket.raw => end.add(const Duration(milliseconds: 1)),
      _ChartBucket.hour => cursor.add(const Duration(hours: 1)),
      _ChartBucket.day => cursor.add(const Duration(days: 1)),
      _ChartBucket.month => _addMonths(cursor, 1),
    };
  }
  return range;
}

EnergyHistoryPoint _bucketPoint(
  DateTime start,
  _ChartBucket bucket,
  List<EnergyHistoryPoint> points,
) {
  if (points.isEmpty) {
    return EnergyHistoryPoint(
      timestamp: start,
      label: _bucketLabel(start, bucket),
      kwh: 0,
      costBhd: 0,
      powerW: 0,
    );
  }

  return EnergyHistoryPoint(
    timestamp: start,
    label: _bucketLabel(start, bucket),
    kwh: points.fold<double>(0, (sum, point) => sum + point.kwh),
    costBhd: points.fold<double>(0, (sum, point) => sum + point.costBhd),
    powerW: points.fold<double>(
      0,
      (max, point) => point.powerW > max ? point.powerW : max,
    ),
  );
}

DateTime _addMonths(DateTime value, int months) {
  return DateTime(value.year, value.month + months);
}

String _bucketLabel(DateTime start, _ChartBucket bucket) {
  return switch (bucket) {
    _ChartBucket.raw => DateFormat('HH:mm').format(start),
    _ChartBucket.hour => DateFormat('HH:mm').format(start),
    _ChartBucket.day => DateFormat('yyyy-MM-dd').format(start),
    _ChartBucket.month => DateFormat('yyyy-MM').format(start),
  };
}

String _breakerDisplayName(BreakerContribution item) {
  if (item.breakerId == 'breaker_01') {
    return 'AC breaker';
  }
  if (item.breakerId == 'breaker_02') {
    return 'Socket breaker';
  }
  final name = item.name.trim();
  if (name.isNotEmpty && !name.toLowerCase().startsWith('breaker_')) {
    return name;
  }
  final branch = item.branch.trim();
  if (branch.isNotEmpty && branch.toLowerCase() != 'breaker') {
    return '$branch breaker';
  }
  return item.breakerId;
}

String _breakerBranchLabel(BreakerContribution item) {
  if (item.breakerId == 'breaker_01') {
    return 'AC';
  }
  if (item.breakerId == 'breaker_02') {
    return 'Socket';
  }
  return item.branch;
}

String _hourRange(EnergyHistoryPoint item) {
  final start = item.timestamp.toLocal();
  final end = start.add(const Duration(hours: 1));
  final format = DateFormat('HH:mm');
  return '${format.format(start)} - ${format.format(end)}';
}

String _formatPowerValue(double watts) {
  if (watts >= 1000) {
    return '${(watts / 1000).toStringAsFixed(2)} kW';
  }
  return '${watts.toStringAsFixed(0)} W';
}

String _formatEnergyValue(double kwh) {
  if (kwh > 0 && kwh < 0.1) {
    return '${kwh.toStringAsFixed(3)} kWh';
  }
  if (kwh < 10) {
    return '${kwh.toStringAsFixed(2)} kWh';
  }
  return '${kwh.toStringAsFixed(1)} kWh';
}

String _formatCostValue(double bhd) {
  if (bhd > 0 && bhd < 0.01) {
    return '${bhd.toStringAsFixed(4)} BHD';
  }
  return '${bhd.toStringAsFixed(3)} BHD';
}

String _axisLabel(
  EnergyHistoryPoint point,
  _ChartLabelType type,
  List<EnergyHistoryPoint> points,
) {
  final local = point.timestamp.toLocal();
  final first = points.first.timestamp.toLocal();
  final last = points.last.timestamp.toLocal();
  final span = last.difference(first).abs();
  return switch (type) {
    _ChartLabelType.time =>
      span.inHours >= 48
          ? DateFormat('E').format(local)
          : DateFormat('HH:mm').format(local),
    _ChartLabelType.day => DateFormat('MMM d').format(local),
    _ChartLabelType.month => DateFormat('MMM').format(local),
  };
}

double _niceInterval(int length) {
  if (length <= 4) {
    return 1;
  }
  return (length / 4).ceilToDouble();
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorTokens.border),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        AppShimmer(height: 90),
        SizedBox(height: 16),
        AppShimmer(height: 220),
        SizedBox(height: 16),
        AppShimmer(height: 220),
      ],
    );
  }
}

LineChartData _chartData(
  List<EnergyHistoryPoint> points,
  Color color,
  double Function(EnergyHistoryPoint point) value,
  _ChartLabelType labelType,
  String Function(double value) valueFormatter,
) {
  final spots = <FlSpot>[
    for (var index = 0; index < points.length; index++)
      FlSpot(
        index.toDouble(),
        value(points[index]).clamp(0, double.infinity).toDouble(),
      ),
  ];
  final maxY = spots.fold<double>(
    0,
    (max, spot) => spot.y > max ? spot.y : max,
  );
  final interval = _niceInterval(points.length);
  return LineChartData(
    minY: 0,
    maxY: maxY <= 0 ? 1 : maxY * 1.2,
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY <= 0 ? 1 : maxY / 4,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: ColorTokens.border, strokeWidth: 1),
    ),
    borderData: FlBorderData(
      show: true,
      border: Border(
        left: BorderSide(color: ColorTokens.border),
        bottom: BorderSide(color: ColorTokens.border),
      ),
    ),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 48,
          interval: maxY <= 0 ? 1 : maxY / 4,
          getTitlesWidget: (value, meta) {
            if (value <= 0) {
              return const SizedBox.shrink();
            }
            return Text(
              valueFormatter(value),
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: interval,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= points.length) {
              return const SizedBox.shrink();
            }
            if (index != 0 &&
                index != points.length - 1 &&
                index % interval.round() != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _axisLabel(points[index], labelType, points),
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            );
          },
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.12),
        ),
      ),
    ],
  );
}

EnergyHistoryData _demoEnergyHistoryData(DashboardData dashboard) {
  final now = dashboard.reading.timestamp;
  final tariff = dashboard.tariffBhdPerKwh <= 0
      ? 0.032
      : dashboard.tariffBhdPerKwh;
  final basePower = _demoHistoryNumber(
    dashboard.settingsSummary,
    'recent_power_avg',
    fallback: dashboard.reading.power * 0.45,
  );
  final baseHourlyKwh = _demoHistoryNumber(
    dashboard.settingsSummary,
    'same_hour_energy_avg',
    fallback: basePower / 1000,
  );
  final currentHourlyKwh = dashboard.reading.power > 0
      ? dashboard.reading.power / 1000
      : dashboard.reading.energyToday / 8;

  final hourly = <EnergyHistoryPoint>[
    for (var index = 23; index >= 0; index--)
      EnergyHistoryPoint(
        timestamp: now.subtract(Duration(hours: index)),
        label: DateFormat('HH:mm').format(now.subtract(Duration(hours: index))),
        kwh: index == 0 ? currentHourlyKwh : baseHourlyKwh * _demoWave(index),
        costBhd:
            (index == 0 ? currentHourlyKwh : baseHourlyKwh * _demoWave(index)) *
            tariff,
        powerW: index == 0
            ? dashboard.reading.power
            : basePower * _demoWave(index),
      ),
  ];

  final daily = <EnergyHistoryPoint>[
    for (var index = 29; index >= 0; index--)
      EnergyHistoryPoint(
        timestamp: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: index)),
        label: DateFormat('yyyy-MM-dd').format(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: index)),
        ),
        kwh: index == 0
            ? dashboard.reading.energyToday
            : (dashboard.reading.energyToday * 0.72) * _demoWave(index),
        costBhd: index == 0
            ? dashboard.reading.costToday
            : (dashboard.reading.energyToday * 0.72) *
                  _demoWave(index) *
                  tariff,
        powerW: 0,
      ),
  ];

  final monthly = <EnergyHistoryPoint>[
    for (var index = 5; index >= 0; index--)
      EnergyHistoryPoint(
        timestamp: DateTime(now.year, now.month - index),
        label: DateFormat(
          'yyyy-MM',
        ).format(DateTime(now.year, now.month - index)),
        kwh: index == 0
            ? dashboard.reading.energyMonth
            : dashboard.reading.energyMonth * (0.78 + (5 - index) * 0.035),
        costBhd: index == 0
            ? dashboard.reading.costMonth
            : dashboard.reading.energyMonth *
                  (0.78 + (5 - index) * 0.035) *
                  tariff,
        powerW: 0,
      ),
  ];

  final breakerEnergy = dashboard.devices.fold<double>(
    0,
    (sum, device) => sum + device.energyToday,
  );
  final contributions =
      dashboard.devices
          .where((device) => device.energyToday > 0 || device.currentPower > 0)
          .map((device) {
            final energy = device.energyToday > 0
                ? device.energyToday
                : device.currentPower / 1000;
            final total = breakerEnergy > 0
                ? breakerEnergy
                : dashboard.reading.energyToday;
            return BreakerContribution(
              breakerId: device.id,
              name: device.name,
              branch: device.branch,
              energyKwh: energy,
              costBhd: energy * tariff,
              percentage: total > 0 ? (energy / total) * 100 : 0,
            );
          })
          .toList()
        ..sort((a, b) => b.energyKwh.compareTo(a.energyKwh));

  final profile = HomeLearningProfile(
    status: 'demo_ready',
    adaptiveReadiness: 0.86,
    averageDailyKwh: dashboard.reading.energyToday * 0.78,
    averageDailyCostBhd: dashboard.reading.energyToday * 0.78 * tariff,
    expectedMonthlyKwh: dashboard.reading.energyToday * 0.78 * 30,
    expectedMonthlyCostBhd: dashboard.reading.energyToday * 0.78 * 30 * tariff,
    hourlySummaryCount: 72,
    dailySummaryCount: 30,
    trainedAt: now,
    profileVersion: 'demo_profile_${dashboard.scenarioId}',
  );

  return EnergyHistoryData(
    powerHistory: hourly
        .skip(hourly.length > 12 ? hourly.length - 12 : 0)
        .toList(),
    hourlyUsage: hourly,
    dailyEnergy: daily,
    monthlyEnergy: monthly,
    costHistory: daily,
    breakerContribution: contributions,
    peakUsageHours: [...hourly]..sort((a, b) => b.kwh.compareTo(a.kwh)),
    homeLearningProfile: profile,
  );
}

double _demoHistoryNumber(
  Map<String, dynamic> settings,
  String key, {
  required double fallback,
}) {
  final history = settings['recent_history'];
  if (history is Map) {
    final value = history[key];
    if (value is num) {
      return value.toDouble();
    }
  }
  return fallback;
}

double _demoWave(int index) {
  return 0.82 + ((index % 5) * 0.07);
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: ColorTokens.surfaceElevated,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ColorTokens.border),
    boxShadow: const [BoxShadow(color: ColorTokens.shadow, blurRadius: 16)],
  );
}
