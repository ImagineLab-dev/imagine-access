import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/ui/glass_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dashboard_repository.dart';

class StatsScreen extends ConsumerWidget {
  final String eventId;

  const StatsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(eventStatsProvider(eventId));

    return GlassScaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
        centerTitle: true,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (stats) {
          final attendance = stats['attendance_by_hour'] as List? ?? [];
          final rrpp = stats['rrpp_performance'] as List? ?? [];
          final sales = stats['sales_timeline'] as List? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(l10n.enteringPerHour, theme),
                const SizedBox(height: 16),
                _buildAttendanceChart(attendance, theme, isDark),
                
                const SizedBox(height: 32),
                _buildSectionTitle(l10n.rrppPerformance, theme),
                const SizedBox(height: 16),
                _buildRrppChart(rrpp, theme, isDark),
                
                const SizedBox(height: 32),
                _buildSectionTitle(l10n.salesTrend, theme),
                const SizedBox(height: 16),
                _buildSalesChart(sales, theme, isDark),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAttendanceChart(List data, ThemeData theme, bool isDark) {
    return GlassCard(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMax(data, 'count') * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[value.toInt()]['hour'].split(':')[0],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: (e.value['count'] as num).toDouble(),
                  color: AppTheme.accentBlue,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRrppChart(List data, ThemeData theme, bool isDark) {
    // Group by name for the chart
    final Map<String, double> perf = {};
    for (var item in data) {
      final name = item['name'] as String;
      perf[name] = (perf[name] ?? 0) + (item['count'] as num).toDouble();
    }

    final sortedItems = perf.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    return GlassCard(
      height: 300,
      padding: const EdgeInsets.all(20),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: sortedItems.take(5).map((e) {
            final color = _getColor(sortedItems.indexOf(e));
            return PieChartSectionData(
              color: color,
              value: e.value,
              title: "${e.value.toInt()}",
              radius: 50,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              badgeWidget: _Badge(e.key, color: color),
              badgePositionPercentageOffset: 1.3,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSalesChart(List data, ThemeData theme, bool isDark) {
    return GlassCard(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 8),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox();
                  final day = data[value.toInt()]['day'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      day.substring(day.length - 2),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble())).toList(),
              isCurved: true,
              color: AppTheme.accentPurple,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accentPurple.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMax(List data, String key) {
    if (data.isEmpty) return 10;
    double max = 0;
    for (var item in data) {
      if ((item[key] as num).toDouble() > max) max = (item[key] as num).toDouble();
    }
    return max == 0 ? 10 : max;
  }

  Color _getColor(int index) {
    final colors = [
      AppTheme.accentBlue,
      AppTheme.accentPurple,
      AppTheme.accentGreen,
      AppTheme.accentYellow,
      Colors.pinkAccent,
    ];
    return colors[index % colors.length];
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
