import 'package:flutter/material.dart';

import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../shared/models/device.dart';
import '../../../shared/models/energy_reading.dart';

/// Three-card row for live breaker and energy KPIs.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({
    super.key,
    required this.reading,
    required this.devices,
    required this.settingsSummary,
    this.onBreakersTap,
    this.onBudgetTap,
  });

  final EnergyReading reading;
  final List<Device> devices;
  final Map<String, dynamic> settingsSummary;
  final VoidCallback? onBreakersTap;
  final VoidCallback? onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final breakerDevices = devices
        .where((device) => device.id.startsWith('breaker_'))
        .toList();
    final activeBreakers = breakerDevices.where((device) => device.isOn).length;
    final totalBreakers = breakerDevices.length;
    final breakerEnergy = breakerDevices.fold<double>(
      0,
      (sum, device) => sum + device.energyToday,
    );
    final energyMonth = reading.energyMonth > 0
        ? reading.energyMonth
        : breakerEnergy > 0
        ? breakerEnergy
        : reading.energyToday;
    final energyDisplay = _energyDisplay(energyMonth);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onBreakersTap,
            borderRadius: BorderRadius.circular(16),
            child: MetricCard(
              title: 'Breakers',
              value: '$activeBreakers/$totalBreakers',
              unit: 'on',
              icon: Icons.electrical_services,
              color: ColorTokens.primary,
              trendLabel: totalBreakers > 0 ? 'details' : 'waiting',
              isTrendPositive: totalBreakers > 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BudgetProgressCard(
            reading: reading,
            settingsSummary: settingsSummary,
            onTap: onBudgetTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            title: 'Energy',
            value: reading.monthDataAvailable ? energyDisplay.value : '--',
            unit: reading.monthDataAvailable ? energyDisplay.unit : '',
            icon: Icons.speed,
            color: ColorTokens.success,
            trendLabel: reading.monthDataAvailable ? 'month' : 'no data',
          ),
        ),
      ],
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.reading,
    required this.settingsSummary,
    required this.onTap,
  });

  final EnergyReading reading;
  final Map<String, dynamic> settingsSummary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final limit = _settingsNumber(settingsSummary, 'monthly_cost_limit_bhd');
    final current = reading.costMonth;
    final percent = limit > 0 ? (current / limit) * 100 : 0.0;
    final status = limit <= 0
        ? 'no budget'
        : current > limit
        ? 'over budget'
        : percent >=
              _settingsNumber(
                settingsSummary,
                'high_usage_warning_percent',
                fallback: 80,
              )
        ? 'near limit'
        : 'on track';
    final color = status == 'over budget'
        ? ColorTokens.danger
        : status == 'near limit'
        ? ColorTokens.warning
        : status == 'no budget'
        ? ColorTokens.textMuted
        : ColorTokens.success;

    return MetricCard(
      title: 'Budget',
      value: limit > 0
          ? '${current.toStringAsFixed(1)}/${limit.toStringAsFixed(0)}'
          : '--',
      unit: limit > 0 ? 'BHD' : '',
      icon: Icons.account_balance_wallet_outlined,
      color: color,
      trendLabel: limit > 0
          ? '${percent.toStringAsFixed(0)}% $status'
          : 'set limit',
      isTrendPositive: status != 'over budget',
      onTap: onTap,
      footer: LinearProgressIndicator(
        value: limit > 0 ? (percent / 100).clamp(0, 1) : 0,
        color: color,
        backgroundColor: ColorTokens.border,
        minHeight: 4,
      ),
    );
  }
}

({String value, String unit}) _energyDisplay(double kwh) {
  if (kwh > 0 && kwh < 1) {
    return (value: (kwh * 1000).toStringAsFixed(0), unit: 'Wh');
  }
  return (value: kwh.toStringAsFixed(1), unit: 'kWh');
}

double _settingsNumber(
  Map<String, dynamic> values,
  String key, {
  double fallback = 0,
}) {
  final value = values[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
