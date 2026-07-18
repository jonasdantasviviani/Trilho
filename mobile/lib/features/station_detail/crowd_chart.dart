import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/models/crowd_model.dart';

class CrowdChart extends StatelessWidget {
  final List<CrowdHistoryPoint> history;
  const CrowdChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    // Oldest first on x-axis
    final points = history.reversed.toList();
    final spots  = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value.density * 100).clamp(0, 100));
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) =>
                  Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
