import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_tokens.dart';

class AiImpactShowcaseScreen extends StatelessWidget {
  const AiImpactShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Impact Showcase')),
      body: FutureBuilder<_ImpactDataset>(
        future: _loadImpactDataset(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _DatasetError(message: snapshot.error?.toString());
          }
          return _ImpactShowcaseContent(dataset: snapshot.data!);
        },
      ),
    );
  }
}

class _ImpactShowcaseContent extends StatelessWidget {
  const _ImpactShowcaseContent({required this.dataset});

  final _ImpactDataset dataset;

  @override
  Widget build(BuildContext context) {
    final rows = dataset.rows;
    final totals = _ImpactTotals.fromRows(rows);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Energy Reduction Simulation', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        _ScenarioLabel(label: dataset.scenarioLabel),
        const SizedBox(height: 8),
        Text(dataset.homeProfile, style: AppTextStyles.caption),
        const SizedBox(height: 18),
        _HeroSavingsCard(totals: totals),
        const SizedBox(height: 16),
        _ComparisonGrid(totals: totals),
        const SizedBox(height: 16),
        _LineComparisonCard(
          title: 'Daily Energy Usage',
          unit: 'kWh',
          rows: rows,
          baseline: (row) => row.baselineKwh,
          assisted: (row) => row.assistedKwh,
          valueFormatter: (value) => '${value.toStringAsFixed(1)} kWh',
          color: ColorTokens.primary,
        ),
        const SizedBox(height: 16),
        _CumulativeSavingsCard(
          title: 'Cumulative cost savings',
          unit: 'BHD',
          rows: rows,
          valueFormatter: (value) => '${value.toStringAsFixed(3)} BHD',
          totals: totals,
        ),
        const SizedBox(height: 16),
        _ActionImpactCard(dataset: dataset, totals: totals),
        const SizedBox(height: 16),
        _AssumptionsCard(dataset: dataset),
      ],
    );
  }
}

class _DatasetError extends StatelessWidget {
  const _DatasetError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message ?? 'Could not load the AI impact dataset.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ScenarioLabel extends StatelessWidget {
  const _ScenarioLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ColorTokens.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ColorTokens.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(color: ColorTokens.primary),
        ),
      ),
    );
  }
}

class _HeroSavingsCard extends StatelessWidget {
  const _HeroSavingsCard({required this.totals});

  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(ColorTokens.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorTokens.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: ColorTokens.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Estimated KahrabaIQ Savings',
                  style: AppTextStyles.h2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${totals.savedKwh.toStringAsFixed(1)} kWh',
            style: AppTextStyles.mono.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 6),
          Text(
            '${totals.savedBhd.toStringAsFixed(3)} BHD saved · ${totals.reductionPercent.toStringAsFixed(0)}% lower energy use',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'This simulation demonstrates the expected impact when residents follow KahrabaIQ recommendations for unnecessary AC operation, devices left on, and inefficient usage routines.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ComparisonGrid extends StatelessWidget {
  const _ComparisonGrid({required this.totals});

  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTile(
        label: 'Without KahrabaIQ',
        value: '${totals.baselineKwh.toStringAsFixed(1)} kWh',
        subvalue: '${totals.baselineCostBhd.toStringAsFixed(3)} BHD',
        color: ColorTokens.warning,
      ),
      _MetricTile(
        label: 'Recommendations followed',
        value: '${totals.assistedKwh.toStringAsFixed(1)} kWh',
        subvalue: '${totals.assistedCostBhd.toStringAsFixed(3)} BHD',
        color: ColorTokens.success,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                SizedBox(width: double.infinity, child: tiles[index]),
                if (index != tiles.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.subvalue,
    required this.color,
  });

  final String label;
  final String value;
  final String subvalue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppTextStyles.bodyMedium),
            ),
            const SizedBox(height: 4),
            Text(subvalue, style: AppTextStyles.caption, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _LineComparisonCard extends StatelessWidget {
  const _LineComparisonCard({
    required this.title,
    required this.unit,
    required this.rows,
    required this.baseline,
    required this.assisted,
    required this.valueFormatter,
    required this.color,
  });

  final String title;
  final String unit;
  final List<_ImpactDay> rows;
  final double Function(_ImpactDay row) baseline;
  final double Function(_ImpactDay row) assisted;
  final String Function(double value) valueFormatter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final baselineTotal = rows.fold<double>(
      0,
      (sum, row) => sum + baseline(row),
    );
    final assistedTotal = rows.fold<double>(
      0,
      (sum, row) => sum + assisted(row),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          _Legend(unit: unit),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: LineChart(
              _comparisonChart(
                rows: rows,
                baseline: baseline,
                assisted: assisted,
                valueFormatter: valueFormatter,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SmallPill('Baseline total', valueFormatter(baselineTotal)),
              _SmallPill('Optimized total', valueFormatter(assistedTotal)),
              _SmallPill(
                'Energy saved',
                valueFormatter(baselineTotal - assistedTotal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CumulativeSavingsCard extends StatelessWidget {
  const _CumulativeSavingsCard({
    required this.title,
    required this.unit,
    required this.rows,
    required this.valueFormatter,
    required this.totals,
  });

  final String title;
  final String unit;
  final List<_ImpactDay> rows;
  final String Function(double value) valueFormatter;
  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Row(
            children: [
              _LegendItem(
                color: ColorTokens.success,
                label: 'Cumulative savings',
              ),
              const Spacer(),
              Text(unit, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: LineChart(
              _cumulativeSavingsChart(
                rows: rows,
                valueFormatter: valueFormatter,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SmallPill(
                'Monthly cost without KahrabaIQ',
                valueFormatter(totals.baselineCostBhd),
              ),
              _SmallPill(
                'Monthly cost after recommendations',
                valueFormatter(totals.assistedCostBhd),
              ),
              _SmallPill(
                'Estimated monthly savings',
                valueFormatter(totals.savedBhd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: ColorTokens.warning, label: 'Without KahrabaIQ'),
        const SizedBox(width: 14),
        _LegendItem(
          color: ColorTokens.success,
          label: 'Recommendations followed',
        ),
        const Spacer(),
        Text(unit, style: AppTextStyles.caption),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
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

class _ActionImpactCard extends StatelessWidget {
  const _ActionImpactCard({required this.dataset, required this.totals});

  final _ImpactDataset dataset;
  final _ImpactTotals totals;

  @override
  Widget build(BuildContext context) {
    final categoryTotal = dataset.savingsCategories.fold<double>(
      0,
      (sum, item) => sum + item.savedKwh,
    );
    final valid = (categoryTotal - totals.savedKwh).abs() < 0.001;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where Savings Come From', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          ...dataset.savingsCategories.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorTokens.border),
              ),
              child: Row(
                children: [
                  Icon(_categoryIcon(item.title), color: ColorTokens.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 4),
                        Text(item.detail, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.savedKwh.toStringAsFixed(1)} kWh',
                    style: AppTextStyles.mono,
                  ),
                ],
              ),
            ),
          ),
          if (!valid)
            Text(
              'Savings category total does not match displayed total.',
              style: AppTextStyles.caption.copyWith(color: ColorTokens.danger),
            ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String title) {
  final value = title.toLowerCase();
  if (value.contains('socket')) return Icons.power_outlined;
  if (value.contains('temperature') || value.contains('cooling')) {
    return Icons.thermostat_outlined;
  }
  if (value.contains('routine')) return Icons.schedule_outlined;
  return Icons.ac_unit;
}

class _AssumptionsCard extends StatelessWidget {
  const _AssumptionsCard({required this.dataset});

  final _ImpactDataset dataset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simulation Assumptions', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          ...dataset.assumptions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: ColorTokens.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: AppTextStyles.caption)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dataset.notes.join(' '),
            style: AppTextStyles.caption.copyWith(
              color: ColorTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${dataset.baselineMonth}. ${dataset.assistedMonth}. Tariff: ${dataset.tariffBhdPerKwh.toStringAsFixed(3)} BHD/kWh.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

LineChartData _comparisonChart({
  required List<_ImpactDay> rows,
  required double Function(_ImpactDay row) baseline,
  required double Function(_ImpactDay row) assisted,
  required String Function(double value) valueFormatter,
}) {
  final baselineSpots = <FlSpot>[
    for (var index = 0; index < rows.length; index++)
      FlSpot(index.toDouble(), baseline(rows[index])),
  ];
  final assistedSpots = <FlSpot>[
    for (var index = 0; index < rows.length; index++)
      FlSpot(index.toDouble(), assisted(rows[index])),
  ];
  final maxY = [
    ...baselineSpots,
    ...assistedSpots,
  ].fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);
  final yInterval = maxY <= 0 ? 1.0 : maxY / 4;
  return LineChartData(
    minY: 0,
    maxY: maxY <= 0 ? 1 : maxY * 1.16,
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: yInterval,
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
          reservedSize: 52,
          interval: yInterval,
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
          reservedSize: 28,
          interval: 7,
          getTitlesWidget: (value, meta) {
            final day = value.round() + 1;
            if (day != 1 &&
                day != 5 &&
                day != 10 &&
                day != 15 &&
                day != 20 &&
                day != 25 &&
                day != 30) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'D$day',
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            );
          },
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: baselineSpots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: ColorTokens.warning,
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: assistedSpots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: ColorTokens.success,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: ColorTokens.success.withValues(alpha: 0.10),
        ),
      ),
    ],
  );
}

LineChartData _cumulativeSavingsChart({
  required List<_ImpactDay> rows,
  required String Function(double value) valueFormatter,
}) {
  var running = 0.0;
  final spots = <FlSpot>[
    for (var index = 0; index < rows.length; index++)
      FlSpot(
        index.toDouble(),
        running += rows[index].baselineCostBhd - rows[index].assistedCostBhd,
      ),
  ];
  final maxY = spots.fold<double>(
    0,
    (max, spot) => spot.y > max ? spot.y : max,
  );
  final yInterval = maxY <= 0 ? 1.0 : maxY / 4;
  return LineChartData(
    minY: 0,
    maxY: maxY <= 0 ? 1 : maxY * 1.16,
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: yInterval,
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
          reservedSize: 58,
          interval: yInterval,
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
          reservedSize: 28,
          interval: 5,
          getTitlesWidget: (value, meta) {
            final day = value.round() + 1;
            if (day != 1 &&
                day != 5 &&
                day != 10 &&
                day != 15 &&
                day != 20 &&
                day != 25 &&
                day != 30) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'D$day',
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
        color: ColorTokens.success,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: ColorTokens.success.withValues(alpha: 0.12),
        ),
      ),
    ],
  );
}

class _ImpactDay {
  const _ImpactDay({
    required this.day,
    required this.baselineKwh,
    required this.assistedKwh,
    required this.tariffBhdPerKwh,
  });

  final int day;
  final double baselineKwh;
  final double assistedKwh;
  final double tariffBhdPerKwh;

  double get baselineCostBhd => baselineKwh * tariffBhdPerKwh;
  double get assistedCostBhd => assistedKwh * tariffBhdPerKwh;
}

class _ImpactTotals {
  const _ImpactTotals({
    required this.baselineKwh,
    required this.assistedKwh,
    required this.baselineCostBhd,
    required this.assistedCostBhd,
  });

  factory _ImpactTotals.fromRows(List<_ImpactDay> rows) {
    final baseline = rows.fold<double>(0, (sum, row) => sum + row.baselineKwh);
    final assisted = rows.fold<double>(0, (sum, row) => sum + row.assistedKwh);
    return _ImpactTotals(
      baselineKwh: baseline,
      assistedKwh: assisted,
      baselineCostBhd: rows.fold<double>(
        0,
        (sum, row) => sum + row.baselineCostBhd,
      ),
      assistedCostBhd: rows.fold<double>(
        0,
        (sum, row) => sum + row.assistedCostBhd,
      ),
    );
  }

  final double baselineKwh;
  final double assistedKwh;
  final double baselineCostBhd;
  final double assistedCostBhd;

  double get savedKwh => baselineKwh - assistedKwh;
  double get savedBhd => baselineCostBhd - assistedCostBhd;
  double get reductionPercent =>
      baselineKwh <= 0 ? 0 : (savedKwh / baselineKwh) * 100;
}

class _ImpactDataset {
  const _ImpactDataset({
    required this.datasetId,
    required this.scenarioLabel,
    required this.homeProfile,
    required this.tariffBhdPerKwh,
    required this.baselineMonth,
    required this.assistedMonth,
    required this.notes,
    required this.assumptions,
    required this.savingsCategories,
    required this.rows,
  });

  final String datasetId;
  final String scenarioLabel;
  final String homeProfile;
  final double tariffBhdPerKwh;
  final String baselineMonth;
  final String assistedMonth;
  final List<String> notes;
  final List<String> assumptions;
  final List<_SavingCategory> savingsCategories;
  final List<_ImpactDay> rows;
}

class _SavingCategory {
  const _SavingCategory({
    required this.title,
    required this.detail,
    required this.savedKwh,
  });

  final String title;
  final String detail;
  final double savedKwh;
}

Future<_ImpactDataset> _loadImpactDataset() async {
  final raw = await rootBundle.loadString(
    'assets/demo/ai_impact_monthly_dataset.json',
  );
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final tariff = _jsonDouble(data['tariff_bhd_per_kwh'], fallback: 0.032);
  final savingsCategories = (data['savings_categories'] as List? ?? const [])
      .whereType<Map>()
      .map(
        (item) => _SavingCategory(
          title: _jsonString(item['title']),
          detail: _jsonString(item['detail']),
          savedKwh: _jsonDouble(item['saved_kwh']),
        ),
      )
      .toList(growable: false);
  final days =
      (data['days'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => _ImpactDay(
              day: _jsonInt(item['day']),
              baselineKwh: _jsonDouble(item['baseline_kwh']),
              assistedKwh: _jsonDouble(item['assisted_kwh']),
              tariffBhdPerKwh: tariff,
            ),
          )
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
  final totals = _ImpactTotals.fromRows(days);
  final categoryTotal = savingsCategories.fold<double>(
    0,
    (sum, category) => sum + category.savedKwh,
  );
  if (days.length != 30) {
    throw const FormatException(
      'AI impact dataset must contain exactly 30 daily records.',
    );
  }
  if ((totals.baselineKwh - 600.0).abs() > 0.001 ||
      (totals.assistedKwh - 480.0).abs() > 0.001 ||
      (totals.savedKwh - 120.0).abs() > 0.001) {
    throw FormatException(
      'AI impact dataset totals are inconsistent: baseline ${totals.baselineKwh}, optimized ${totals.assistedKwh}, saved ${totals.savedKwh}.',
    );
  }
  if ((categoryTotal - totals.savedKwh).abs() > 0.001) {
    throw FormatException(
      'AI impact savings categories total $categoryTotal kWh but the displayed savings total is ${totals.savedKwh} kWh.',
    );
  }
  return _ImpactDataset(
    datasetId: _jsonString(data['dataset_id']),
    scenarioLabel: _jsonString(data['scenario_label']),
    homeProfile: _jsonString(data['home_profile']),
    tariffBhdPerKwh: tariff,
    baselineMonth: _jsonString(data['baseline_month']),
    assistedMonth: _jsonString(data['assisted_month']),
    notes: (data['notes'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    assumptions: (data['assumptions'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    savingsCategories: savingsCategories,
    rows: days,
  );
}

String _jsonString(Object? value) {
  return value?.toString() ?? '';
}

int _jsonInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _jsonDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

BoxDecoration _cardDecoration(Color color) {
  return BoxDecoration(
    color: ColorTokens.surfaceElevated,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: color.withValues(alpha: 0.3)),
    boxShadow: const [BoxShadow(color: ColorTokens.shadow, blurRadius: 16)],
  );
}
