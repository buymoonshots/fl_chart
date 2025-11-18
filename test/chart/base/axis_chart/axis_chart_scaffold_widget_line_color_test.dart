import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  group('AxisChartScaffoldWidget - Line Color with Stacked Widgets', () {
    testWidgets(
        'should show only one line when two widgets are at same position',
        (tester) async {
      // Create two horizontal lines at the same Y position with different colors
      const firstLineColor = Colors.blue;
      const secondLineColor = Colors.red;
      const sameY = 50.0;

      final firstLine = HorizontalLine(
        y: sameY,
        color: firstLineColor,
        strokeWidth: 2.0,
        dashArray: [4, 4],
        rightWidget: Container(
          width: 100,
          height: 30,
          color: Colors.blue,
          child: const Text('First'),
        ),
      );

      final secondLine = HorizontalLine(
        y: sameY,
        color: secondLineColor,
        strokeWidth: 2.0,
        dashArray: [4, 4],
        rightWidget: Container(
          width: 100,
          height: 30,
          color: Colors.red,
          child: const Text('Second'),
        ),
      );

      final chartData = LineChartData(
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 100,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              const FlSpot(10, 100),
            ],
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [firstLine, secondLine],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: LineChart(chartData),
            ),
          ),
        ),
      );

      // Wait for the chart to fully render
      await tester.pumpAndSettle();

      // Both widgets should be present
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      // Find all CustomPaint widgets that are children of Positioned widgets
      // These represent the line overlays
      // The line overlay structure is: Positioned(left: 0) > AnimatedContainer > CustomPaint
      // We need to find Positioned widgets with left: 0 (line overlays) vs right: 0 (widgets)
      final allPositioned = find.byType(Positioned);
      final allElements = allPositioned.evaluate();

      // Count CustomPaint widgets that are children of Positioned widgets with left: 0
      // These are the line overlays (widget overlays have right: 0)
      int lineOverlayCount = 0;
      for (final element in allElements) {
        final positionedWidget = element.widget as Positioned;
        // Only count Positioned widgets with left: 0 (line overlays), not right: 0 (widgets)
        if (positionedWidget.left == 0 && positionedWidget.right == null) {
          // Check if this Positioned widget has a CustomPaint as a child
          // The line overlay structure is: Positioned > AnimatedContainer > CustomPaint
          final customPaintFinder = find.descendant(
            of: find.byWidget(positionedWidget),
            matching: find.byType(CustomPaint),
            matchRoot: false,
          );
          if (customPaintFinder.evaluate().isNotEmpty) {
            lineOverlayCount++;
          }
        }
      }

      // Debug: Print what we found
      print('Found $lineOverlayCount line overlay CustomPaint widgets');
      print('Total Positioned widgets: ${allElements.length}');

      // We expect only 1 line overlay CustomPaint when two widgets are at the same Y
      // (The first widget's line should be shown, the second should be hidden)
      expect(lineOverlayCount, equals(1),
          reason:
              'Only one line should be drawn when two widgets are at the same Y position. '
              'Found $lineOverlayCount line overlays.');
    });

    testWidgets(
        'should show separate lines when widgets are at different Y positions',
        (tester) async {
      // Create two horizontal lines at different Y positions
      const firstLineColor = Colors.cyan;
      const secondLineColor = Colors.pink;
      const firstY = 30.0;
      const secondY = 70.0;

      final firstLine = HorizontalLine(
        y: firstY,
        color: firstLineColor,
        strokeWidth: 2.0,
        dashArray: [4, 4],
        rightWidget: Container(
          width: 100,
          height: 30,
          color: Colors.cyan,
          child: const Text('First'),
        ),
      );

      final secondLine = HorizontalLine(
        y: secondY,
        color: secondLineColor,
        strokeWidth: 2.0,
        dashArray: [4, 4],
        rightWidget: Container(
          width: 100,
          height: 30,
          color: Colors.pink,
          child: const Text('Second'),
        ),
      );

      final chartData = LineChartData(
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 100,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              const FlSpot(10, 100),
            ],
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [firstLine, secondLine],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: LineChart(chartData),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both widgets should be present
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      // When lines are at different Y positions, both should be visible
      final allPositioned = find.byType(Positioned);
      final allElements = allPositioned.evaluate();

      int lineOverlayCount = 0;
      for (final element in allElements) {
        final positionedWidget = element.widget as Positioned;
        final customPaintFinder = find.descendant(
          of: find.byWidget(positionedWidget),
          matching: find.byType(CustomPaint),
          matchRoot: false,
        );
        if (customPaintFinder.evaluate().isNotEmpty) {
          lineOverlayCount++;
        }
      }

      print(
          'Found $lineOverlayCount line overlay CustomPaint widgets for different Y positions');

      // When lines are at different Y positions, both should be visible
      expect(lineOverlayCount, greaterThanOrEqualTo(2),
          reason:
              'Both lines should be drawn when they are at different Y positions. '
              'Found $lineOverlayCount line overlays.');
    });
  });
}
