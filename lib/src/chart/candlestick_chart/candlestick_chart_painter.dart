import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/base/axis_chart/axis_chart_painter.dart';
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:fl_chart/src/utils/utils.dart';
import 'package:flutter/material.dart';

/// Paints [CandlestickChartData] in the canvas, it can be used in a [CustomPainter]
class CandlestickChartPainter extends AxisChartPainter<CandlestickChartData> {
  /// Paints [CandlestickChartData] in the canvas
  CandlestickChartPainter() : super() {
    _bgTouchTooltipPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    _borderTouchTooltipPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.transparent
      ..strokeWidth = 1.0;

    _clipPaint = Paint();
    _maskPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x40000000);
  }

  late Paint _bgTouchTooltipPaint;
  late Paint _borderTouchTooltipPaint;
  late Paint _clipPaint;
  late Paint _maskPaint;

  /// Paints [CandlestickChartData] into the provided canvas.
  @override
  void paint(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<CandlestickChartData> holder,
  ) {
    if (holder.chartVirtualRect != null) {
      canvasWrapper
        ..saveLayer(
          Offset.zero & canvasWrapper.size,
          _clipPaint,
        )
        ..clipRect(Offset.zero & canvasWrapper.size);
    }
    super.paint(context, canvasWrapper, holder);

    drawAxisSpotIndicator(context, canvasWrapper, holder);
    
    // Determine which candlesticks have lines centered on them for z-ordering
    final candlesticksWithLinesOnTop = _getCandlesticksWithLinesOnTop(holder);
    
    // Draw candlesticks in two passes for z-ordering
    if (!holder.data.extraLinesData.extraLinesOnTop) {
      // Draw candlesticks without lines first
      drawCandlesticks(
        context,
        canvasWrapper,
        holder,
        skipIndices: candlesticksWithLinesOnTop,
      );
      // Draw lines
      super.drawExtraLines(context, canvasWrapper, holder);
      // Draw candlesticks with lines on top
      drawCandlesticks(
        context,
        canvasWrapper,
        holder,
        onlyIndices: candlesticksWithLinesOnTop,
      );
    } else {
      // Draw all candlesticks first
      drawCandlesticks(context, canvasWrapper, holder);
      // Draw lines on top
      super.drawExtraLines(context, canvasWrapper, holder);
    }

    if (holder.chartVirtualRect != null) {
      canvasWrapper.restore();
    }

    drawMasks(context, canvasWrapper, holder);
    drawTouchTooltips(context, canvasWrapper, holder);
  }

  /// Identifies which candlesticks have horizontal lines centered on them
  /// Uses a tolerance based on Y-axis range to determine "centered on"
  Set<int> _getCandlesticksWithLinesOnTop(
    PaintHolder<CandlestickChartData> holder,
  ) {
    final data = holder.data;
    final horizontalLines = data.extraLinesData.horizontalLines;
    if (horizontalLines.isEmpty) {
      return <int>{};
    }

    final candlesticksWithLines = <int>{};
    final yRange = data.maxY - data.minY;
    // Use 0.5% of Y-axis range as tolerance, or minimum 1 pixel worth of value
    final tolerance = max(yRange * 0.005, (yRange / 1000));

    for (final line in horizontalLines) {
      final lineY = line.y;
      
      for (var i = 0; i < data.candlestickSpots.length; i++) {
        final spot = data.candlestickSpots[i];
        if (!spot.show) continue;

        // Check if line is centered on any of the candlestick's key values
        // (open, close, high, low, or midpoint)
        final valuesToCheck = [
          spot.open,
          spot.close,
          spot.high,
          spot.low,
          spot.midPoint,
        ];

        for (final value in valuesToCheck) {
          if ((lineY - value).abs() <= tolerance) {
            candlesticksWithLines.add(i);
            break; // Found a match for this candlestick, no need to check other values
          }
        }
      }
    }

    return candlesticksWithLines;
  }

  @visibleForTesting
  void drawCandlesticks(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<CandlestickChartData> holder, {
    Set<int>? skipIndices,
    Set<int>? onlyIndices,
  }) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;
    final clip = data.clipData;
    final border = data.borderData.show ? data.borderData.border : null;

    if (data.clipData.any) {
      canvasWrapper.saveLayer(
        Rect.fromLTRB(
          0,
          0,
          canvasWrapper.size.width,
          canvasWrapper.size.height,
        ),
        _clipPaint,
      );

      var left = 0.0;
      var top = 0.0;
      var right = viewSize.width;
      var bottom = viewSize.height;

      if (clip.left) {
        final borderWidth = border?.left.width ?? 0;
        left = borderWidth / 2;
      }
      if (clip.top) {
        final borderWidth = border?.top.width ?? 0;
        top = borderWidth / 2;
      }
      if (clip.right) {
        final borderWidth = border?.right.width ?? 0;
        right = viewSize.width - (borderWidth / 2);
      }
      if (clip.bottom) {
        final borderWidth = border?.bottom.width ?? 0;
        bottom = viewSize.height - (borderWidth / 2);
      }

      canvasWrapper.clipRect(Rect.fromLTRB(left, top, right, bottom));
    }

    // Calculate dynamic candle width if sizing is configured
    double? calculatedBodyWidth;
    if (data.candlestickSizing != null && data.candlestickSpots.isNotEmpty) {
      final sizing = data.candlestickSizing!;
      final usableSize = holder.getChartUsableSize(viewSize);
      
      // Account for internal padding between chart content and right widgets
      final hasRightWidgets = data.extraLinesData.horizontalLines
          .any((line) => line.rightWidget != null);
      final internalPadding = hasRightWidgets
          ? data.extraLinesData.rightWidgetInternalPadding
          : 0.0;
      
      final availableWidth = usableSize.width - internalPadding;
      final numberOfVisibleCandles = data.candlestickSpots
          .where((spot) => spot.show)
          .length;
      
      if (numberOfVisibleCandles > 0) {
        double width;
        if (sizing.minPadding != null) {
          // Calculate width based on minimum padding
          final totalPadding = sizing.minPadding! * (numberOfVisibleCandles - 1);
          width = (availableWidth - totalPadding) / numberOfVisibleCandles;
        } else {
          // Calculate width based on available space
          width = availableWidth / numberOfVisibleCandles;
        }
        
        // Apply min/max constraints if provided
        if (sizing.minWidth != null && width < sizing.minWidth!) {
          width = sizing.minWidth!;
        }
        if (sizing.maxWidth != null && width > sizing.maxWidth!) {
          width = sizing.maxWidth!;
        }
        
        calculatedBodyWidth = width;
      }
    }

    // Store original painter and create wrapper if dynamic sizing is active
    final originalPainter = holder.data.candlestickPainter;
    final painterToUse = calculatedBodyWidth != null &&
            originalPainter is DefaultCandlestickPainter
        ? _DynamicWidthCandlestickPainter(
            originalPainter,
            calculatedBodyWidth,
          )
        : originalPainter;

    for (var i = 0; i < data.candlestickSpots.length; i++) {
      final candlestickSpot = data.candlestickSpots[i];

      if (!candlestickSpot.show) {
        continue;
      }

      // Skip if this index should be skipped
      if (skipIndices != null && skipIndices.contains(i)) {
        continue;
      }

      // Skip if only specific indices should be drawn and this isn't one of them
      if (onlyIndices != null && !onlyIndices.contains(i)) {
        continue;
      }

      // Skip rendering if candlestick is completely outside Y-axis bounds
      // Check if both high and low are outside the visible range
      final highOutsideBounds = candlestickSpot.high < data.minY ||
          candlestickSpot.high > data.maxY;
      final lowOutsideBounds =
          candlestickSpot.low < data.minY || candlestickSpot.low > data.maxY;

      // Only skip if both high and low are outside bounds (candlestick completely invisible)
      if (highOutsideBounds && lowOutsideBounds) {
        continue;
      }

      painterToUse.paint(
        canvasWrapper.canvas,
        (x) => getPixelX(x, viewSize, holder),
        (y) => getPixelY(y, viewSize, holder),
        candlestickSpot,
        i,
      );
    }

    if (data.clipData.any) {
      canvasWrapper.restore();
    }
  }

  @visibleForTesting
  void drawTouchTooltips(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final targetData = holder.targetData;
    for (var i = 0; i < targetData.candlestickSpots.length; i++) {
      if (!targetData.showingTooltipIndicators.contains(i)) {
        continue;
      }

      final candlestickSpot = targetData.candlestickSpots[i];
      drawTouchTooltip(
        context,
        canvasWrapper,
        targetData.candlestickTouchData.touchTooltipData,
        candlestickSpot,
        i,
        holder,
      );
    }
  }

  @visibleForTesting
  void drawTouchTooltip(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    CandlestickTouchTooltipData tooltipData,
    CandlestickSpot showOnSpot,
    int spotIndex,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final viewSize = canvasWrapper.size;

    final tooltipItem = tooltipData.getTooltipItems(
      holder.data.candlestickPainter,
      showOnSpot,
      spotIndex,
    );

    if (tooltipItem == null) {
      return;
    }

    final span = TextSpan(
      style: Utils().getThemeAwareTextStyle(context, tooltipItem.textStyle),
      text: tooltipItem.text,
      children: tooltipItem.children,
    );

    final drawingTextPainter = TextPainter(
      text: span,
      textAlign: tooltipItem.textAlign,
      textDirection: tooltipItem.textDirection,
      textScaler: holder.textScaler,
    )..layout(maxWidth: tooltipData.maxContentWidth);

    final width = drawingTextPainter.width;
    final height = drawingTextPainter.height;

    final tooltipOriginPoint = Offset(
      getPixelX(showOnSpot.x, viewSize, holder),
      getPixelY(
        showOnSpot.high,
        viewSize,
        holder,
      ),
    );

    final tooltipWidth = width + tooltipData.tooltipPadding.horizontal;
    final tooltipHeight = height + tooltipData.tooltipPadding.vertical;

    double tooltipTopPosition;
    if (tooltipData.showOnTopOfTheChartBoxArea) {
      tooltipTopPosition = 0 - tooltipHeight - tooltipItem.bottomMargin;
    } else {
      tooltipTopPosition =
          tooltipOriginPoint.dy - tooltipHeight - tooltipItem.bottomMargin;
    }

    final tooltipLeftPosition = getTooltipLeft(
      tooltipOriginPoint.dx,
      tooltipWidth,
      tooltipData.tooltipHorizontalAlignment,
      tooltipData.tooltipHorizontalOffset,
    );

    /// draw the background rect with rounded radius
    var rect = Rect.fromLTWH(
      tooltipLeftPosition,
      tooltipTopPosition,
      tooltipWidth,
      tooltipHeight,
    );

    if (tooltipData.fitInsideHorizontally) {
      if (rect.left < 0) {
        final shiftAmount = 0 - rect.left;
        rect = Rect.fromLTRB(
          rect.left + shiftAmount,
          rect.top,
          rect.right + shiftAmount,
          rect.bottom,
        );
      }

      if (rect.right > viewSize.width) {
        final shiftAmount = rect.right - viewSize.width;
        rect = Rect.fromLTRB(
          rect.left - shiftAmount,
          rect.top,
          rect.right - shiftAmount,
          rect.bottom,
        );
      }
    }

    if (tooltipData.fitInsideVertically) {
      if (rect.top < 0) {
        final shiftAmount = 0 - rect.top;
        rect = Rect.fromLTRB(
          rect.left,
          rect.top + shiftAmount,
          rect.right,
          rect.bottom + shiftAmount,
        );
      }

      if (rect.bottom > viewSize.height) {
        final shiftAmount = rect.bottom - viewSize.height;
        rect = Rect.fromLTRB(
          rect.left,
          rect.top - shiftAmount,
          rect.right,
          rect.bottom - shiftAmount,
        );
      }
    }

    final roundedRect = RRect.fromRectAndCorners(
      rect,
      topLeft: tooltipData.tooltipBorderRadius.topLeft,
      topRight: tooltipData.tooltipBorderRadius.topRight,
      bottomLeft: tooltipData.tooltipBorderRadius.bottomLeft,
      bottomRight: tooltipData.tooltipBorderRadius.bottomRight,
    );

    _bgTouchTooltipPaint.color = tooltipData.getTooltipColor(showOnSpot);

    final rotateAngle = tooltipData.rotateAngle;
    final rectRotationOffset =
        Offset(0, Utils().calculateRotationOffset(rect.size, rotateAngle).dy);
    final rectDrawOffset = Offset(roundedRect.left, roundedRect.top);

    final textRotationOffset =
        Utils().calculateRotationOffset(drawingTextPainter.size, rotateAngle);

    final drawOffset = Offset(
      rect.center.dx - (drawingTextPainter.width / 2),
      rect.topCenter.dy +
          tooltipData.tooltipPadding.top -
          textRotationOffset.dy +
          rectRotationOffset.dy,
    );

    if (tooltipData.tooltipBorder != BorderSide.none) {
      _borderTouchTooltipPaint
        ..color = tooltipData.tooltipBorder.color
        ..strokeWidth = tooltipData.tooltipBorder.width;
    }

    final reverseQuarterTurnsAngle = -holder.data.rotationQuarterTurns * 90;
    canvasWrapper.drawRotated(
      size: rect.size,
      rotationOffset: rectRotationOffset,
      drawOffset: rectDrawOffset,
      angle: reverseQuarterTurnsAngle + rotateAngle,
      drawCallback: () {
        canvasWrapper
          ..drawRRect(roundedRect, _bgTouchTooltipPaint)
          ..drawRRect(roundedRect, _borderTouchTooltipPaint)
          ..drawText(drawingTextPainter, drawOffset);
      },
    );
  }

  @visibleForTesting
  void drawAxisSpotIndicator(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final pointIndicator = holder.data.touchedPointIndicator;
    if (pointIndicator == null) {
      return;
    }

    final viewSize = canvasWrapper.size;
    pointIndicator.painter.paint(
      context,
      canvasWrapper.canvas,
      canvasWrapper.size,
      pointIndicator,
      (x) => getPixelX(x, viewSize, holder),
      (y) => getPixelY(y, viewSize, holder),
      holder.data,
    );
  }

  @visibleForTesting
  void drawMasks(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final maskData = holder.data.maskData;
    if (maskData == null || !maskData.show) {
      return;
    }

    final targetData = holder.targetData;
    final showingIndicators = targetData.showingTooltipIndicators;

    // Early return if no indicators to avoid unnecessary processing
    if (showingIndicators.isEmpty) {
      return;
    }

    // Draw masks for each selected point
    for (final index in showingIndicators) {
      if (index < 0 || index >= targetData.candlestickSpots.length) {
        continue;
      }

      final candlestickSpot = targetData.candlestickSpots[index];
      drawMask(
        context,
        canvasWrapper,
        maskData,
        candlestickSpot,
        index,
        holder,
      );
    }
  }

  @visibleForTesting
  void drawMask(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    CandlestickMaskData maskData,
    CandlestickSpot spot,
    int spotIndex,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final viewSize = canvasWrapper.size;
    final x = getPixelX(spot.x, viewSize, holder);
    final y = getPixelY(spot.high, viewSize, holder);

    // Validate coordinates to prevent drawing outside bounds
    if (x < 0 || x > viewSize.width || y < 0 || y > viewSize.height) {
      return;
    }

    // Set paint properties once to avoid repeated setup
    _maskPaint
      ..color = maskData.color
      ..style = PaintingStyle.fill;

    // Calculate the candlestick body width to adjust mask positioning
    var bodyWidth = 4.0; // Default body width
    if (holder.targetData.candlestickPainter is DefaultCandlestickPainter) {
      final painter =
          holder.targetData.candlestickPainter as DefaultCandlestickPainter;
      final style = painter.candlestickStyleProvider(spot, spotIndex);
      
      if (style.bodyWidth != null) {
        bodyWidth = style.bodyWidth!;
      } else {
        // If bodyWidth is null, calculate from CandlestickSizing if configured
        final data = holder.targetData;
        if (data.candlestickSizing != null && data.candlestickSpots.isNotEmpty) {
          final sizing = data.candlestickSizing!;
          final usableSize = holder.getChartUsableSize(viewSize);
          
          // Account for internal padding between chart content and right widgets
          final hasRightWidgets = data.extraLinesData.horizontalLines
              .any((line) => line.rightWidget != null);
          final internalPadding = hasRightWidgets
              ? data.extraLinesData.rightWidgetInternalPadding
              : 0.0;
          
          final availableWidth = usableSize.width - internalPadding;
          final numberOfVisibleCandles = data.candlestickSpots
              .where((spot) => spot.show)
              .length;
          
          if (numberOfVisibleCandles > 0) {
            double width;
            if (sizing.minPadding != null) {
              // Calculate width based on minimum padding
              final totalPadding = sizing.minPadding! * (numberOfVisibleCandles - 1);
              width = (availableWidth - totalPadding) / numberOfVisibleCandles;
            } else {
              // Calculate width based on available space
              width = availableWidth / numberOfVisibleCandles;
            }
            
            // Apply min/max constraints if provided
            if (sizing.minWidth != null && width < sizing.minWidth!) {
              width = sizing.minWidth!;
            }
            if (sizing.maxWidth != null && width > sizing.maxWidth!) {
              width = sizing.maxWidth!;
            }
            
            bodyWidth = width;
          }
        }
        // If no sizing configured, bodyWidth remains 4.0 (default)
      }
    }

    // Calculate the right edge of the candlestick body
    final bodyRightEdge = x + (bodyWidth / 2);

    Rect maskRect;
    switch (maskData.maskPosition) {
      case CandlestickMaskPosition.right:
        maskRect = Rect.fromLTWH(
          bodyRightEdge, // Start from the right edge of the body instead of center line
          0,
          viewSize.width -
              bodyRightEdge, // Extend to the full width of the chart
          viewSize.height,
        );
      case CandlestickMaskPosition.left:
        final bodyLeftEdge = x - (bodyWidth / 2);
        maskRect = Rect.fromLTWH(
          0,
          0,
          bodyLeftEdge, // Extend from the left edge to the left edge of the body
          viewSize.height,
        );
      case CandlestickMaskPosition.bottom:
        maskRect = Rect.fromLTWH(
          0,
          y,
          viewSize.width,
          viewSize.height - y, // Extend to the bottom of the chart
        );
      case CandlestickMaskPosition.top:
        maskRect = Rect.fromLTWH(
          0,
          0,
          viewSize.width,
          y, // Extend from the top edge to the point
        );
    }

    // Ensure mask stays within chart bounds and has valid dimensions
    final chartRect = Rect.fromLTWH(0, 0, viewSize.width, viewSize.height);
    maskRect = maskRect.intersect(chartRect);

    // Only draw if the mask has valid dimensions
    if (maskRect.width > 0 && maskRect.height > 0) {
      canvasWrapper.drawRect(maskRect, _maskPaint);
    }
  }

  /// Makes a [CandlestickTouchedSpot] based on the provided [localPosition]
  ///
  /// Processes [localPosition] and checks
  /// the elements of the chart that are near the offset,
  /// then makes a [CandlestickTouchedSpot] from the elements that has been touched.
  ///
  /// Returns null if finds nothing!
  CandlestickTouchedSpot? handleTouch(
    Offset localPosition,
    Size viewSize,
    PaintHolder<CandlestickChartData> holder,
  ) {
    final data = holder.data;

    final touchedSpots =
        <({CandlestickSpot spot, int index, double distance})>[];
    for (var i = data.candlestickSpots.length - 1; i >= 0; i--) {
      // Reverse the loop to check the topmost spot first
      final spot = data.candlestickSpots[i];
      if (!spot.show) {
        continue;
      }

      final spotPixelX = getPixelX(spot.x, viewSize, holder);

      final (hit, distance) = holder.targetData.candlestickPainter.hitTest(
        spot,
        spotPixelX,
        localPosition.dx,
        holder.data.candlestickTouchData.touchSpotThreshold,
      );
      if (hit) {
        touchedSpots.add(
          (
            spot: spot,
            index: i,
            distance: distance,
          ),
        );
      }
    }

    if (touchedSpots.isEmpty) {
      return null;
    }
    // Sort the touched spots by distance
    touchedSpots.sort((a, b) => a.distance.compareTo(b.distance));
    final closestSpot = touchedSpots.first;
    return CandlestickTouchedSpot(closestSpot.spot, closestSpot.index);
  }
}

/// A wrapper painter that overrides bodyWidth for dynamic sizing
class _DynamicWidthCandlestickPainter extends FlCandlestickPainter {
  _DynamicWidthCandlestickPainter(
    this._basePainter,
    this._dynamicWidth,
  );

  final DefaultCandlestickPainter _basePainter;
  final double _dynamicWidth;

  @override
  List<Object?> get props => [_basePainter, _dynamicWidth];

  @override
  void paint(
    Canvas canvas,
    ValueInCanvasProvider xInCanvasProvider,
    ValueInCanvasProvider yInCanvasProvider,
    CandlestickSpot spot,
    int spotIndex,
  ) {
    final originalStyle = _basePainter.candlestickStyleProvider(spot, spotIndex);
    // Calculate lineWidth from dynamic width if not provided
    final calculatedLineWidth =
        originalStyle.lineWidth ?? _dynamicWidth / 4;
    final modifiedStyle = CandlestickStyle(
      lineColor: originalStyle.lineColor,
      lineWidth: calculatedLineWidth,
      bodyStrokeColor: originalStyle.bodyStrokeColor,
      bodyStrokeWidth: originalStyle.bodyStrokeWidth,
      bodyFillColor: originalStyle.bodyFillColor,
      bodyWidth: _dynamicWidth,
      bodyRadius: originalStyle.bodyRadius,
    );

    final xOffsetInCanvas = xInCanvasProvider(spot.x);
    final openYOffsetInCanvas = yInCanvasProvider(spot.open);
    final highYOffsetInCanvas = yInCanvasProvider(spot.high);
    final lowOYOffsetInCanvas = yInCanvasProvider(spot.low);
    final closeYOffsetInCanvas = yInCanvasProvider(spot.close);

    final bodyHighCanvas = min(openYOffsetInCanvas, closeYOffsetInCanvas);
    final bodyLowCanvas = max(openYOffsetInCanvas, closeYOffsetInCanvas);

    final linePainter = Paint();
    final bodyPainter = Paint();
    final bodyStrokePainter = Paint();

    final effectiveLineWidth = modifiedStyle.lineWidth ?? 0;
    if (effectiveLineWidth > 0 && modifiedStyle.lineColor.a > 0) {
      canvas
        // Bottom line
        ..drawLine(
          Offset(xOffsetInCanvas, lowOYOffsetInCanvas),
          Offset(xOffsetInCanvas, bodyLowCanvas),
          linePainter
            ..color = modifiedStyle.lineColor
            ..strokeWidth = effectiveLineWidth,
        )
        // Top line
        ..drawLine(
          Offset(xOffsetInCanvas, highYOffsetInCanvas),
          Offset(xOffsetInCanvas, bodyHighCanvas),
          linePainter
            ..color = modifiedStyle.lineColor
            ..strokeWidth = effectiveLineWidth,
        );
    }

    // Body
    // For flat candles (open == close), ensure minimum height for visibility
    final effectiveBodyWidth = modifiedStyle.bodyWidth ?? _dynamicWidth;
    final bodyHeight = bodyLowCanvas - bodyHighCanvas;
    final minBodyHeight = bodyHeight > 0 ? 0.0 : 1.0;
    final adjustedBodyLowCanvas = bodyLowCanvas + minBodyHeight;
    
    final bodyRect = Rect.fromLTRB(
      xOffsetInCanvas - effectiveBodyWidth / 2,
      bodyHighCanvas,
      xOffsetInCanvas + effectiveBodyWidth / 2,
      adjustedBodyLowCanvas,
    );
    if (modifiedStyle.bodyFillColor.a > 0 && effectiveBodyWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bodyRect,
          Radius.circular(modifiedStyle.bodyRadius),
        ),
        bodyPainter
          ..color = modifiedStyle.bodyFillColor
          ..style = PaintingStyle.fill,
      );
    }
    if (modifiedStyle.bodyStrokeWidth > 0 &&
        modifiedStyle.bodyStrokeColor.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bodyRect,
          Radius.circular(modifiedStyle.bodyRadius),
        ),
        bodyStrokePainter
          ..color = modifiedStyle.bodyStrokeColor
          ..strokeWidth = modifiedStyle.bodyStrokeWidth
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  FlCandlestickPainter lerp(
    FlCandlestickPainter a,
    FlCandlestickPainter b,
    double t,
  ) =>
      _basePainter.lerp(a, b, t);

  @override
  Color getMainColor({
    required CandlestickSpot spot,
    required int spotIndex,
  }) =>
      _basePainter.getMainColor(spot: spot, spotIndex: spotIndex);

  @override
  (bool, double) hitTest(
    CandlestickSpot spot,
    double touchedX,
    double spotX,
    double extraTouchThreshold,
  ) =>
      _basePainter.hitTest(spot, touchedX, spotX, extraTouchThreshold);
}
