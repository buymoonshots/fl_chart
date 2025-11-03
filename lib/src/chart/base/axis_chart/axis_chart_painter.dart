import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/bar_chart/bar_chart_painter.dart';
import 'package:fl_chart/src/chart/base/axis_chart/axis_chart_helper.dart';
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_painter.dart';
import 'package:fl_chart/src/extensions/paint_extension.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:fl_chart/src/utils/utils.dart';
import 'package:flutter/material.dart';

/// This class is responsible to draw the grid behind all axis base charts.
/// also we have two useful function [getPixelX] and [getPixelY] that used
/// in child classes -> [BarChartPainter], [LineChartPainter]
/// [dataList] is the currently showing data (it may produced by an animation using lerp function),
/// [targetData] is the target data, that animation is going to show (if animating)
abstract class AxisChartPainter<D extends AxisChartData>
    extends BaseChartPainter<D> {
  AxisChartPainter() {
    _gridPaint = Paint()..style = PaintingStyle.stroke;

    _backgroundPaint = Paint()..style = PaintingStyle.fill;

    _rangeAnnotationPaint = Paint()..style = PaintingStyle.fill;

    _extraLinesPaint = Paint()..style = PaintingStyle.stroke;

    _imagePaint = Paint();

    _clipPaint = Paint();
  }

  late Paint _gridPaint;
  late Paint _backgroundPaint;
  late Paint _extraLinesPaint;
  late Paint _imagePaint;
  late Paint _clipPaint;

  /// [_rangeAnnotationPaint] draws range annotations;
  late Paint _rangeAnnotationPaint;

  /// Paints [AxisChartData] into the provided canvas.
  @override
  void paint(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<D> holder,
  ) {
    super.paint(context, canvasWrapper, holder);
    drawBackground(canvasWrapper, holder);
    drawRangeAnnotation(canvasWrapper, holder);
    drawGrid(canvasWrapper, holder);
  }

  @visibleForTesting
  void drawGrid(CanvasWrapper canvasWrapper, PaintHolder<D> holder) {
    final data = holder.data;
    if (!data.gridData.show) {
      return;
    }
    final viewSize = canvasWrapper.size;
    // Show Vertical Grid
    if (data.gridData.drawVerticalLine) {
      final verticalInterval = data.gridData.verticalInterval ??
          Utils().getEfficientInterval(
            viewSize.width,
            data.horizontalDiff,
          );
      final axisValues = AxisChartHelper().iterateThroughAxis(
        min: data.minX,
        minIncluded: false,
        max: data.maxX,
        maxIncluded: false,
        baseLine: data.baselineX,
        interval: verticalInterval,
      );
      for (final axisValue in axisValues) {
        if (!data.gridData.checkToShowVerticalLine(axisValue)) {
          continue;
        }
        final bothX = getPixelX(axisValue, viewSize, holder);
        final x1 = bothX;
        const y1 = 0.0;
        final x2 = bothX;
        final y2 = viewSize.height;
        final from = Offset(x1, y1);
        final to = Offset(x2, y2);

        final flLineStyle = data.gridData.getDrawingVerticalLine(axisValue);
        _gridPaint
          ..setColorOrGradientForLine(
            flLineStyle.color,
            flLineStyle.gradient,
            from: from,
            to: to,
          )
          ..strokeWidth = flLineStyle.strokeWidth
          ..transparentIfWidthIsZero();

        canvasWrapper.drawDashedLine(
          from,
          to,
          _gridPaint,
          flLineStyle.dashArray,
        );
      }
    }

    // Show Horizontal Grid
    if (data.gridData.drawHorizontalLine) {
      final horizontalInterval = data.gridData.horizontalInterval ??
          Utils().getEfficientInterval(viewSize.height, data.verticalDiff);

      final axisValues = AxisChartHelper().iterateThroughAxis(
        min: data.minY,
        minIncluded: false,
        max: data.maxY,
        maxIncluded: false,
        baseLine: data.baselineY,
        interval: horizontalInterval,
      );
      for (final axisValue in axisValues) {
        if (!data.gridData.checkToShowHorizontalLine(axisValue)) {
          continue;
        }
        final flLine = data.gridData.getDrawingHorizontalLine(axisValue);

        final bothY = getPixelY(axisValue, viewSize, holder);
        const x1 = 0.0;
        final y1 = bothY;
        final x2 = viewSize.width;
        final y2 = bothY;
        final from = Offset(x1, y1);
        final to = Offset(x2, y2);

        _gridPaint
          ..setColorOrGradientForLine(
            flLine.color,
            flLine.gradient,
            from: from,
            to: to,
          )
          ..strokeWidth = flLine.strokeWidth
          ..transparentIfWidthIsZero();

        canvasWrapper.drawDashedLine(
          from,
          to,
          _gridPaint,
          flLine.dashArray,
        );
      }
    }
  }

  /// This function draws a colored background behind the chart.
  @visibleForTesting
  void drawBackground(CanvasWrapper canvasWrapper, PaintHolder<D> holder) {
    final data = holder.data;
    if (data.backgroundColor.a == 0.0) {
      return;
    }

    final viewSize = canvasWrapper.size;
    _backgroundPaint.color = data.backgroundColor;
    canvasWrapper.drawRect(
      Rect.fromLTWH(0, 0, viewSize.width, viewSize.height),
      _backgroundPaint,
    );
  }

  @visibleForTesting
  void drawRangeAnnotation(CanvasWrapper canvasWrapper, PaintHolder<D> holder) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;

    if (data.rangeAnnotations.verticalRangeAnnotations.isNotEmpty) {
      for (final annotation in data.rangeAnnotations.verticalRangeAnnotations) {
        final from = Offset(getPixelX(annotation.x1, viewSize, holder), 0);
        final to = Offset(
          getPixelX(annotation.x2, viewSize, holder),
          viewSize.height,
        );

        final rect = Rect.fromPoints(from, to);

        _rangeAnnotationPaint.setColorOrGradient(
          annotation.color,
          annotation.gradient,
          rect,
        );

        canvasWrapper.drawRect(rect, _rangeAnnotationPaint);
      }
    }

    if (data.rangeAnnotations.horizontalRangeAnnotations.isNotEmpty) {
      for (final annotation
          in data.rangeAnnotations.horizontalRangeAnnotations) {
        final from = Offset(0, getPixelY(annotation.y1, viewSize, holder));
        final to = Offset(
          viewSize.width,
          getPixelY(annotation.y2, viewSize, holder),
        );

        final rect = Rect.fromPoints(from, to);

        _rangeAnnotationPaint.setColorOrGradient(
          annotation.color,
          annotation.gradient,
          rect,
        );

        canvasWrapper.drawRect(rect, _rangeAnnotationPaint);
      }
    }
  }

  void drawExtraLines(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<D> holder,
  ) {
    if (holder.chartVirtualRect != null) {
      canvasWrapper.restore();
    }

    super.paint(context, canvasWrapper, holder);
    final data = holder.data;
    final viewSize = canvasWrapper.size;

    if (data.extraLinesData.horizontalLines.isNotEmpty) {
      drawHorizontalLines(context, canvasWrapper, holder, viewSize);
    }

    if (data.extraLinesData.verticalLines.isNotEmpty) {
      drawVerticalLines(context, canvasWrapper, holder, viewSize);
    }

    if (holder.chartVirtualRect != null) {
      canvasWrapper
        ..saveLayer(
          Offset.zero & canvasWrapper.size,
          _clipPaint,
        )
        ..clipRect(Offset.zero & canvasWrapper.size);
    }
  }

  void drawHorizontalLines(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<D> holder,
    Size viewSize,
  ) {
    // Lines extend to the full width of the chart content area
    // Line segments in the widget overlay will extend from here to the widgets
    for (final line in holder.data.extraLinesData.horizontalLines) {
      // Check if line Y is within Y-axis bounds
      final lineWithinYBounds = line.y >= holder.data.minY &&
          line.y <= holder.data.maxY;

      // Only draw lines that are within bounds (including lines with widgets)
      // Widgets will also be hidden if their line is out of bounds
      if (!lineWithinYBounds) {
        continue;
      }

      final pixelY = getPixelY(line.y, viewSize, holder);
      final from = Offset(0, pixelY);
      // Lines extend to full width of chart content area
      // Widget overlay will extend them further to reach widgets
      final to = Offset(viewSize.width, pixelY);

      _extraLinesPaint
        ..setColorOrGradientForLine(
          line.color,
          line.gradient,
          from: from,
          to: to,
        )
        ..strokeWidth = line.strokeWidth
        ..transparentIfWidthIsZero()
        ..strokeCap = line.strokeCap;

      canvasWrapper.drawDashedLine(
        from,
        to,
        _extraLinesPaint,
        line.dashArray,
      );

      if (line.sizedPicture != null) {
        final centerX = line.sizedPicture!.width / 2;
        final centerY = line.sizedPicture!.height / 2;
        final xPosition = centerX;
        final yPosition = to.dy - centerY;

        canvasWrapper
          ..save()
          ..translate(xPosition, yPosition)
          ..drawPicture(line.sizedPicture!.picture)
          ..restore();
      }

      if (line.image != null) {
        final centerX = line.image!.width / 2;
        final centerY = line.image!.height / 2;
        final centeredImageOffset = Offset(centerX, to.dy - centerY);
        canvasWrapper.drawImage(
          line.image!,
          centeredImageOffset,
          _imagePaint,
        );
      }

      if (line.label.show) {
        final label = line.label;
        final style =
            TextStyle(fontSize: 11, color: line.color).merge(label.style);
        final padding = label.padding as EdgeInsets;

        final span = TextSpan(
          text: label.labelResolver(line),
          style: Utils().getThemeAwareTextStyle(context, style),
        );

        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        )..layout();

        switch (label.direction) {
          case LabelDirection.horizontal:
            canvasWrapper.drawText(
              tp,
              label.alignment.withinRect(
                Rect.fromLTRB(
                  from.dx + padding.left,
                  from.dy - padding.bottom - tp.height,
                  to.dx - padding.right - tp.width,
                  to.dy + padding.top,
                ),
              ),
            );
          case LabelDirection.vertical:
            canvasWrapper.drawVerticalText(
              tp,
              label.alignment.withinRect(
                Rect.fromLTRB(
                  from.dx + padding.left + tp.height,
                  from.dy - padding.bottom - tp.width,
                  to.dx - padding.right,
                  to.dy + padding.top,
                ),
              ),
            );
        }
      }
    }
  }

  void drawVerticalLines(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<D> holder,
    Size viewSize,
  ) {
    for (final line in holder.data.extraLinesData.verticalLines) {
      final from = Offset(getPixelX(line.x, viewSize, holder), 0);
      final to = Offset(getPixelX(line.x, viewSize, holder), viewSize.height);

      final isLineOutsideOfChart = from.dx < 0 ||
          to.dx < 0 ||
          from.dx > viewSize.width ||
          to.dx > viewSize.width;

      if (!isLineOutsideOfChart) {
        _extraLinesPaint
          ..setColorOrGradientForLine(
            line.color,
            line.gradient,
            from: from,
            to: to,
          )
          ..strokeWidth = line.strokeWidth
          ..transparentIfWidthIsZero()
          ..strokeCap = line.strokeCap;

        canvasWrapper.drawDashedLine(
          from,
          to,
          _extraLinesPaint,
          line.dashArray,
        );

        if (line.sizedPicture != null) {
          final centerX = line.sizedPicture!.width / 2;
          final centerY = line.sizedPicture!.height / 2;
          final xPosition = to.dx - centerX;
          final yPosition = viewSize.height - centerY;

          canvasWrapper
            ..save()
            ..translate(xPosition, yPosition)
            ..drawPicture(line.sizedPicture!.picture)
            ..restore();
        }

        if (line.image != null) {
          final centerX = line.image!.width / 2;
          final centerY = line.image!.height + 2;
          final centeredImageOffset =
              Offset(to.dx - centerX, viewSize.height - centerY);
          canvasWrapper.drawImage(
            line.image!,
            centeredImageOffset,
            _imagePaint,
          );
        }

        if (line.label.show) {
          final label = line.label;
          final style =
              TextStyle(fontSize: 11, color: line.color).merge(label.style);
          final padding = label.padding as EdgeInsets;

          final span = TextSpan(
            text: label.labelResolver(line),
            style: Utils().getThemeAwareTextStyle(context, style),
          );

          final tp = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
          )..layout();

          // Calculate base label rect
          Rect labelRect;

          // For center alignments, calculate labelRect centered on the line position
          final isCenterAlignment = label.alignment == Alignment.bottomCenter ||
              label.alignment == Alignment.topCenter ||
              label.alignment == Alignment.center;
          
          final labelRectWidth = tp.width + padding.horizontal;
          final labelRectCenter = from.dx; // Center on the line position

          if (line.showOnTopOfTheChartBoxArea) {
            // When showing on top, position labels outside the chart bounds
            // Use alignment to determine if label goes above (topCenter) or below (bottomCenter)
            final isTop = label.alignment.y <
                0; // topCenter, topLeft, topRight have y = -1

            if (isTop) {
              // Position above the chart
              if (isCenterAlignment) {
                // Center the label on the line
                labelRect = Rect.fromLTRB(
                  labelRectCenter - labelRectWidth / 2,
                  0 - padding.bottom - tp.height,
                  labelRectCenter + labelRectWidth / 2,
                  0 + padding.top,
                );
              } else {
                // Use original calculation for non-center alignments
                labelRect = Rect.fromLTRB(
                  from.dx - padding.right - tp.width,
                  0 - padding.bottom - tp.height,
                  to.dx + padding.left,
                  0 + padding.top,
                );
              }
            } else {
              // Position below the chart
              if (isCenterAlignment) {
                // Center the label on the line
                labelRect = Rect.fromLTRB(
                  labelRectCenter - labelRectWidth / 2,
                  viewSize.height - padding.top,
                  labelRectCenter + labelRectWidth / 2,
                  viewSize.height + padding.bottom + tp.height,
                );
              } else {
                // Use original calculation for non-center alignments
                labelRect = Rect.fromLTRB(
                  from.dx - padding.right - tp.width,
                  viewSize.height - padding.top,
                  to.dx + padding.left,
                  viewSize.height + padding.bottom + tp.height,
                );
              }
            }
          } else {
            // Default behavior: position within chart bounds
            if (isCenterAlignment) {
              // Center the label on the line
              labelRect = Rect.fromLTRB(
                labelRectCenter - labelRectWidth / 2,
                from.dy + padding.top,
                labelRectCenter + labelRectWidth / 2,
                from.dy - padding.bottom - tp.height,
              );
            } else {
              // Use original calculation for non-center alignments
              labelRect = Rect.fromLTRB(
                from.dx - padding.right - tp.width,
                from.dy + padding.top,
                to.dx + padding.left,
                to.dy - padding.bottom - tp.height,
              );
            }
          }

          // If fitInsideHorizontally is enabled, adjust the label position
          // to keep it within the viewport bounds horizontally
          // When false, labelRect is used as-is and may overflow bounds
          if (line.fitInsideHorizontally) {
            final actualLabelRectWidth = labelRect.right - labelRect.left;

            // Calculate the center of the original labelRect (which should be at from.dx for center alignments)
            final originalCenter = (labelRect.left + labelRect.right) / 2;

            // Clamp X position to keep label within horizontal bounds
            // For center alignments, try to center on the line, but if it can't fit, align to the edge
            var adjustedX = labelRect.left;
            
            if (isCenterAlignment) {
              // For center alignments, check if we can fit centered on the line
              final centeredLeft = originalCenter - (actualLabelRectWidth / 2);
              final centeredRight = originalCenter + (actualLabelRectWidth / 2);
              
              if (centeredLeft < 0) {
                // Can't fit centered - overflow left, so align to left edge
                adjustedX = 0;
              } else if (centeredRight > viewSize.width) {
                // Can't fit centered - overflow right, so align to right edge
                adjustedX = viewSize.width - actualLabelRectWidth;
              } else {
                // Can fit centered, keep the original centered position
                adjustedX = centeredLeft;
              }
            } else {
              // For non-center alignments, use simple clamping
              if (labelRect.left < 0) {
                adjustedX = 0;
              } else if (adjustedX + actualLabelRectWidth > viewSize.width) {
                adjustedX = viewSize.width - actualLabelRectWidth;
              }
            }

            labelRect = Rect.fromLTRB(
              adjustedX,
              labelRect.top,
              adjustedX + actualLabelRectWidth,
              labelRect.bottom,
            );
          }

          switch (label.direction) {
            case LabelDirection.horizontal:
              var position = label.alignment.withinRect(labelRect);

              // Adjust position for bottom alignments to account for text height
              if (label.alignment.y > 0) {
                // bottomCenter, bottomLeft, bottomRight
                position = Offset(position.dx, position.dy - tp.height);
              }

              // For center alignments, withinRect returns the center point, but TextPainter
              // draws from that point (extending right). We need to offset by -tp.width/2 to center.
              // However, we adjust this based on fitInsideHorizontally to keep text in bounds.
              if (isCenterAlignment) {
                // Use the original line position (from.dx) as the center point, not the adjusted labelRect center
                final lineCenterX = from.dx;
                final textLeft = lineCenterX - tp.width / 2;
                final textRight = lineCenterX + tp.width / 2;

                if (line.fitInsideHorizontally) {
                  // For center alignments with fitInsideHorizontally:
                  // - Try to keep text centered on the line
                  // - If centered would overflow, shift just enough to fit while staying as close to edge as possible
                  if (textLeft < 0) {
                    // Overflow left: position text so left edge is at 0 (as far left as possible while fitting)
                    position = Offset(0, position.dy);
                  } else if (textRight > viewSize.width) {
                    // Overflow right: position text so right edge is at width (as far right as possible while fitting)
                    position = Offset(viewSize.width - tp.width, position.dy);
                  } else {
                    // Can fit centered, use centered position (offset by -tp.width/2 from line center)
                    position = Offset(lineCenterX - tp.width / 2, position.dy);
                  }
                } else {
                  // Without fitInsideHorizontally, just center normally on the line
                  position = Offset(lineCenterX - tp.width / 2, position.dy);
                }
              } else {
                // For non-center alignments, if fitInsideHorizontally is enabled,
                // clamp the position so text doesn't extend beyond viewport
                if (line.fitInsideHorizontally) {
                  if (position.dx < 0) {
                    position = Offset(0, position.dy);
                  } else if (position.dx + tp.width > viewSize.width) {
                    position = Offset(viewSize.width - tp.width, position.dy);
                  }
                }
              }

              canvasWrapper.drawText(
                tp,
                position,
              );
            case LabelDirection.vertical:
              canvasWrapper.drawVerticalText(
                tp,
                label.alignment.withinRect(
                  Rect.fromLTRB(
                    labelRect.left,
                    labelRect.top,
                    labelRect.right + tp.height,
                    labelRect.bottom,
                  ),
                ),
              );
          }
        }
      }
    }
  }

  /// With this function we can convert our [FlSpot] x
  /// to the view base axis x .
  /// the view 0, 0 is on the top/left, but the spots is bottom/left
  double getPixelX(
    double spotX,
    Size viewSize,
    PaintHolder<D> holder,
  ) {
    final usableSize = holder.getChartUsableSize(viewSize);

    // Account for internal padding between chart content and right widgets
    // This reduces the usable width for X positioning so last data point doesn't touch widgets
    final hasRightWidgets = holder.data.extraLinesData.horizontalLines
        .any((line) => line.rightWidget != null);
    final internalPadding = hasRightWidgets
        ? holder.data.extraLinesData.rightWidgetInternalPadding
        : 0.0;
    
    // Create adjusted usable size for X calculations (reduce width by internal padding)
    final adjustedUsableSize = Size(
      usableSize.width - internalPadding,
      usableSize.height,
    );

    final pixelXUnadjusted = _getPixelX(spotX, holder.data, adjustedUsableSize);

    // Adjust the position relative to the canvas if chartVirtualRect
    // is provided
    final adjustment = holder.chartVirtualRect?.left ?? 0;
    return pixelXUnadjusted + adjustment;
  }

  double _getPixelX(double spotX, D data, Size usableSize) {
    final deltaX = data.maxX - data.minX;
    if (deltaX == 0.0) {
      return 0;
    }
    return ((spotX - data.minX) / deltaX) * usableSize.width;
  }

  /// With this function we can convert our [FlSpot] y
  /// to the view base axis y.
  double getPixelY(
    double spotY,
    Size viewSize,
    PaintHolder<D> holder,
  ) {
    final usableSize = holder.getChartUsableSize(viewSize);

    final pixelYUnadjusted = _getPixelY(spotY, holder.data, usableSize);

    // Adjust the position relative to the canvas if chartVirtualRect
    // is provided
    final adjustment = holder.chartVirtualRect?.top ?? 0;
    return pixelYUnadjusted + adjustment;
  }

  double _getPixelY(double spotY, D data, Size usableSize) {
    final deltaY = data.maxY - data.minY;
    if (deltaY == 0.0) {
      return usableSize.height;
    }
    return usableSize.height -
        (((spotY - data.minY) / deltaY) * usableSize.height);
  }

  /// Converts pixel X position to axis X coordinates
  double getXForPixel(
    double pixelX,
    Size viewSize,
    PaintHolder<D> holder,
  ) {
    final usableSize = holder.getChartUsableSize(viewSize);
    final adjustment = holder.chartVirtualRect?.left ?? 0;
    final unadjustedPixelX = pixelX - adjustment;

    final deltaX = holder.data.maxX - holder.data.minX;
    if (deltaX == 0.0) return holder.data.minX;

    return (unadjustedPixelX / usableSize.width) * deltaX + holder.data.minX;
  }

  /// Converts pixel Y position to axis Y coordinates
  double getYForPixel(
    double pixelY,
    Size viewSize,
    PaintHolder<D> holder,
  ) {
    final usableSize = holder.getChartUsableSize(viewSize);
    final adjustment = holder.chartVirtualRect?.top ?? 0;
    final unadjustedPixelY = pixelY - adjustment;

    final deltaY = holder.data.maxY - holder.data.minY;
    if (deltaY == 0.0) return holder.data.minY;

    return holder.data.maxY - (unadjustedPixelY / usableSize.height) * deltaY;
  }

  /// Converts pixel coordinates to chart coordinates
  Offset getChartCoordinateFromPixel(
    Offset pixelOffset,
    Size viewSize,
    PaintHolder<D> holder,
  ) =>
      Offset(
        getXForPixel(pixelOffset.dx, viewSize, holder),
        getYForPixel(pixelOffset.dy, viewSize, holder),
      );

  /// With this function we can get horizontal
  /// position for the tooltip.
  double getTooltipLeft(
    double dx,
    double tooltipWidth,
    FLHorizontalAlignment tooltipHorizontalAlignment,
    double tooltipHorizontalOffset,
  ) =>
      switch (tooltipHorizontalAlignment) {
        FLHorizontalAlignment.center =>
          dx - (tooltipWidth / 2) + tooltipHorizontalOffset,
        FLHorizontalAlignment.right => dx + tooltipHorizontalOffset,
        FLHorizontalAlignment.left =>
          dx - tooltipWidth + tooltipHorizontalOffset,
      };
}
