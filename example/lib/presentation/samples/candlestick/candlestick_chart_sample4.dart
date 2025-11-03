import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart_app/presentation/resources/app_colors.dart';
import 'package:flutter/material.dart';

class CandlestickChartSample4 extends StatefulWidget {
  const CandlestickChartSample4({super.key});

  @override
  State<StatefulWidget> createState() => CandlestickChartSample4State();
}

class CandlestickChartSample4State extends State<CandlestickChartSample4> {
  // Three price levels that can move and cross each other
  late double _price1;
  late double _price2;
  late double _price3;

  @override
  void initState() {
    super.initState();
    // Start with prices that are close together to demonstrate stacking
    _price1 = 41000.0;
    _price2 = 41500.0;
    _price3 = 42000.0;

    // Auto-animate prices to demonstrate stacking animation
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          // Move prices up and down to cause them to cross
          _price1 += 500;
          _price2 -= 500;
          _price3 += 300;
        });
        _startAnimation(); // Continue animating
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate some sample candlestick data
    final candlestickSpots = List.generate(30, (index) {
      final basePrice = 41000.0;
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

    // Expand range to include all price levels
    final allPrices = [_price1, _price2, _price3];
    final priceMin = allPrices.reduce((a, b) => a < b ? a : b);
    final priceMax = allPrices.reduce((a, b) => a > b ? a : b);

    final yRange = maxY - minY;
    final expandedMinY = (minY < priceMin ? minY : priceMin) - yRange * 0.1;
    final expandedMaxY = (maxY > priceMax ? maxY : priceMax) + yRange * 0.1;

    return Column(
      children: [
        const SizedBox(height: 18),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Animated Stacking Demo',
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
            'Watch as the price labels move up and down. When they cross each other, '
            'the stacking order smoothly animates. Notice how labels smoothly transition '
            'their vertical positions when stacking changes.',
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
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
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
                rightWidgetAdditionalStackingPadding: 4.0,
                horizontalLines: [
                  // Price level 1
                  HorizontalLine(
                    y: _price1,
                    color: Colors.blue,
                    strokeWidth: 2,
                    dashArray: [10, 5],
                    rightWidget: _buildPricePill(
                      'Price 1',
                      _price1,
                      Colors.blue,
                    ),
                    rightWidgetPadding: 8.0,
                    rightWidgetStackingSpacing: 4.0,
                  ),
                  // Price level 2
                  HorizontalLine(
                    y: _price2,
                    color: Colors.orange,
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    rightWidget: _buildPricePill(
                      'Price 2',
                      _price2,
                      Colors.orange,
                    ),
                    rightWidgetPadding: 8.0,
                    rightWidgetStackingSpacing: 4.0,
                  ),
                  // Price level 3
                  HorizontalLine(
                    y: _price3,
                    color: Colors.purple,
                    strokeWidth: 2,
                    dashArray: [15, 5],
                    rightWidget: _buildPricePill(
                      'Price 3',
                      _price3,
                      Colors.purple,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _price1 += 500;
                  });
                },
                child: const Text('Move Price 1 Up'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _price2 -= 500;
                  });
                },
                child: const Text('Move Price 2 Down'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _price3 += 300;
                  });
                },
                child: const Text('Move Price 3 Up'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Use the buttons above to manually move prices, or watch the auto-animation. '
            'When prices cross, notice how the labels smoothly animate their stacking positions.',
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
