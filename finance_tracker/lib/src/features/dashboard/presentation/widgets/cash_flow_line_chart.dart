import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/dashboard_summary.dart';

class CashFlowLineChart extends StatelessWidget {
  const CashFlowLineChart({super.key, required this.data});

  final List<DailyCashFlow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Belum ada data cash flow')),
      );
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), data[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), data[i].expense));
    }

    final maxY = [
      ...incomeSpots,
      ...expenseSpots,
    ].map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    final bottomLabels = <int, String>{};
    for (var i = 0; i < data.length; i++) {
      final day = data[i].date.length >= 10
          ? data[i].date.substring(8, 10)
          : data[i].date;
      if (i == 0 || i == data.length - 1 || i % 5 == 0) {
        bottomLabels[i] = day;
      }
    }

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 24, top: 16, bottom: 4),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final label = bottomLabels[value.toInt()];
                    if (label == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
