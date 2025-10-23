import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CandlestickChartSample2 extends StatefulWidget {
  const CandlestickChartSample2({super.key});

  @override
  State<StatefulWidget> createState() => CandlestickChartSample2State();
}

class CandlestickChartSample2State extends State<CandlestickChartSample2> {
  List<int> showingTooltipIndicators = [];
  CandlestickMaskPosition maskPosition = CandlestickMaskPosition.right;

  final List<CandlestickSpot> candlestickSpots = [
    CandlestickSpot(x: 0, open: 100, high: 120, low: 90, close: 110),
    CandlestickSpot(x: 1, open: 110, high: 130, low: 100, close: 125),
    CandlestickSpot(x: 2, open: 125, high: 140, low: 115, close: 135),
    CandlestickSpot(x: 3, open: 135, high: 150, low: 125, close: 145),
    CandlestickSpot(x: 4, open: 145, high: 160, low: 135, close: 155),
    CandlestickSpot(x: 5, open: 155, high: 170, low: 145, close: 165),
    CandlestickSpot(x: 6, open: 165, high: 180, low: 155, close: 175),
    CandlestickSpot(x: 7, open: 175, high: 190, low: 165, close: 185),
    CandlestickSpot(x: 8, open: 185, high: 200, low: 175, close: 195),
    CandlestickSpot(x: 9, open: 195, high: 210, low: 185, close: 205),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600, // Fixed height to work within SliverMasonryGrid
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Mask position controls
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
                      maskPosition = CandlestickMaskPosition.right;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        maskPosition == CandlestickMaskPosition.right
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  child: const Text('Right'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      maskPosition = CandlestickMaskPosition.left;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        maskPosition == CandlestickMaskPosition.left
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  child: const Text('Left'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      maskPosition = CandlestickMaskPosition.bottom;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        maskPosition == CandlestickMaskPosition.bottom
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  child: const Text('Bottom'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      maskPosition = CandlestickMaskPosition.top;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maskPosition == CandlestickMaskPosition.top
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: const Text('Top'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CandlestickChart(
                CandlestickChartData(
                  candlestickSpots: candlestickSpots,
                  minX: 0,
                  maxX: 9,
                  minY: 80,
                  maxY: 220,
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  candlestickTouchData: CandlestickTouchData(
                    enabled: true,
                    touchSpotThreshold: 100,
                    touchCallback: (event, response) {
                      if (response?.touchedSpot != null) {
                        setState(() {
                          showingTooltipIndicators = [
                            response!.touchedSpot!.spotIndex
                          ];
                        });
                      }
                    },
                  ),
                  showingTooltipIndicators: showingTooltipIndicators,
                  maskData: CandlestickMaskData(
                    show: true,
                    color: Colors.blue.withOpacity(0.3),
                    horizontalMaskSize: double.infinity,
                    verticalMaskSize: double.infinity,
                    maskPosition: maskPosition,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Tap on a candlestick to see the mask effect',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
