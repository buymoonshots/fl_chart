import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart_app/presentation/resources/app_colors.dart';
import 'package:flutter/material.dart';

class CandlestickChartSample3 extends StatefulWidget {
  const CandlestickChartSample3({super.key});

  @override
  State<StatefulWidget> createState() => CandlestickChartSample3State();
}

class CandlestickChartSample3State extends State<CandlestickChartSample3> {
  // Simulated trading position data
  late double _entryPrice;
  late double _liquidationPrice;
  late double _currentPrice;

  @override
  void initState() {
    super.initState();
    // Example values - entry, liquidation, and current prices
    _entryPrice = 42000.0;
    _liquidationPrice = 38000.0;
    _currentPrice = 43500.0;
  }

  @override
  Widget build(BuildContext context) {
    // Generate some sample candlestick data
    final candlestickSpots = List.generate(30, (index) {
      final basePrice = _currentPrice;
      final open = basePrice + (index % 2 == 0 ? 200 : -200);
      final high = open + 300;
      final low = open - 300;
      final close = basePrice + ((index % 3) - 1) * 150;
      return CandlestickSpot(
        x: index.toDouble(),
        open: open,
        high: high,
        low: low,
        close: close,
      );
    });

    final minY =
        candlestickSpots.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    final maxY =
        candlestickSpots.map((e) => e.high).reduce((a, b) => a > b ? a : b);

    // Expand range to include position lines
    final yRange = maxY - minY;
    final expandedMinY = minY - yRange * 0.1;
    final expandedMaxY = maxY + yRange * 0.1;

    return Column(
      children: [
        const SizedBox(height: 18),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trading Position on Candlestick Chart',
              style: TextStyle(
                color: AppColors.contentColorYellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'This example shows entry price, liquidation price, and current price '
            'with custom widgets (pills) on the right side of horizontal lines. '
            'All widgets have uniform width (based on the largest), and stack closely '
            'when they overlap.',
            style: TextStyle(
              color: AppColors.contentColorWhite,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 1.5,
          child: CandlestickChart(
            CandlestickChartData(
              candlestickSpots: candlestickSpots,
              minX: 0,
              maxX: 29,
              minY: expandedMinY,
              maxY: expandedMaxY,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.blueGrey.withValues(alpha: 0.2),
                  strokeWidth: 0.5,
                ),
              ),
              extraLinesData: ExtraLinesData(
                rightWidgetInternalPadding: 20.0,
                horizontalLines: [
                  // Entry price line
                  HorizontalLine(
                    y: _entryPrice,
                    color: AppColors.contentColorGreen,
                    strokeWidth: 2,
                    dashArray: [10, 5],
                    rightWidget: _buildPricePill(
                      'Entry',
                      _entryPrice,
                      AppColors.contentColorGreen,
                    ),
                    rightWidgetPadding: 8.0,
                    rightWidgetStackingSpacing: 4.0,
                  ),
                  // Current price line
                  HorizontalLine(
                    y: _currentPrice,
                    color: AppColors.contentColorYellow,
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    rightWidget: _buildPricePill(
                      'Current',
                      _currentPrice,
                      AppColors.contentColorYellow,
                    ),
                    rightWidgetPadding: 8.0,
                    rightWidgetStackingSpacing: 4.0,
                  ),
                  // Liquidation price line
                  HorizontalLine(
                    y: _liquidationPrice,
                    color: AppColors.contentColorRed,
                    strokeWidth: 2,
                    dashArray: [15, 5],
                    rightWidget: _buildPricePill(
                      'Liquidation',
                      _liquidationPrice,
                      AppColors.contentColorRed,
                    ),
                    rightWidgetPadding: 8.0,
                    rightWidgetStackingSpacing: 4.0,
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  drawBelowEverything: true,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: _leftTitles,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: _bottomTitles,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Notice how all widgets have uniform width (largest widget determines width) '
            'and automatically stack with tight spacing when they overlap. '
            'The chart adjusts its right margin to fit the widgets. '
            'Internal padding creates space between the last candle and the widgets, '
            'while lines still extend all the way to the widget edge.',
            style: TextStyle(
              color: AppColors.contentColorWhite,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPricePill(String label, double price, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '\$${price.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    if (value.toInt() % 5 != 0) {
      return const SizedBox();
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(
        value.toInt().toString(),
        style: const TextStyle(
          color: AppColors.contentColorGreen,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        '\$${value.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.contentColorYellow,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
