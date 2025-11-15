import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_data.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'axis_chart_painter_horizontal_line_clamp_test.mocks.dart';

@GenerateMocks([Canvas, CanvasWrapper, BuildContext])
void main() {
  group('HorizontalLine clampToBounds behavior', () {
    test('should draw line above maxY when clampToBounds is true', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 15, // Above maxY (10)
              color: Colors.red,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
          'paint_color': (inv.positionalArguments[2] as Paint).color,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 1);
      // Line should be clamped to top edge with offset (0 - 25 = -25)
      expect(results[0]['from'].dy, -25.0);
      expect(results[0]['to'].dy, -25.0);
      expect(
        results[0]['paint_color'],
        isSameColorAs(Colors.red),
      );
    });

    test('should draw line below minY when clampToBounds is true', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: -5, // Below minY (0)
              color: Colors.blue,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
          'paint_color': (inv.positionalArguments[2] as Paint).color,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 1);
      // Line should be clamped to bottom edge with offset (100 + 25 = 125)
      expect(results[0]['from'].dy, 125.0);
      expect(results[0]['to'].dy, 125.0);
      expect(
        results[0]['paint_color'],
        isSameColorAs(Colors.blue),
      );
    });

    test('should draw line at normal position when within bounds', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 5, // Within bounds (0-10)
              color: Colors.green,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
          'paint_color': (inv.positionalArguments[2] as Paint).color,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 1);
      // Line should be at normal position (y=5 maps to pixel y=50 in 100px height)
      expect(results[0]['from'].dy, 50.0);
      expect(results[0]['to'].dy, 50.0);
      expect(
        results[0]['paint_color'],
        isSameColorAs(Colors.green),
      );
    });

    test('should skip line when outside bounds and clampToBounds is false', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 15, // Above maxY (10)
              color: Colors.red,
              strokeWidth: 2,
              clampToBounds: false, // Should be skipped
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      // Line should be skipped (not drawn)
      expect(results.length, 0);
    });

    test('should draw clamped line even without widget', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 15, // Above maxY (10)
              color: Colors.purple,
              strokeWidth: 2,
              clampToBounds: true,
              // No rightWidget - should still be drawn
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
          'paint_color': (inv.positionalArguments[2] as Paint).color,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      // Line should be drawn even without widget
      expect(results.length, 1);
      expect(results[0]['from'].dy, -25.0);
      expect(
        results[0]['paint_color'],
        isSameColorAs(Colors.purple),
      );
    });

    test('should handle multiple clamped lines correctly', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 15, // Above maxY
              color: Colors.red,
              strokeWidth: 2,
              clampToBounds: true,
            ),
            HorizontalLine(
              y: 5, // Within bounds
              color: Colors.green,
              strokeWidth: 2,
              clampToBounds: true,
            ),
            HorizontalLine(
              y: -5, // Below minY
              color: Colors.blue,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
          'paint_color': (inv.positionalArguments[2] as Paint).color,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 3);
      // First line (above maxY) should be at top with offset
      expect(results[0]['from'].dy, -25.0);
      expect(
        results[0]['paint_color'],
        isSameColorAs(Colors.red),
      );
      // Second line (within bounds) should be at normal position
      expect(results[1]['from'].dy, 50.0);
      expect(
        results[1]['paint_color'],
        isSameColorAs(Colors.green),
      );
      // Third line (below minY) should be at bottom with offset
      expect(results[2]['from'].dy, 125.0);
      expect(
        results[2]['paint_color'],
        isSameColorAs(Colors.blue),
      );
    });

    test('should handle line exactly at minY boundary', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0, // Exactly at minY
              color: Colors.orange,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 1);
      // Line at minY should be at bottom of chart (y=100)
      expect(results[0]['from'].dy, 100.0);
    });

    test('should handle line exactly at maxY boundary', () {
      const viewSize = Size(100, 100);
      final data = LineChartData(
        minY: 0,
        maxY: 10,
        minX: 0,
        maxX: 10,
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 10, // Exactly at maxY
              color: Colors.teal,
              strokeWidth: 2,
              clampToBounds: true,
            ),
          ],
        ),
      );

      final lineChartPainter = LineChartPainter();
      final holder =
          PaintHolder<LineChartData>(data, data, TextScaler.noScaling);
      final mockCanvasWrapper = MockCanvasWrapper();
      when(mockCanvasWrapper.size).thenAnswer((_) => viewSize);
      when(mockCanvasWrapper.canvas).thenReturn(MockCanvas());

      final mockBuildContext = MockBuildContext();

      final results = <Map<String, dynamic>>[];
      when(
        mockCanvasWrapper.drawDashedLine(
          captureAny,
          captureAny,
          captureAny,
          any,
        ),
      ).thenAnswer((inv) {
        results.add({
          'from': inv.positionalArguments[0] as Offset,
          'to': inv.positionalArguments[1] as Offset,
        });
      });

      lineChartPainter.drawExtraLines(
        mockBuildContext,
        mockCanvasWrapper,
        holder,
      );

      expect(results.length, 1);
      // Line at maxY should be at top of chart (y=0)
      expect(results[0]['from'].dy, 0.0);
    });
  });
}
