import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/app_state_widgets.dart';
import '../../../shared/services/kahrabaiq_api_service.dart';

class EnergyBudgetScreen extends StatefulWidget {
  const EnergyBudgetScreen({super.key, required this.homeId});

  final String homeId;

  @override
  State<EnergyBudgetScreen> createState() => _EnergyBudgetScreenState();
}

class _EnergyBudgetScreenState extends State<EnergyBudgetScreen> {
  final KahrabaIqApiService _api = KahrabaIqApiService();
  late Future<EnergyBudgetData> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchEnergyBudget(homeId: widget.homeId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchEnergyBudget(homeId: widget.homeId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Energy Budget')),
      body: RefreshIndicator(
        color: ColorTokens.primary,
        onRefresh: _reload,
        child: FutureBuilder<EnergyBudgetData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _BudgetLoading();
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
                icon: Icons.account_balance_wallet_outlined,
                title: 'No budget data',
                message: 'Budget progress will appear after summaries sync.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text('Energy Budget Progress', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Track monthly cost and keep daily usage under control.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 18),
                if (data.monthlyBudgetBhd <= 0)
                  const _Notice(
                    message:
                        'No monthly budget set. Add a cost limit in Home Settings to track progress.',
                  )
                else if (!data.monthDataAvailable)
                  const _Notice(message: 'Waiting for cloud summaries.'),
                _OverviewCard(data: data),
                const SizedBox(height: 16),
                _PredictionCard(data: data),
                const SizedBox(height: 16),
                _ProgressChart(data: data),
                const SizedBox(height: 16),
                _DailyComparison(data: data),
                const SizedBox(height: 16),
                _Recommendations(data: data),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final EnergyBudgetData data;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(data.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_statusLabel(data.status), style: AppTextStyles.h2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${data.currentMonthCostBhd.toStringAsFixed(3)} / ${data.monthlyBudgetBhd.toStringAsFixed(3)} BHD',
            style: AppTextStyles.mono.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (data.percentageUsed / 100).clamp(0, 1),
            color: color,
            backgroundColor: ColorTokens.border,
            minHeight: 8,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniMetric('Used', '${data.percentageUsed.toStringAsFixed(0)}%'),
              _MiniMetric(
                'Remaining',
                '${data.remainingBudgetBhd.toStringAsFixed(3)} BHD',
              ),
              _MiniMetric('Days left', '${data.daysRemaining}'),
              _MiniMetric(
                'Avg/day',
                '${data.averageDailyCostBhd.toStringAsFixed(3)} BHD',
              ),
              _MiniMetric(
                'Daily target',
                '${data.recommendedDailyLimitBhd.toStringAsFixed(3)} BHD',
              ),
              _MiniMetric(
                'Energy',
                '${data.currentMonthEnergyKwh.toStringAsFixed(2)} kWh',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.data});

  final EnergyBudgetData data;

  @override
  Widget build(BuildContext context) {
    final over = data.predictedDifferenceBhd > 0;
    final difference = data.predictedDifferenceBhd.abs();
    final message = data.monthlyBudgetBhd <= 0
        ? 'Set a monthly cost limit to enable end-of-month prediction.'
        : over
        ? 'Expected to exceed budget by ${difference.toStringAsFixed(3)} BHD.'
        : 'Expected to stay under budget by ${difference.toStringAsFixed(3)} BHD.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        over ? ColorTokens.warning : ColorTokens.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('End-of-Month Prediction', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          Text(
            '${data.predictedMonthlyCostBhd.toStringAsFixed(3)} BHD',
            style: AppTextStyles.mono.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.data});

  final EnergyBudgetData data;

  @override
  Widget build(BuildContext context) {
    final points = data.dailyProgress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cost Accumulation', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const _EmptyInline(message: 'Waiting for cloud summaries.')
          else
            SizedBox(height: 190, child: LineChart(_budgetChart(points))),
        ],
      ),
    );
  }
}

class _DailyComparison extends StatelessWidget {
  const _DailyComparison({required this.data});

  final EnergyBudgetData data;

  @override
  Widget build(BuildContext context) {
    final points = data.dailyProgress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.info),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Budget Comparison', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const _EmptyInline(message: 'No daily cost summaries yet.')
          else
            ...points
                .take(10)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Text(
                          '${item.actualCostBhd.toStringAsFixed(3)} / ${item.recommendedCostBhd.toStringAsFixed(3)}',
                          style: AppTextStyles.mono.copyWith(
                            color: item.overRecommended
                                ? ColorTokens.warning
                                : ColorTokens.success,
                          ),
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

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.data});

  final EnergyBudgetData data;

  @override
  Widget build(BuildContext context) {
    final topBreaker = data.breakerContribution.isEmpty
        ? null
        : data.breakerContribution.first;
    final recommendations = <String>[
      if (data.monthlyBudgetBhd <= 0)
        'Add a monthly cost limit in Home Settings to activate budget tracking.'
      else if (data.status == 'over_budget')
        'Reduce high-power devices now to bring the monthly cost back under control.'
      else if (data.status == 'near_limit')
        'Keep daily cost below ${data.recommendedDailyLimitBhd.toStringAsFixed(3)} BHD to stay within budget.'
      else
        'Current usage is on track. Keep monitoring high-power periods.',
      if (topBreaker != null)
        '${topBreaker.name} is using the largest share of measured breaker energy.',
      if (data.predictedDifferenceBhd > 0)
        'Expected monthly cost is above budget. Review evening AC and socket usage.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(ColorTokens.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommendations', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          ...recommendations.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: ColorTokens.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.caption.copyWith(
                        color: ColorTokens.textPrimary,
                      ),
                    ),
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorTokens.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(color: ColorTokens.textPrimary),
      ),
    );
  }
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

class _BudgetLoading extends StatelessWidget {
  const _BudgetLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        AppShimmer(height: 160),
        SizedBox(height: 16),
        AppShimmer(height: 220),
        SizedBox(height: 16),
        AppShimmer(height: 180),
      ],
    );
  }
}

LineChartData _budgetChart(List<DailyBudgetProgress> points) {
  var running = 0.0;
  final spots = <FlSpot>[
    for (var index = 0; index < points.length; index++)
      FlSpot(index.toDouble(), running += points[index].actualCostBhd),
  ];
  final maxY = spots.fold<double>(
    0,
    (max, spot) => spot.y > max ? spot.y : max,
  );
  return LineChartData(
    minY: 0,
    maxY: maxY <= 0 ? 1 : maxY * 1.2,
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    titlesData: const FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: ColorTokens.primary,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: ColorTokens.primary.withValues(alpha: 0.12),
        ),
      ),
    ],
  );
}

BoxDecoration _cardDecoration(Color color) {
  return BoxDecoration(
    color: ColorTokens.surfaceElevated,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: color.withValues(alpha: 0.3)),
    boxShadow: const [BoxShadow(color: ColorTokens.shadow, blurRadius: 16)],
  );
}

Color _statusColor(String status) {
  if (status == 'over_budget') return ColorTokens.danger;
  if (status == 'near_limit') return ColorTokens.warning;
  if (status == 'no_budget') return ColorTokens.textMuted;
  return ColorTokens.success;
}

String _statusLabel(String status) {
  if (status == 'over_budget') return 'Over budget';
  if (status == 'near_limit') return 'Near limit';
  if (status == 'no_budget') return 'No budget set';
  return 'On track';
}
